import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../models/user_model.dart';
import '../../../services/firestore_order_service.dart';
import '../../../services/mock_data_service.dart';
import '../../../services/push/notification_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier(ref);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

// True until the first `authStateChanges()` event resolves (or immediately
// false without Firebase). The router uses this to show a splash screen
// instead of briefly flashing /login for an already-signed-in user while
// Firebase is still restoring the session.
final authLoadingProvider = StateProvider<bool>((ref) => kUseFirebase);

// Set when sign-in is rejected because an admin has blocked the account —
// the login screen reads this to show why the user is stuck on /login.
final blockedMessageProvider = StateProvider<String?>((ref) => null);

// Exposed so callers can surface specific error messages.
enum AuthError {
  invalidEmail,      // not a valid email address format
  weakPassword,     // password shorter than Firebase's 6-char minimum
  emptyFields,
  tooManyAttempts,
  invalidCredentials,
  emailInUseDifferentPassword, // signup: email already has an account, but with a different password
}

class AuthResult {
  final bool success;
  final AuthError? error;
  const AuthResult.ok() : success = true, error = null;
  const AuthResult.fail(this.error) : success = false;
}

class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier(this._ref) : super(null) {
    if (kUseFirebase) {
      _authSub = fb.FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
    }
  }

  final Ref _ref;
  StreamSubscription<fb.User?>? _authSub;
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;

  // Last signed-in uid, kept so we can detach its push token on sign-out
  // (fbUser is null by then).
  String? _lastUid;

  Future<void> _onAuthStateChanged(fb.User? fbUser) async {
    if (fbUser == null) {
      final goneUid = _lastUid;
      _lastUid = null;
      if (goneUid != null) {
        // Stop delivering this user's order notifications to a signed-out device.
        FirestoreOrderService.instance
            .clearFcmToken(goneUid)
            .catchError((e) => debugPrint('[push] clearFcmToken failed: $e'));
      }
      state = null;
      // Reset the shared placeholder too — otherwise any screen reading it
      // directly (instead of authProvider) keeps showing the previous
      // signed-out user's id/name/email indefinitely.
      MockDataService.currentUser = const UserModel(
        id: '',
        name: '',
        email: '',
        universityId: '',
        role: UserRole.student,
      );
      _ref.read(authLoadingProvider.notifier).state = false;
      return;
    }
    try {
      var profile = await FirestoreOrderService.instance.fetchUserProfile(fbUser.uid);
      if (profile == null) {
        // First sign-in via a provider that doesn't go through our signUp()
        // flow (e.g. Google) — bootstrap a profile from the provider's data.
        profile = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'Student',
          email: fbUser.email ?? '',
          universityId: '',
          role: UserRole.student,
          avatarUrl: fbUser.photoURL,
        );
        await FirestoreOrderService.instance.createUserProfile(profile);
      }
      if (profile.isBlocked) {
        _ref.read(blockedMessageProvider.notifier).state =
            'Your account has been blocked. Contact support if you think this is a mistake.';
        await fb.FirebaseAuth.instance.signOut();
        return;
      }
      MockDataService.currentUser = profile;
      state = profile;
      _lastUid = profile.id;
      _registerPushToken(profile.id);
    } catch (e) {
      debugPrint('[Auth] profile fetch failed: $e');
    } finally {
      _ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  // Save the device's FCM token to this user's doc and keep it fresh on
  // rotation, so order-status push notifications reach them. Best-effort.
  bool _pushRefreshHooked = false;
  void _registerPushToken(String uid) {
    NotificationService.instance.currentToken().then((token) {
      debugPrint('[push] currentToken for $uid => ${token == null ? 'NULL' : '${token.substring(0, 12)}… (len ${token.length})'}');
      if (token != null && token.isNotEmpty) {
        FirestoreOrderService.instance
            .saveFcmToken(uid, token)
            .then((_) => debugPrint('[push] saveFcmToken OK for $uid'))
            .catchError((e) => debugPrint('[push] saveFcmToken failed: $e'));
      }
    });
    if (_pushRefreshHooked) return;
    _pushRefreshHooked = true;
    NotificationService.instance.onTokenRefresh((token) {
      final current = state?.id;
      if (current != null && current.isNotEmpty) {
        FirestoreOrderService.instance
            .saveFcmToken(current, token)
            .catchError((e) => debugPrint('[push] saveFcmToken refresh failed: $e'));
      }
    });
  }

  // Test phase: any well-formed email, any password Firebase accepts
  // (6+ chars), any non-empty ID. Tighten these back up before real launch.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Returns null if valid, otherwise the specific error.
  static AuthError? validateEmail(String email) {
    if (email.isEmpty) return AuthError.emptyFields;
    if (!_emailPattern.hasMatch(email)) return AuthError.invalidEmail;
    return null;
  }

  static AuthError? validatePassword(String password) {
    if (password.isEmpty) return AuthError.emptyFields;
    if (password.length < 6) return AuthError.weakPassword;
    return null;
  }

  static AuthError? validateUniversityId(String id) {
    if (id.isEmpty) return AuthError.emptyFields;
    return null;
  }

  Future<AuthResult> signIn(String email, String password) async {
    if (_failedAttempts >= _maxAttempts) {
      return const AuthResult.fail(AuthError.tooManyAttempts);
    }

    final emailErr = validateEmail(email);
    if (emailErr != null) return AuthResult.fail(emailErr);

    final passErr = validatePassword(password);
    if (passErr != null) return AuthResult.fail(passErr);

    try {
      await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // state is populated by _onAuthStateChanged once the Firestore profile loads.
      _failedAttempts = 0;
      return const AuthResult.ok();
    } on fb.FirebaseAuthException {
      _failedAttempts++;
      return const AuthResult.fail(AuthError.invalidCredentials);
    }
  }

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String universityId,
    required UserRole role,
  }) async {
    if (name.trim().isEmpty) return const AuthResult.fail(AuthError.emptyFields);

    final emailErr = validateEmail(email);
    if (emailErr != null) return AuthResult.fail(emailErr);

    final passErr = validatePassword(password);
    if (passErr != null) return AuthResult.fail(passErr);

    final idErr = validateUniversityId(universityId);
    if (idErr != null) return AuthResult.fail(idErr);

    try {
      fb.UserCredential cred;
      try {
        cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        // Same email already has an account in this Firebase project — likely
        // from the driver app, since one person can be both. Sign in to the
        // existing account instead of failing, so the login is shared.
        try {
          cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } on fb.FirebaseAuthException catch (signInError) {
          // Wrong password on the cross-app fallback — newer Firebase Auth
          // versions report this as 'invalid-credential' rather than the
          // older 'wrong-password' code, so check both.
          if (signInError.code == 'wrong-password' || signInError.code == 'invalid-credential') {
            return const AuthResult.fail(AuthError.emailInUseDifferentPassword);
          }
          rethrow;
        }
      }

      final existing = await FirestoreOrderService.instance.fetchUserProfile(cred.user!.uid);
      final profile = existing ??
          UserModel(
            id: cred.user!.uid,
            name: name.trim(),
            email: email.toLowerCase().trim(),
            universityId: universityId.trim(),
            role: role,
          );
      if (existing == null) {
        await FirestoreOrderService.instance.createUserProfile(profile);
      }
      MockDataService.currentUser = profile;
      state = profile;
      return const AuthResult.ok();
    } on fb.FirebaseAuthException {
      // Covers wrong-password on the cross-app fallback, weak-password
      // (already validated above), etc.
      return const AuthResult.fail(AuthError.invalidCredentials);
    }
  }

  /// Returns null on success (including user-cancelled — not an error worth
  /// surfacing), or an error message on genuine failure.
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user backed out of the picker
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await fb.FirebaseAuth.instance.signInWithCredential(credential);
      // state is populated by _onAuthStateChanged once the Firestore profile loads.
      return null;
    } catch (e) {
      debugPrint('[Auth] Google sign-in failed: $e');
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> signOut() async {
    _failedAttempts = 0;
    if (kUseFirebase) {
      await fb.FirebaseAuth.instance.signOut();
    } else {
      state = null;
    }
  }

  Future<void> updateProfile({String? name, String? phone}) async {
    if (state == null) return;
    final updated = state!.copyWith(name: name, phone: phone);
    state = updated;
    MockDataService.currentUser = updated;
    if (kUseFirebase) {
      await FirestoreOrderService.instance.updateUserProfile(updated);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
