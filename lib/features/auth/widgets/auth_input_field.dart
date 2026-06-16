import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;

  const AuthInputField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary),
      ),
    );
  }
}
