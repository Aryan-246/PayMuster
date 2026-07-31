import 'package:flutter/material.dart';
import '../../theme/paymuster_tokens.dart';

enum PMCardTier { priority, standard, stat }

class PMCard extends StatelessWidget {
  final Widget child;
  final PMCardTier tier;
  final VoidCallback? onTap;
  final Color? accentColor; // Used for left accent on Priority, top accent on Stat

  const PMCard({
    super.key,
    required this.child,
    this.tier = PMCardTier.standard,
    this.onTap,
    this.accentColor,
  });

  factory PMCard.priority({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    Color? accentColor,
  }) {
    return PMCard(
      key: key,
      tier: PMCardTier.priority,
      onTap: onTap,
      accentColor: accentColor,
      child: child,
    );
  }

  factory PMCard.standard({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return PMCard(
      key: key,
      tier: PMCardTier.standard,
      onTap: onTap,
      child: child,
    );
  }

  factory PMCard.stat({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    Color? accentColor,
  }) {
    return PMCard(
      key: key,
      tier: PMCardTier.stat,
      onTap: onTap,
      accentColor: accentColor,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    EdgeInsets padding;
    BorderRadius radius;
    List<BoxShadow>? shadow;
    BorderSide defaultBorder = BorderSide(
      color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
    );
    
    BoxDecoration decoration;

    switch (tier) {
      case PMCardTier.priority:
        padding = const EdgeInsets.all(PMSpacing.s5);
        radius = PMRadius.lg;
        shadow = isDark ? PMElevation.raisedDark : PMElevation.raisedLight;
        decoration = BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          boxShadow: shadow,
          border: Border(
            top: defaultBorder,
            right: defaultBorder,
            bottom: defaultBorder,
            left: accentColor != null 
                ? BorderSide(color: accentColor!, width: 4.0) 
                : defaultBorder,
          ),
        );
        break;
      case PMCardTier.standard:
        padding = const EdgeInsets.all(PMSpacing.s4);
        radius = PMRadius.md;
        shadow = null; // Flat
        decoration = BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          border: Border.fromBorderSide(defaultBorder),
        );
        break;
      case PMCardTier.stat:
        padding = const EdgeInsets.all(PMSpacing.s3);
        radius = PMRadius.sm;
        shadow = null;
        decoration = BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          border: Border(
            top: accentColor != null 
                ? BorderSide(color: accentColor!, width: 2.0) 
                : defaultBorder,
            right: defaultBorder,
            bottom: defaultBorder,
            left: defaultBorder,
          ),
        );
        break;
    }

    Widget content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return content;
  }
}
