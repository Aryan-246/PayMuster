import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/language_controller.dart';
import '../../../theme/theme_controller.dart';
import 'theme/admin_tokens.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final languageController = LanguageScope.of(context);

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Preferences',
                  style: AdminTypography.headlineLgMobile.copyWith(
                    color: AdminColors.onSurface,
                  ),
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  'Manage the preferences stored for this browser.',
                  style: AdminTypography.bodyMd.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AdminSpacing.lg),
                _PreferencePanel(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  child: DropdownButtonFormField<ThemePreference>(
                    initialValue: themeController.preference,
                    decoration: const InputDecoration(labelText: 'Theme'),
                    dropdownColor: AdminColors.surfaceContainerHigh,
                    items: ThemePreference.values
                        .map(
                          (preference) => DropdownMenuItem(
                            value: preference,
                            child: Text(themePreferenceLabel(preference)),
                          ),
                        )
                        .toList(),
                    onChanged: (preference) {
                      if (preference != null) {
                        themeController.setPreference(preference);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AdminSpacing.md),
                _PreferencePanel(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  child: DropdownButtonFormField<AppLanguage>(
                    initialValue: languageController.language,
                    decoration: const InputDecoration(
                      labelText: 'Application language',
                    ),
                    dropdownColor: AdminColors.surfaceContainerHigh,
                    items: AppLanguage.values
                        .map(
                          (language) => DropdownMenuItem(
                            value: language,
                            child: Text(language.label),
                          ),
                        )
                        .toList(),
                    onChanged: (language) {
                      if (language != null) {
                        languageController.setLanguage(language);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _PreferencePanel({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainerLow,
        borderRadius: AdminRadius.lg,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AdminColors.primaryContainer),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                title,
                style: AdminTypography.titleMd.copyWith(
                  color: AdminColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          child,
        ],
      ),
    );
  }
}
