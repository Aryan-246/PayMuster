import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/paymuster_tokens.dart';

class PayMusterShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const PayMusterShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final activeColor = isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;
    final inactiveColor = isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;
    final bgColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final borderColor = isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            backgroundColor: bgColor,
            indicatorColor: activeColor.withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return PMTypography.caption.copyWith(color: activeColor);
              }
              return PMTypography.caption.copyWith(color: inactiveColor);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(color: activeColor, size: 24);
              }
              return IconThemeData(color: inactiveColor, size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => _onTap(context, index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: l10n.text('dashboard'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.groups_outlined),
                selectedIcon: const Icon(Icons.groups),
                label: l10n.text('staff'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.fact_check_outlined),
                selectedIcon: const Icon(Icons.fact_check),
                label: l10n.text('attendance'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: l10n.text('payroll'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
