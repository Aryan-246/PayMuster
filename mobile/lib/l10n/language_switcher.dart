import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'language_controller.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<AppLanguage>(
      tooltip: l10n.text('language'),
      icon: const Icon(Icons.language_outlined),
      initialValue: controller.language,
      onSelected: controller.setLanguage,
      itemBuilder: (context) => AppLanguage.values.map((language) => PopupMenuItem(value: language, child: Text(language.label))).toList(),
    );
  }
}
