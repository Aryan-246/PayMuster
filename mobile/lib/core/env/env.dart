import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // Ignore if .env is missing, just use default empty strings
    }
  }

  static String get apiBaseUrl {
    final value = dotenv.env['API_BASE_URL'] ?? dotenv.env['BACKEND_URL'] ?? '';
    if (value.isEmpty) {
      return 'http://localhost:4000';
    }
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static String get googleWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  static String get googleAndroidClientId => dotenv.env['GOOGLE_ANDROID_CLIENT_ID'] ?? '';
  static String get googleIosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
