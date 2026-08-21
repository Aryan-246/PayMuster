import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.text('ownerDashboard'))),
      body: Center(child: Text(loc.text('ownerWelcome'))),
    );
  }
}
