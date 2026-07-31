import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/paymuster_tokens.dart';

enum PMButtonVariant { primary, secondary, tertiary, danger }

class PMButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PMButtonVariant variant;
  final bool isLoading;

  const PMButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PMButtonVariant.primary,
    this.isLoading = false,
  });

  factory PMButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return PMButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: PMButtonVariant.primary,
      isLoading: isLoading,
    );
  }

  factory PMButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return PMButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: PMButtonVariant.secondary,
      isLoading: isLoading,
    );
  }

  factory PMButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return PMButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: PMButtonVariant.danger,
      isLoading: isLoading,
    );
  }

  factory PMButton.ghost({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return PMButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: PMButtonVariant.tertiary,
      isLoading: isLoading,
    );
  }

  @override
  State<PMButton> createState() => _PMButtonState();
}

class _PMButtonState extends State<PMButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PMMotion.instant,
    );
    // Slight overshoot for tap easing
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isEnabled) return;
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!_isEnabled) return;
    _controller.reverse();
  }

  void _handleTap() {
    if (!_isEnabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;
    double height = 52.0;
    TextStyle textStyle = PMTypography.labelLarge;

    switch (widget.variant) {
      case PMButtonVariant.primary:
        backgroundColor = isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;
        textColor = isDark ? PMColors.brandOnPrimaryDark : PMColors.brandOnPrimaryLight;
        break;
      case PMButtonVariant.secondary:
        backgroundColor = Colors.transparent;
        textColor = isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;
        borderSide = BorderSide(color: isDark ? PMColors.borderStrongDark : PMColors.borderStrongLight);
        break;
      case PMButtonVariant.danger:
        backgroundColor = isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight;
        textColor = isDark ? PMColors.statusOnDangerDark : PMColors.statusOnDangerLight;
        break;
      case PMButtonVariant.tertiary:
        backgroundColor = Colors.transparent;
        textColor = isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;
        height = 44.0;
        break;
    }

    if (!widget.isLoading && _isHovering && _isEnabled && widget.variant == PMButtonVariant.primary) {
      backgroundColor = isDark ? PMColors.brandPrimaryLight : PMColors.brandPrimaryDark; // Slightly adjust for hover
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _isEnabled ? 1.0 : 0.4,
                child: Container(
                  height: height,
                  constraints: const BoxConstraints(minWidth: 88),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.variant == PMButtonVariant.tertiary ? PMSpacing.s2 : PMSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: PMRadius.md,
                    border: Border.fromBorderSide(borderSide),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(textColor),
                          ),
                        ),
                      ] else ...[
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 20, color: textColor),
                          const SizedBox(width: PMSpacing.s2),
                        ],
                        Text(
                          widget.label,
                          style: textStyle.copyWith(color: textColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
