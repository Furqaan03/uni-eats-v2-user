import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Shown only while Firebase Auth restores the previous session — keeps the
/// router from briefly flashing /login for an already-signed-in user before
/// `authStateChanges()` has had a chance to fire.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Uni Eats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
