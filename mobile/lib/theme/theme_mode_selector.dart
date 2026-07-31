import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'theme_controller.dart';

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<ThemePreference>(
      tooltip: l10n.text('theme'),
      icon: const Icon(Icons.brightness_6_outlined),
      initialValue: controller.preference,
      onSelected: controller.setPreference,
      itemBuilder: (context) => ThemePreference.values
          .map(
            (preference) => PopupMenuItem(
              value: preference,
              child: Row(
                children: [
                  Icon(_iconFor(preference)),
                  const SizedBox(width: 12),
                  Text(l10n.text(switch (preference) {
                    ThemePreference.dark => 'dark',
                    ThemePreference.light => 'light',
                    ThemePreference.amoled => 'amoled',
                    ThemePreference.system => 'system',
                  })),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  IconData _iconFor(ThemePreference preference) => switch (preference) {
        ThemePreference.dark => Icons.dark_mode_outlined,
        ThemePreference.light => Icons.light_mode_outlined,
        ThemePreference.amoled => Icons.brightness_1_outlined,
        ThemePreference.system => Icons.brightness_auto_outlined,
      };
}
