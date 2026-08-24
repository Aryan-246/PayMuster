import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/env/env.dart';
import 'core/observability/observability_reporter.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final observability = ObservabilityReporter();
  FlutterError.onError = (details) {
    observability.reportFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    observability.reportError(error, stack, fatal: true);
    return true;
  };

  runApp(
    const ProviderScope(
      child: PayMusterApp(),
    ),
  );
}