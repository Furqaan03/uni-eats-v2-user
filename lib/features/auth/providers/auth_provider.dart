import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../../../services/mock_data_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier() : super(MockDataService.currentUser);

  // TODO: Replace with Firebase Auth and server-side validation.
  Future<bool> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isNotEmpty && password.length >= 6) {
      state = MockDataService.currentUser;
      return true;
    }
    return false;
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String universityId,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (name.isNotEmpty && email.isNotEmpty && password.length >= 6 && universityId.isNotEmpty) {
      state = MockDataService.currentUser.copyWith(
        name: name,
        email: email,
        universityId: universityId,
        role: role,
      );
      return true;
    }
    return false;
  }

  void signOut() {
    state = null;
  }
}
