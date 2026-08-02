import 'package:flutter/material.dart';
import '../../../theme/paymuster_tokens.dart';

/// Splash screen shown while auth state is being restored.
/// This screen does NOT perform any navigation — GoRouter redirect
/// handles all routing decisions after auth initialization completes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PMColors.brandPrimaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo/paymuster_logo.png',
              width: 120,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.construction,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PayMuster',
              style: PMTypography.display.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
