import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleSignInButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google_logo.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: AppTypography.body.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A horizontal "── or ──" divider used between the email/password form and
/// social sign-in options.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Row(
      children: [
        Expanded(child: Divider(color: border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('or', style: AppTypography.caption.copyWith(color: textSecondary)),
        ),
        Expanded(child: Divider(color: border)),
      ],
    );
  }
}
