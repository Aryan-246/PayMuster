import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';
import 'widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  bool _obscurePassword = true;

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
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
      return;
    }

    final success =
        await ref.read(authControllerProvider.notifier).signIn(email, password);
    if (success) {
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'paymuster.remembered_user', email.toLowerCase());
      }
      // GoRouter handles navigation via state change
    } else if (mounted) {
      final authState = ref.read(authControllerProvider);

      // If email not verified, navigate to verification screen
      if (authState.status == AuthStatus.pendingVerification) {
        context.go('/verify-email');
        return;
      }

      final errorMessage = authState.errorMessage;
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
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.construction,
                    size: 80,
                    color: isDark ? Colors.white : PMColors.textPrimaryLight,
                  ),
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
                  color: isDark
                      ? PMColors.textSecondaryDark
                      : PMColors.textSecondaryLight,
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
                obscureText: _obscurePassword,
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: PMSpacing.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                        activeColor: PMColors.brandPrimaryDark,
                      ),
                      Text(
                        'Remember Me',
                        style: PMTypography.caption.copyWith(
                          color: isDark
                              ? PMColors.textSecondaryDark
                              : PMColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text(
                      'Forgot Password?',
                      style: PMTypography.caption.copyWith(
                        color: PMColors.brandPrimaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PMSpacing.s6),
              PMButton.primary(
                label: 'Sign In',
                isLoading: isLoading,
                onPressed: isLoading ? null : _handleLogin,
              ),
              const SizedBox(height: PMSpacing.s4),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: PMSpacing.s4),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: PMSpacing.s4),
              PMGoogleSignInButton(isLoading: isLoading),
              const SizedBox(height: PMSpacing.s6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Don\'t have an account?',
                    style: PMTypography.caption.copyWith(
                      color: isDark
                          ? PMColors.textSecondaryDark
                          : PMColors.textSecondaryLight,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: Text(
                      'Sign Up',
                      style: PMTypography.caption.copyWith(
                        color: PMColors.brandPrimaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
