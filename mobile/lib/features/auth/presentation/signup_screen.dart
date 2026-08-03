import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import 'widgets/google_sign_in_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  _PasswordStrength get _passwordStrength {
    final pw = _passwordController.text;
    if (pw.isEmpty) return _PasswordStrength.empty;
    int score = 0;
    if (pw.length >= 6) score++;
    if (pw.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[a-z]').hasMatch(pw)) score++;
    if (RegExp(r'\d').hasMatch(pw)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
    if (score <= 1) return _PasswordStrength.weak;
    if (score <= 3) return _PasswordStrength.fair;
    if (score <= 4) return _PasswordStrength.good;
    return _PasswordStrength.strong;
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authControllerProvider.notifier).signUp(
            email,
            password,
            name,
          );

      if (success && mounted) {
        // Navigate to verification screen — GoRouter handles this via pendingVerification status
        context.go('/verify-email');
      } else if (!success && mounted) {
        final errorMessage = ref.read(authControllerProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Sign up failed.'),
            backgroundColor: PMColors.statusDangerDark,
          ),
        );
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
    final strength = _passwordStrength;

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
                  'Create Account',
                  style: PMTypography.display.copyWith(color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join PayMuster to manage your workforce.',
                  style: PMTypography.bodyLarge.copyWith(
                    color: isDark
                        ? PMColors.textSecondaryDark
                        : PMColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                PMTextInput(
                  labelText: 'Full Name',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 16),
                PMTextInput(
                  labelText: 'Email',
                  controller: _emailController,
                  prefixIcon: const Icon(Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Please enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                PMTextInput(
                  labelText: 'Password',
                  controller: _passwordController,
                  prefixIcon: const Icon(Icons.lock_outline),
                  obscureText: _obscurePassword,
                  validator: (value) => value == null || value.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
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
                // Password strength meter
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: strength.progress,
                      backgroundColor:
                          isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight,
                      valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        strength.label,
                        style: PMTypography.caption.copyWith(
                          color: strength.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          _strengthIndicator('6+', _passwordController.text.length >= 6, isDark),
                          _strengthIndicator('A-Z', RegExp(r'[A-Z]').hasMatch(_passwordController.text), isDark),
                          _strengthIndicator('0-9', RegExp(r'\d').hasMatch(_passwordController.text), isDark),
                          _strengthIndicator('!@#', RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text), isDark),
                        ],
                      ),
                    ],
                  ),
                ],
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
                  label: 'Sign Up',
                  isLoading: authState.status == AuthStatus.loading,
                  onPressed: _signUp,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                PMGoogleSignInButton(
                  isLoading: authState.status == AuthStatus.loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _strengthIndicator(String label, bool met, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 12,
          color: met
              ? PMColors.statusSuccessDark
              : (isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: PMTypography.overline.copyWith(
            color: met
                ? PMColors.statusSuccessDark
                : (isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight),
          ),
        ),
      ],
    );
  }
}

enum _PasswordStrength {
  empty(0, 'Empty', Colors.grey),
  weak(0.2, 'Weak', Color(0xFFEF4444)),
  fair(0.5, 'Fair', Color(0xFFFDBA2D)),
  good(0.75, 'Good', Color(0xFF10B981)),
  strong(1.0, 'Strong', Color(0xFF15D1C2));

  const _PasswordStrength(this.progress, this.label, this.color);
  final double progress;
  final String label;
  final Color color;
}
