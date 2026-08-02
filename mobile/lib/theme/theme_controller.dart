import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'paymuster_theme.dart';

enum ThemePreference { dark, light, amoled, system }

class ThemeController extends ChangeNotifier {
  static const _storageKey = 'paymuster.theme-mode';

  ThemePreference _preference = ThemePreference.system;

  ThemePreference get preference => _preference;

  ThemeMode get materialThemeMode => switch (_preference) {
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.amoled => ThemeMode.dark,
        ThemePreference.system => ThemeMode.system,
      };

  ThemeData get darkTheme => _preference == ThemePreference.amoled
      ? PayMusterTheme.amoledTheme()
      : PayMusterTheme.darkTheme();

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    _preference = ThemePreference.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => ThemePreference.system,
    );
    notifyListeners();
  }

  Future<void> setPreference(ThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, preference.name);
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({required super.notifier, required super.child, super.key});

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

String themePreferenceLabel(ThemePreference preference) => switch (preference) {
      ThemePreference.dark => 'Dark',
      ThemePreference.light => 'Light',
      ThemePreference.amoled => 'AMOLED',
      ThemePreference.system => 'System',
    };
