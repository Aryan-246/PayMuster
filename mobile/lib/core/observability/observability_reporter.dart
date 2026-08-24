import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class ObservabilityReporter {
  ObservabilityReporter({FirebaseCrashlytics? crashlytics})
      : _crashlyticsOverride = crashlytics;

  final FirebaseCrashlytics? _crashlyticsOverride;

  FirebaseCrashlytics? get _crashlytics {
    try {
      return _crashlyticsOverride ?? FirebaseCrashlytics.instance;
    } catch (_) {
      return null;
    }
  }

  static final RegExp _sensitiveFieldPattern = RegExp(
    r'password|otp|token|secret|authorization|cookie|credential|private.?key|api.?key|dsn',
    caseSensitive: false,
  );

  String _redactField(String key, Object? value) {
    if (_sensitiveFieldPattern.hasMatch(key)) return '[REDACTED]';
    final text = value?.toString() ?? '';
    return text.length > 500 ? '${text.substring(0, 500)}...' : text;
  }

  Future<void> reportError(
    Object error,
    StackTrace stack, {
    String? requestId,
    String? provider,
    String? operation,
    bool fatal = false,
  }) async {
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await _setContext(
        crashlytics,
        requestId: requestId,
        provider: provider,
        operation: operation,
      );
      await crashlytics.recordError(error, stack, fatal: fatal);
    } catch (_) {
      // Telemetry must never change application behavior.
    }
  }

  Future<void> reportFlutterError(FlutterErrorDetails details) async {
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await crashlytics.recordFlutterError(details);
    } catch (_) {
      // Telemetry must never change application behavior.
    }
  }

  Future<void> _setContext(
    FirebaseCrashlytics crashlytics, {
    String? requestId,
    String? provider,
    String? operation,
  }) async {
    final values = <String, String?>{
      'requestId': requestId,
      'provider': provider,
      'operation': operation,
    };
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        await crashlytics.setCustomKey(entry.key, _redactField(entry.key, value));
      }
    }
  }
}
