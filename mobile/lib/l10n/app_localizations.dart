import 'package:flutter/material.dart';

enum AppLanguage { english, hindi, punjabi, bhojpuri, hinglish }

extension AppLanguageDetails on AppLanguage {
  Locale get locale => switch (this) {
        AppLanguage.english => const Locale('en', 'IN'),
        AppLanguage.hindi => const Locale('hi', 'IN'),
        AppLanguage.punjabi => const Locale('pa', 'IN'),
        AppLanguage.bhojpuri => const Locale('hi', 'BH'), // Use 'hi' language code for Material compatibility
        AppLanguage.hinglish => const Locale('hi', 'EN'), // Custom for Hinglish
      };

  String get label => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'हिन्दी',
        AppLanguage.punjabi => 'ਪੰਜਾਬੀ',
        AppLanguage.bhojpuri => 'भोजपुरी',
        AppLanguage.hinglish => 'Hinglish',
      };
}

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const delegate = _AppLocalizationsDelegate();
  static const supportedLocales = [Locale('en', 'IN'), Locale('hi', 'IN'), Locale('pa', 'IN'), Locale('hi', 'BH'), Locale('hi', 'EN')];

  static AppLocalizations of(BuildContext context) => Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String key) {
    final localeKey = '${locale.languageCode}_${locale.countryCode}';
    return _messages[localeKey]?[key] ?? _messages[locale.languageCode]?[key] ?? _messages['en']![key] ?? key;
  }
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
    'adminDashboard': 'Super Admin Dashboard', 'ownerDashboard': 'Owner Dashboard', 'managerDashboard': 'Site Manager Dashboard', 'supervisorDashboard': 'Supervisor Dashboard', 'workerDashboard': 'Worker Dashboard',
    'adminWelcome': 'Welcome, Super Admin. Full system access.', 'ownerWelcome': 'Welcome, Company Owner. View company metrics.', 'managerWelcome': 'Welcome, Site Manager. Manage your assigned sites.', 'supervisorWelcome': 'Welcome, Supervisor. Oversee workers and attendance.', 'workerWelcome': 'Welcome, Worker. View your shifts and payroll.',
    'totalEarnings': 'Total Earnings (This Month)', 'viewPayslips': 'View Payslips',
  },
  'hi': {
    'language': 'भाषा', 'theme': 'थीम', 'dark': 'डार्क', 'light': 'लाइट', 'amoled': 'AMOLED', 'system': 'सिस्टम',
    'fieldOperations': 'फील्ड ऑपरेशन', 'today': 'आज', 'dashboard': 'डैशबोर्ड', 'staff': 'कर्मचारी', 'attendance': 'उपस्थिति', 'payroll': 'पेरोल',
    'operationsOverview': 'ऑपरेशन सारांश', 'heroDescription': 'मोबाइल अनुभव के लिए एक बेहतर, स्थानीयकृत आधार।', 'openDashboard': 'डैशबोर्ड खोलें', 'premiumShell': 'मॉड्यूल के लिए प्रीमियम शेल तैयार है', 'quickActions': 'त्वरित कार्य', 'reusableStates': 'स्थानीयकृत पुन: उपयोगी स्थिति', 'noPendingActions': 'कोई कार्य लंबित नहीं', 'themeReady': 'थीम और भाषा प्राथमिकताएँ भविष्य के मॉड्यूल के लिए तैयार हैं।', 'workers': 'कर्मचारी', 'pending': 'लंबित',
    'adminDashboard': 'सुपर एडमिन डैशबोर्ड', 'ownerDashboard': 'मालिक डैशबोर्ड', 'managerDashboard': 'साइट मैनेजर डैशबोर्ड', 'supervisorDashboard': 'सुपरवाइजर डैशबोर्ड', 'workerDashboard': 'कर्मचारी डैशबोर्ड',
    'adminWelcome': 'सुपर एडमिन का स्वागत है। पूर्ण सिस्टम पहुंच।', 'ownerWelcome': 'मालिक का स्वागत है। कंपनी मेट्रिक्स देखें।', 'managerWelcome': 'साइट मैनेजर का स्वागत है। अपनी साइटों का प्रबंधन करें।', 'supervisorWelcome': 'सुपरवाइजर का स्वागत है। कर्मचारियों और उपस्थिति की देखरेख करें।', 'workerWelcome': 'कर्मचारी का स्वागत है। अपनी शिफ्ट और पेरोल देखें।',
    'totalEarnings': 'कुल आय (इस महीने)', 'viewPayslips': 'पेस्लिप देखें',
  },
  'pa': {
    'language': 'ਭਾਸ਼ਾ', 'theme': 'ਥੀਮ', 'dark': 'ਡਾਰਕ', 'light': 'ਲਾਈਟ', 'amoled': 'AMOLED', 'system': 'ਸਿਸਟਮ',
    'fieldOperations': 'ਫੀਲਡ ਓਪਰੇਸ਼ਨ', 'today': 'ਅੱਜ', 'dashboard': 'ਡੈਸ਼ਬੋਰਡ', 'staff': 'ਕਰਮਚਾਰੀ', 'attendance': 'ਹਾਜ਼ਰੀ', 'payroll': 'ਤਨਖਾਹ',
    'operationsOverview': 'ਓਪਰੇਸ਼ਨ ਝਲਕ', 'heroDescription': 'ਮੋਬਾਈਲ ਅਨੁਭਵ ਲਈ ਇੱਕ ਬਿਹਤਰ, ਸਥਾਨਕਕ੍ਰਿਤ ਆਧਾਰ।', 'openDashboard': 'ਡੈਸ਼ਬੋਰਡ ਖੋਲ੍ਹੋ', 'premiumShell': 'ਮੋਡੀਊਲਾਂ ਲਈ ਪ੍ਰੀਮੀਅਮ ਸ਼ੈੱਲ ਤਿਆਰ ਹੈ', 'quickActions': 'ਤੁਰੰਤ ਕਾਰਵਾਈਆਂ', 'reusableStates': 'ਸਥਾਨਕਕ੍ਰਿਤ ਮੁੜ ਵਰਤੋਂਯੋਗ ਸਥਿਤੀਆਂ', 'noPendingActions': 'ਕੋਈ ਕਾਰਵਾਈ ਲੰਬਿਤ ਨਹੀਂ', 'themeReady': 'ਥੀਮ ਅਤੇ ਭਾਸ਼ਾ ਤਰਜੀਹਾਂ ਭਵਿੱਖ ਦੇ ਮੋਡੀਊਲਾਂ ਲਈ ਤਿਆਰ ਹਨ।', 'workers': 'ਕਰਮਚਾਰੀ', 'pending': 'ਲੰਬਿਤ',
    'adminDashboard': 'ਸੁਪਰ ਐਡਮਿਨ ਡੈਸ਼ਬੋਰਡ', 'ownerDashboard': 'ਮਾਲਕ ਡੈਸ਼ਬੋਰਡ', 'managerDashboard': 'ਸਾਈਟ ਮੈਨੇਜਰ ਡੈਸ਼ਬੋਰਡ', 'supervisorDashboard': 'ਸੁਪਰਵਾਈਜ਼ਰ ਡੈਸ਼ਬੋਰਡ', 'workerDashboard': 'ਕਰਮਚਾਰੀ ਡੈਸ਼ਬੋਰਡ',
    'adminWelcome': 'ਸੁਪਰ ਐਡਮਿਨ ਦਾ ਸੁਆਗਤ ਹੈ। ਪੂਰੀ ਸਿਸਟਮ ਪਹੁੰਚ।', 'ownerWelcome': 'ਮਾਲਕ ਦਾ ਸੁਆਗਤ ਹੈ। ਕੰਪਨੀ ਮੈਟ੍ਰਿਕਸ ਦੇਖੋ।', 'managerWelcome': 'ਸਾਈਟ ਮੈਨੇਜਰ ਦਾ ਸੁਆਗਤ ਹੈ। ਆਪਣੀਆਂ ਸਾਈਟਾਂ ਦਾ ਪ੍ਰਬੰਧਨ ਕਰੋ।', 'supervisorWelcome': 'ਸੁਪਰਵਾਈਜ਼ਰ ਦਾ ਸੁਆਗਤ ਹੈ। ਕਰਮਚਾਰੀਆਂ ਅਤੇ ਹਾਜ਼ਰੀ ਦੀ ਨਿਗਰਾਨੀ ਕਰੋ।', 'workerWelcome': 'ਕਰਮਚਾਰੀ ਦਾ ਸੁਆਗਤ ਹੈ। ਆਪਣੀਆਂ ਸ਼ਿਫਟਾਂ ਅਤੇ ਤਨਖਾਹ ਦੇਖੋ।',
    'totalEarnings': 'ਕੁੱਲ ਕਮਾਈ (ਇਸ ਮਹੀਨੇ)', 'viewPayslips': 'ਪੇਸਲਿਪ ਦੇਖੋ',
  },
  'hi_BH': {
    'language': 'भाषा', 'theme': 'थीम', 'dark': 'डार्क', 'light': 'लाइट', 'amoled': 'AMOLED', 'system': 'सिस्टम',
    'fieldOperations': 'फील्ड काम', 'today': 'आज', 'dashboard': 'डैशबोर्ड', 'staff': 'स्टाफ', 'attendance': 'हाजिरी', 'payroll': 'पेरोल',
    'operationsOverview': 'कामकाज सारांश', 'heroDescription': 'मोबाइल खातिर एक बढ़िया आधार।', 'openDashboard': 'डैशबोर्ड खोलीं', 'premiumShell': 'प्रीमियम शेल तइयार बा', 'quickActions': 'जल्दी काम', 'reusableStates': 'फिर से इस्तेमाल होखे वाला', 'noPendingActions': 'कवनो काम पेंडिंग नइखे', 'themeReady': 'थीम अवुरी भाषा तइयार बा।', 'workers': 'मजदूर', 'pending': 'पेंडिंग',
    'adminDashboard': 'सुपर एडमिन डैशबोर्ड', 'ownerDashboard': 'मालिक डैशबोर्ड', 'managerDashboard': 'साइट मैनेजर डैशबोर्ड', 'supervisorDashboard': 'सुपरवाइजर डैशबोर्ड', 'workerDashboard': 'मजदूर डैशबोर्ड',
    'adminWelcome': 'सुपर एडमिन के स्वागत बा। पूरा सिस्टम पहुँच।', 'ownerWelcome': 'मालिक के स्वागत बा। कंपनी के जानकारी देखीं।', 'managerWelcome': 'साइट मैनेजर के स्वागत बा। आपन साइट के देखरेख करीं।', 'supervisorWelcome': 'सुपरवाइजर के स्वागत बा। मजदूर अउर हाजिरी देखीं।', 'workerWelcome': 'मजदूर के स्वागत बा। आपन शिफ्ट अउर पइसा देखीं।',
    'totalEarnings': 'कुल कमाई (ई महीना)', 'viewPayslips': 'पेस्लिप देखीं',
  },
  'hi_EN': {
    'language': 'Language', 'theme': 'Theme', 'dark': 'Dark', 'light': 'Light', 'amoled': 'AMOLED', 'system': 'System',
    'fieldOperations': 'Field Operations', 'today': 'Aaj', 'dashboard': 'Dashboard', 'staff': 'Staff', 'attendance': 'Attendance', 'payroll': 'Payroll',
    'operationsOverview': 'Kaam ka overview', 'heroDescription': 'Ek badiya mobile app foundation.', 'openDashboard': 'Dashboard open karein', 'premiumShell': 'Shell ready hai', 'quickActions': 'Quick actions', 'reusableStates': 'Reusable states', 'noPendingActions': 'Koi pending kaam nahi hai', 'themeReady': 'Theme aur language preferences ready hain.', 'workers': 'Workers', 'pending': 'Pending',
    'adminDashboard': 'Super Admin Dashboard', 'ownerDashboard': 'Owner Dashboard', 'managerDashboard': 'Site Manager Dashboard', 'supervisorDashboard': 'Supervisor Dashboard', 'workerDashboard': 'Worker Dashboard',
    'adminWelcome': 'Welcome, Super Admin. Pura system access.', 'ownerWelcome': 'Welcome, Owner. Company metrics dekhein.', 'managerWelcome': 'Welcome, Site Manager. Apni sites manage karein.', 'supervisorWelcome': 'Welcome, Supervisor. Workers aur attendance dekhein.', 'workerWelcome': 'Welcome, Worker. Apni shifts aur payroll dekhein.',
    'totalEarnings': 'Total Earnings (Is Mahine)', 'viewPayslips': 'Payslips dekhein',
  },
};
