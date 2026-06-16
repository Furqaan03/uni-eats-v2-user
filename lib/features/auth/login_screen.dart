import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_input_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _errorMessage(AuthError? error) {
    return switch (error) {
      AuthError.invalidEmail => 'Please enter a valid email address.',
      AuthError.notUdstDomain => 'Only @udst.edu.qa email addresses are accepted.',
      AuthError.weakPassword =>
        'Password must be 8+ characters with uppercase, lowercase, and a digit.',
      AuthError.tooManyAttempts =>
        'Too many failed attempts. Please try again later.',
      // Generic message — never reveal which field is wrong.
      _ => 'Invalid email or password.',
    };
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      context.go('/home');
    } else {
      setState(() => _error = _errorMessage(result.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text(
                'Welcome back',
                style: AppTypography.displayLarge.copyWith(color: textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with your UDST email',
                style: AppTypography.body.copyWith(color: textSecondary),
              ),
              const SizedBox(height: 40),
              AuthInputField(
                controller: _emailController,
                label: 'UDST Email',
                hint: 'you@udst.edu.qa',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthInputField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
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
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/signup'),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: AppTypography.body.copyWith(color: textSecondary),
                      children: [
                        TextSpan(
                          text: 'Sign Up',
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
              const Spacer(),
              Center(
                child: Text(
                  'Students & faculty only · @udst.edu.qa',
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
