import 'package:flutter/material.dart';
import '../../theme/paymuster_tokens.dart';

class PMTextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final int? maxLines;

  const PMTextInput({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderDefault = isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;
    final borderFocus = isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;
    final borderError = isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight;
    final fill = isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight;
    final fillFocus = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (labelText != null) ...[
            Text(
              labelText!,
              style: PMTypography.label.copyWith(
                color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: PMSpacing.s2),
          ],
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            enabled: enabled,
            maxLines: maxLines,
            style: PMTypography.body.copyWith(
              color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: PMTypography.body.copyWith(
                color: isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight,
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return fillFocus;
                }
                return fill;
              }),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: PMSpacing.s4,
                vertical: PMSpacing.s4, // Approx aligns to 52px height depending on text height
              ),
              border: OutlineInputBorder(
                borderRadius: PMRadius.sm,
                borderSide: BorderSide(color: borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: PMRadius.sm,
                borderSide: BorderSide(color: borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: PMRadius.sm,
                borderSide: BorderSide(color: borderFocus, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: PMRadius.sm,
                borderSide: BorderSide(color: borderError, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: PMRadius.sm,
                borderSide: BorderSide(color: borderError, width: 2),
              ),
              errorText: errorText,
              errorStyle: PMTypography.caption.copyWith(
                color: borderError,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
