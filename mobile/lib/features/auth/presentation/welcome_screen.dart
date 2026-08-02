import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import 'widgets/google_sign_in_button.dart';
import '../domain/auth_state.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final cardColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo/paymuster_logo.png',
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.construction,
                        size: 80,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to PayMuster',
                      style: PMTypography.display.copyWith(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The all-in-one platform for construction workforce management.',
                      style: PMTypography.bodyLarge.copyWith(
                        color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PMButton.primary(
                      label: 'Login',
                      onPressed: () => context.push('/login'),
                    ),
                    const SizedBox(height: 16),
                    PMButton.secondary(
                      label: 'Create Account',
                      onPressed: () => context.push('/signup'),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    PMGoogleSignInButton(
                      isLoading: authState.status == AuthStatus.loading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
