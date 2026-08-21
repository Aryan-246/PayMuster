import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.text('managerDashboard'))),
      body: Center(child: Text(loc.text('managerWelcome'))),
    );
  }
}
