import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  // Step 1: OTP input, Step 2: New password
  int _step = 1;

  // OTP controllers
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Password controllers
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _resetSuccess = false;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isResending = false;

  late AnimationController _successAnimController;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _startCooldown(60);
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
    _passwordController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _successAnimController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
  }

  void _onOtpKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpControllers[index - 1].clear();
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  void _proceedToPasswordStep() {
    final otp = _otpValue;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _handleResetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
      return;
    }

    final email = ref.read(authControllerProvider).pendingResetEmail;
    if (email == null) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPasswordComplete(email, _otpValue, password);

    if (success && mounted) {
      setState(() => _resetSuccess = true);
      _successAnimController.forward();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/login');
    } else if (mounted) {
      final errorMessage = ref.read(authControllerProvider).errorMessage;
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: PMColors.statusDangerDark,
          ),
        );
        // If OTP was invalid, go back to step 1
        if (errorMessage.toLowerCase().contains('code') ||
            errorMessage.toLowerCase().contains('otp') ||
            errorMessage.toLowerCase().contains('expired')) {
          for (final c in _otpControllers) {
            c.clear();
          }
          setState(() => _step = 1);
          _otpFocusNodes[0].requestFocus();
        }
      }
    }
  }

  Future<void> _handleResend() async {
    final email = ref.read(authControllerProvider).pendingResetEmail;
    if (email == null || _cooldownSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);
    final success =
        await ref.read(authControllerProvider.notifier).requestPasswordReset(email);
    if (mounted) {
      setState(() => _isResending = false);
      if (success) {
        _startCooldown(60);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new reset code has been sent.'),
            backgroundColor: PMColors.statusSuccessDark,
          ),
        );
      }
    }
  }

  // Password strength meter
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final email = authState.pendingResetEmail ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              context.go('/forgot-password');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
              _resetSuccess
                  ? _buildSuccessView(textColor, isDark)
                  : _step == 1
                      ? _buildOtpStep(textColor, isDark, isLoading, email)
                      : _buildPasswordStep(textColor, isDark, isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(Color textColor, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 80),
        ScaleTransition(
          scale: _successScale,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PMColors.statusSuccessDark.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 48,
              color: PMColors.statusSuccessDark,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Password Reset!',
          style: PMTypography.display.copyWith(color: textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been changed. Redirecting to sign in…',
          style: PMTypography.bodyLarge.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOtpStep(Color textColor, bool isDark, bool isLoading, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PMColors.accentOrangeDark.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 36,
              color: PMColors.accentOrangeDark,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Enter reset code',
          style: PMTypography.display.copyWith(color: textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Enter the 6-digit code sent to',
          style: PMTypography.body.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: PMTypography.labelLarge.copyWith(color: PMColors.brandPrimaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              width: 48,
              height: 56,
              margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) => _onOtpKeyEvent(index, event),
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  enabled: !isLoading,
                  style: PMTypography.display.copyWith(
                    color: PMColors.accentOrangeDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? PMColors.borderStrongDark : PMColors.borderStrongLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PMColors.accentOrangeDark, width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onOtpDigitChanged(index, value),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        PMButton.primary(
          label: 'Continue',
          isLoading: isLoading,
          onPressed: isLoading ? null : _proceedToPasswordStep,
        ),
        const SizedBox(height: 24),
        Center(
          child: _isResending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _cooldownSeconds > 0 ? null : _handleResend,
                  child: Text(
                    _cooldownSeconds > 0
                        ? 'Resend code in ${_cooldownSeconds}s'
                        : 'Resend reset code',
                    style: PMTypography.label.copyWith(
                      color: _cooldownSeconds > 0
                          ? (isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight)
                          : PMColors.brandPrimaryDark,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(Color textColor, bool isDark, bool isLoading) {
    final strength = _passwordStrength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'Create new password',
          style: PMTypography.display.copyWith(color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Your new password must be at least 6 characters.',
          style: PMTypography.bodyLarge.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 32),
        PMTextInput(
          labelText: 'New Password',
          controller: _passwordController,
          prefixIcon: const Icon(Icons.lock_outline),
          obscureText: _obscurePassword,
          enabled: !isLoading,
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
        const SizedBox(height: 12),
        // Strength meter
        if (_passwordController.text.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: strength.progress,
              backgroundColor: isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight,
              valueColor: AlwaysStoppedAnimation<Color>(strength.color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                strength.label,
                style: PMTypography.caption.copyWith(
                  color: strength.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _strengthCheck('6+ chars', _passwordController.text.length >= 6, isDark),
              const SizedBox(width: 8),
              _strengthCheck('A-Z', RegExp(r'[A-Z]').hasMatch(_passwordController.text), isDark),
              const SizedBox(width: 8),
              _strengthCheck('0-9', RegExp(r'\d').hasMatch(_passwordController.text), isDark),
              const SizedBox(width: 8),
              _strengthCheck('!@#', RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text), isDark),
            ],
          ),
          const SizedBox(height: 16),
        ],
        PMTextInput(
          labelText: 'Confirm Password',
          controller: _confirmController,
          prefixIcon: const Icon(Icons.lock_outline),
          obscureText: _obscureConfirm,
          enabled: !isLoading,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirm = !_obscureConfirm;
              });
            },
          ),
        ),
        const SizedBox(height: 32),
        PMButton.primary(
          label: 'Reset Password',
          isLoading: isLoading,
          onPressed: isLoading ? null : _handleResetPassword,
        ),
      ],
    );
  }

  Widget _strengthCheck(String label, bool met, bool isDark) {
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
