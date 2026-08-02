import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isResending = false;
  bool _verificationSuccess = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _successAnimController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
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

  String get _otpValue =>
      _otpControllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otpValue.length == 6) {
      _handleVerify();
    }
  }

  void _onOtpKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _clearOtp() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handleVerify() async {
    final otp = _otpValue;
    if (otp.length != 6) return;

    final email = ref.read(authControllerProvider).pendingVerificationEmail;
    if (email == null) return;

    final success = await ref.read(authControllerProvider.notifier).verifyEmail(email, otp);
    if (success && mounted) {
      setState(() => _verificationSuccess = true);
      _successAnimController.forward();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/login');
    } else if (mounted) {
      _clearOtp();
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

  Future<void> _handleResend() async {
    final email = ref.read(authControllerProvider).pendingVerificationEmail;
    if (email == null || _cooldownSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);
    final success =
        await ref.read(authControllerProvider.notifier).resendVerification(email);
    if (mounted) {
      setState(() => _isResending = false);
      if (success) {
        _startCooldown(60);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new verification code has been sent.'),
            backgroundColor: PMColors.statusSuccessDark,
          ),
        );
      } else {
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
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final email = authState.pendingVerificationEmail ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.go('/login'),
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
              _verificationSuccess ? _buildSuccessView(textColor, isDark) : _buildOtpView(textColor, isDark, isLoading, email),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(Color textColor, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
          'Email Verified!',
          style: PMTypography.display.copyWith(color: textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your account is ready. Redirecting to sign in…',
          style: PMTypography.bodyLarge.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOtpView(Color textColor, bool isDark, bool isLoading, String email) {
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
              color: PMColors.brandPrimaryDark.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 36,
              color: PMColors.brandPrimaryDark,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Verify your email',
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
        // OTP digit boxes
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
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  enabled: !isLoading,
                  style: PMTypography.display.copyWith(
                    color: PMColors.brandPrimaryDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: isDark
                        ? PMColors.bgSurfaceDark
                        : PMColors.bgSurfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? PMColors.borderStrongDark
                            : PMColors.borderStrongLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? PMColors.borderDefaultDark
                            : PMColors.borderDefaultLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: PMColors.brandPrimaryDark,
                        width: 2,
                      ),
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
          label: 'Verify Email',
          isLoading: isLoading,
          onPressed: isLoading ? null : _handleVerify,
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
                        : 'Resend verification code',
                    style: PMTypography.label.copyWith(
                      color: _cooldownSeconds > 0
                          ? (isDark
                              ? PMColors.textTertiaryDark
                              : PMColors.textTertiaryLight)
                          : PMColors.brandPrimaryDark,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text(
              'Back to Sign In',
              style: PMTypography.label.copyWith(
                color: isDark
                    ? PMColors.textSecondaryDark
                    : PMColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
