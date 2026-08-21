import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.text('adminDashboard'))),
      body: Center(child: Text(loc.text('adminWelcome'))),
    );
  }
}
