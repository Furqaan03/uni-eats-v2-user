import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_input_field.dart';
import 'widgets/google_signin_button.dart';

const _kPrefRememberedEmail = 'remembered_email';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefRememberedEmail);
    if (saved != null && mounted) {
      setState(() => _emailController.text = saved);
    }
  }

  Future<void> _persistRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_kPrefRememberedEmail, _emailController.text.trim());
    } else {
      await prefs.remove(_kPrefRememberedEmail);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  String _errorMessage(AuthError? error) {
    return switch (error) {
      AuthError.invalidEmail => 'Please enter a valid email address.',
      AuthError.weakPassword => 'Password must be at least 6 characters.',
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
      await _persistRememberedEmail();
      if (!mounted) return;
      context.go('/home');
    } else {
      setState(() => _error = _errorMessage(result.error));
    }
  }

  Future<void> _signInWithGoogle() async {
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

    ref.listen<String?>(blockedMessageProvider, (previous, next) {
      if (next != null) {
        setState(() => _error = next);
        ref.read(blockedMessageProvider.notifier).state = null;
      }
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // Give the Column at least the viewport height so the trailing
            // Spacer fills a BOUNDED space (pinning the footer to the bottom)
            // rather than an infinite one. A Spacer/Expanded directly inside a
            // SingleChildScrollView otherwise asserts "non-zero flex but
            // unbounded height" — which surfaced on a device whose first frame
            // laid out with a degenerate (zero) size. IntrinsicHeight lets the
            // Column grow past the viewport and scroll when content is taller.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
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
                'Sign in to your account',
                style: AppTypography.body.copyWith(color: textSecondary),
              ),
              const SizedBox(height: 40),
              AuthInputField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
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
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? true),
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Remember me', style: AppTypography.body.copyWith(color: textSecondary)),
                  ],
                ),
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
              const AuthOrDivider(),
              const SizedBox(height: 16),
              GoogleSignInButton(
                loading: _isGoogleLoading,
                onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
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
                  'Uni Eats · Test build',
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
