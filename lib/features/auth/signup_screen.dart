import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../models/user_model.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_input_field.dart';
import 'widgets/google_signin_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.student;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _errorMessage(AuthError? error) {
    return switch (error) {
      AuthError.emptyFields => 'Please fill in all fields.',
      AuthError.invalidEmail => 'Please enter a valid email address.',
      AuthError.weakPassword => 'Password must be at least 6 characters.',
      AuthError.emailInUseDifferentPassword =>
        'An account with this email already exists with a different password. Try signing in instead.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  Future<void> _signUp() async {
    // Client-side pre-check to give immediate feedback before async call.
    final quickErrors = [
      if (_nameController.text.trim().isEmpty) AuthError.emptyFields,
      AuthNotifier.validateEmail(_emailController.text.trim()),
      AuthNotifier.validatePassword(_passwordController.text),
      AuthNotifier.validateUniversityId(_idController.text.trim()),
    ].whereType<AuthError>().toList();

    if (quickErrors.isNotEmpty) {
      setState(() => _error = _errorMessage(quickErrors.first));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          universityId: _idController.text.trim(),
          role: _role,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      context.go('/home');
    } else {
      setState(() => _error = _errorMessage(result.error));
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (error != null) {
      setState(() => _error = error);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account', style: AppTypography.heading.copyWith(color: textPrimary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              AuthInputField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              AuthInputField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthInputField(
                controller: _idController,
                label: 'University ID',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              AuthInputField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 6),
              Text(
                'At least 6 characters',
                style: AppTypography.caption.copyWith(color: textSecondary),
              ),
              const SizedBox(height: 16),
              Text('Account Type', style: AppTypography.caption.copyWith(color: textSecondary)),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.student, label: Text('Student')),
                  ButtonSegment(value: UserRole.faculty, label: Text('Faculty')),
                ],
                selected: {_role},
                onSelectionChanged: (value) => setState(() => _role = value.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 16),
              const AuthOrDivider(),
              const SizedBox(height: 16),
              GoogleSignInButton(
                loading: _isGoogleLoading,
                onPressed: (_isLoading || _isGoogleLoading) ? null : _signUpWithGoogle,
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: AppTypography.body.copyWith(color: textSecondary),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: AppTypography.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
