import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../../../services/mock_data_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

// Exposed so callers can surface specific error messages.
enum AuthError {
  invalidEmail,      // not a valid email address format
  notUdstDomain,    // email must be @udst.edu.qa
  weakPassword,     // password does not meet strength requirements
  invalidId,        // university ID must be 8 digits
  emptyFields,
  tooManyAttempts,
  invalidCredentials,
}

class AuthResult {
  final bool success;
  final AuthError? error;
  const AuthResult.ok() : success = true, error = null;
  const AuthResult.fail(this.error) : success = false;
}

class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier() : super(MockDataService.currentUser);

  int _failedAttempts = 0;
  static const int _maxAttempts = 5;

  // UDST institutional email pattern.
  static final _udstEmailPattern =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@udst\.edu\.qa$', caseSensitive: false);

  // At least 8 chars, one uppercase, one lowercase, one digit.
  static final _strongPasswordPattern =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');

  // 8-digit numeric university ID.
  static final _universityIdPattern = RegExp(r'^\d{8}$');

  /// Returns null if valid, otherwise the specific error.
  static AuthError? validateEmail(String email) {
    if (email.isEmpty) return AuthError.emptyFields;
    if (!email.contains('@') || !email.contains('.')) return AuthError.invalidEmail;
    if (!_udstEmailPattern.hasMatch(email)) return AuthError.notUdstDomain;
    return null;
  }

  static AuthError? validatePassword(String password) {
    if (password.isEmpty) return AuthError.emptyFields;
    if (!_strongPasswordPattern.hasMatch(password)) return AuthError.weakPassword;
    return null;
  }

  static AuthError? validateUniversityId(String id) {
    if (id.isEmpty) return AuthError.emptyFields;
    if (!_universityIdPattern.hasMatch(id)) return AuthError.invalidId;
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

    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with Firebase Auth signInWithEmailAndPassword.
    // Always fail in mock unless credentials match the seeded test account.
    final valid = email.toLowerCase() == MockDataService.currentUser.email.toLowerCase();

    if (!valid) {
      _failedAttempts++;
      return const AuthResult.fail(AuthError.invalidCredentials);
    }

    _failedAttempts = 0;
    state = MockDataService.currentUser;
    return const AuthResult.ok();
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

    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with Firebase Auth createUserWithEmailAndPassword.
    state = MockDataService.currentUser.copyWith(
      name: name.trim(),
      email: email.toLowerCase().trim(),
      universityId: universityId.trim(),
      role: role,
    );
    return const AuthResult.ok();
  }

  void signOut() {
    _failedAttempts = 0;
    state = null;
  }
}
