import 'package:flutter/material.dart';
import '../../theme/paymuster_tokens.dart';
import '../../components/layout/pm_card.dart';
import '../../components/foundation/pm_button.dart';
import '../../l10n/language_switcher.dart';
import '../../theme/theme_mode_selector.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: PMSpacing.s4),
              // Context Strip (C9) - Simplified for now
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.light_mode, 
                        color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: PMSpacing.s2),
                      Text('24°C', style: PMTypography.label),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight,
                      borderRadius: PMRadius.full,
                    ),
                    child: Text('PRE-SHIFT', style: PMTypography.overline),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: PMSpacing.s2),
                      const ThemeModeSelector(),
                      const LanguageSwitcher(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: PMSpacing.s6),
              
              // Priority Card (C1)
              PMCard.priority(
                accentColor: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTION REQUIRED', 
                      style: PMTypography.overline.copyWith(
                        color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: PMSpacing.s2),
                    Text(
                      'Approve Overtime', 
                      style: PMTypography.headline,
                    ),
                    const SizedBox(height: PMSpacing.s2),
                    Text(
                      '3 workers requested overtime approval for yesterday\'s concrete pour.',
                      style: PMTypography.body,
                    ),
                    const SizedBox(height: PMSpacing.s4),
                    Row(
                      children: [
                        Expanded(
                          child: PMButton.primary(
                            label: 'Review (3)',
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: PMSpacing.s3),
                        Expanded(
                          child: PMButton.secondary(
                            label: 'Dismiss',
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PMSpacing.s6),
              
              // Smart Dock (C10) stub
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    PMButton.primary(
                      label: 'Start Roll Call',
                      icon: Icons.groups,
                      onPressed: () {},
                    ),
                    const SizedBox(width: PMSpacing.s3),
                    PMButton.secondary(
                      label: 'Add Worker',
                      icon: Icons.person_add,
                      onPressed: () {},
                    ),
                    const SizedBox(width: PMSpacing.s3),
                    PMButton.secondary(
                      label: 'Report Issue',
                      icon: Icons.report,
                      onPressed: () {},
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
