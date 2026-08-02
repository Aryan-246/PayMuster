import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class SupervisorDashboardScreen extends StatelessWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.text('supervisorDashboard'))),
      body: Center(child: Text(loc.text('supervisorWelcome'))),
    );
  }
}
