import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final success = await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(email);
      if (success && mounted) {
        // Navigate to reset password screen to enter OTP
        context.go('/reset-password');
      } else if (mounted) {
        final errorMessage = ref.read(authControllerProvider).errorMessage;
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: PMColors.statusDangerDark,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo/paymuster_logo.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.construction,
                      size: 64,
                      color: isDark ? Colors.white : PMColors.textPrimaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reset Password',
                  style: PMTypography.display.copyWith(color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email address and we will send you a code to reset your password.',
                  style: PMTypography.bodyLarge.copyWith(
                    color: isDark
                        ? PMColors.textSecondaryDark
                        : PMColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                PMTextInput(
                  labelText: 'Email',
                  controller: _emailController,
                  prefixIcon: const Icon(Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Please enter a valid email'
                      : null,
                ),
                if (authState.status == AuthStatus.error) ...[
                  const SizedBox(height: 16),
                  Text(
                    authState.errorMessage ?? 'An error occurred',
                    style: PMTypography.caption
                        .copyWith(color: PMColors.statusDangerDark),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                PMButton.primary(
                  label: 'Send Reset Code',
                  isLoading: authState.status == AuthStatus.loading,
                  onPressed: _requestReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
