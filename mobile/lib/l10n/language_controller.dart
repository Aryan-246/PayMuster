import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

class LanguageController extends ChangeNotifier {
  static const _storageKey = 'paymuster.language';
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    _language = AppLanguage.values.firstWhere((value) => value.name == stored, orElse: () => AppLanguage.english);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, language.name);
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({required super.notifier, required super.child, super.key});

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
