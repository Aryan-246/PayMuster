import 'package:flutter/material.dart';

enum AppLanguage { english, hindi, punjabi }

extension AppLanguageDetails on AppLanguage {
  Locale get locale => switch (this) {
        AppLanguage.english => const Locale('en', 'IN'),
        AppLanguage.hindi => const Locale('hi', 'IN'),
        AppLanguage.punjabi => const Locale('pa', 'IN'),
      };

  String get label => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'हिन्दी',
        AppLanguage.punjabi => 'ਪੰਜਾਬੀ',
      };
}

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const delegate = _AppLocalizationsDelegate();
  static const supportedLocales = [Locale('en', 'IN'), Locale('hi', 'IN'), Locale('pa', 'IN')];

  static AppLocalizations of(BuildContext context) => Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String key) => _messages[locale.languageCode]?[key] ?? _messages['en']![key] ?? key;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => const ['en', 'hi', 'pa'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _messages = <String, Map<String, String>>{
  'en': {
    'language': 'Language', 'theme': 'Theme', 'dark': 'Dark', 'light': 'Light', 'amoled': 'AMOLED', 'system': 'System',
    'fieldOperations': 'Field Operations', 'today': 'Today', 'dashboard': 'Dashboard', 'staff': 'Staff', 'attendance': 'Attendance', 'payroll': 'Payroll',
    'operationsOverview': 'Operations overview', 'heroDescription': 'A refined, localized foundation for the mobile experience.', 'openDashboard': 'Open dashboard', 'premiumShell': 'Premium shell ready for modules', 'quickActions': 'Quick actions', 'reusableStates': 'Reusable localized states', 'noPendingActions': 'No pending actions', 'themeReady': 'Theme and language preferences are ready for future feature modules.', 'workers': 'Workers', 'pending': 'Pending',
  },
  'hi': {
    'language': 'भाषा', 'theme': 'थीम', 'dark': 'डार्क', 'light': 'लाइट', 'amoled': 'AMOLED', 'system': 'सिस्टम',
    'fieldOperations': 'फील्ड ऑपरेशन', 'today': 'आज', 'dashboard': 'डैशबोर्ड', 'staff': 'कर्मचारी', 'attendance': 'उपस्थिति', 'payroll': 'पेरोल',
    'operationsOverview': 'ऑपरेशन सारांश', 'heroDescription': 'मोबाइल अनुभव के लिए एक बेहतर, स्थानीयकृत आधार।', 'openDashboard': 'डैशबोर्ड खोलें', 'premiumShell': 'मॉड्यूल के लिए प्रीमियम शेल तैयार है', 'quickActions': 'त्वरित कार्य', 'reusableStates': 'स्थानीयकृत पुन: उपयोगी स्थिति', 'noPendingActions': 'कोई कार्य लंबित नहीं', 'themeReady': 'थीम और भाषा प्राथमिकताएँ भविष्य के मॉड्यूल के लिए तैयार हैं।', 'workers': 'कर्मचारी', 'pending': 'लंबित',
  },
  'pa': {
    'language': 'ਭਾਸ਼ਾ', 'theme': 'ਥੀਮ', 'dark': 'ਡਾਰਕ', 'light': 'ਲਾਈਟ', 'amoled': 'AMOLED', 'system': 'ਸਿਸਟਮ',
    'fieldOperations': 'ਫੀਲਡ ਓਪਰੇਸ਼ਨ', 'today': 'ਅੱਜ', 'dashboard': 'ਡੈਸ਼ਬੋਰਡ', 'staff': 'ਕਰਮਚਾਰੀ', 'attendance': 'ਹਾਜ਼ਰੀ', 'payroll': 'ਤਨਖਾਹ',
    'operationsOverview': 'ਓਪਰੇਸ਼ਨ ਝਲਕ', 'heroDescription': 'ਮੋਬਾਈਲ ਅਨੁਭਵ ਲਈ ਇੱਕ ਬਿਹਤਰ, ਸਥਾਨਕਕ੍ਰਿਤ ਆਧਾਰ।', 'openDashboard': 'ਡੈਸ਼ਬੋਰਡ ਖੋਲ੍ਹੋ', 'premiumShell': 'ਮੋਡੀਊਲਾਂ ਲਈ ਪ੍ਰੀਮੀਅਮ ਸ਼ੈੱਲ ਤਿਆਰ ਹੈ', 'quickActions': 'ਤੁਰੰਤ ਕਾਰਵਾਈਆਂ', 'reusableStates': 'ਸਥਾਨਕਕ੍ਰਿਤ ਮੁੜ ਵਰਤੋਂਯੋਗ ਸਥਿਤੀਆਂ', 'noPendingActions': 'ਕੋਈ ਕਾਰਵਾਈ ਲੰਬਿਤ ਨਹੀਂ', 'themeReady': 'ਥੀਮ ਅਤੇ ਭਾਸ਼ਾ ਤਰਜੀਹਾਂ ਭਵਿੱਖ ਦੇ ਮੋਡੀਊਲਾਂ ਲਈ ਤਿਆਰ ਹਨ।', 'workers': 'ਕਰਮਚਾਰੀ', 'pending': 'ਲੰਬਿਤ',
  },
};
