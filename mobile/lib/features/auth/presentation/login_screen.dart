import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).signIn(email, password);
    if (!success && mounted) {
      final errorMessage = ref.read(authControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'Login failed.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PMSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: PMSpacing.s12),
              Center(
                child: Image.asset(
                  'assets/logo/paymuster_logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: PMSpacing.s6),
              Text(
                'Sign in to PayMuster',
                style: PMTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                'Workforce Operating System',
                style: PMTypography.body.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s10),
              PMTextInput(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'name@company.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: PMSpacing.s4),
              PMTextInput(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Enter your password',
                obscureText: true,
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: PMSpacing.s8),
              PMButton.primary(
                label: 'Sign In',
                isLoading: isLoading,
                onPressed: isLoading ? null : _handleLogin,
              ),
              const SizedBox(height: PMSpacing.s6),
              if (authState.status == AuthStatus.unauthenticated)
                Text(
                  'Admin credentials: admin@paymuster.com / admin123',
                  style: PMTypography.caption.copyWith(
                    color: isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
