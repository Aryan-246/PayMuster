import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/permissions/role_permission_manager.dart';
import '../features/auth/domain/user.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme/paymuster_tokens.dart';
import 'announcement_coordinator.dart';

/// Shell rail / bottom-nav destinations, each tied to its shell branch index.
/// Visibility is a cosmetic mirror of the backend permission map (§B/§X) —
/// the backend re-enforces every gate on each endpoint.
class _ShellDestination {
  const _ShellDestination({
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.allowedPermissions,
  });

  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
  final List<AppPermission> allowedPermissions;

  bool isVisibleFor(UserRole role) {
    return role == UserRole.superAdmin
        ? true
        : allowedPermissions.any(
            (permission) => RolePermissionManager.roleHasPermission(
              role,
              permission,
            ),
          );
  }
}

List<_ShellDestination> _destinations(AppLocalizations l10n) {
  return [
    _ShellDestination(
      branchIndex: 0,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: (l10n) => l10n.text('dashboard'),
      allowedPermissions: const [AppPermission.viewWorkerDashboard],
    ),
    _ShellDestination(
      branchIndex: 1,
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      label: (l10n) => 'Sites',
      allowedPermissions: const [AppPermission.viewSites],
    ),
    _ShellDestination(
      branchIndex: 2,
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      label: (l10n) => l10n.text('attendance'),
      // Supervisors/managers see org attendance; staff see their own log.
      allowedPermissions: const [
        AppPermission.viewAttendance,
        AppPermission.logOwnAttendance,
      ],
    ),
    _ShellDestination(
      branchIndex: 3,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: (l10n) => l10n.text('payroll'),
      // Accountants run payroll; staff see their own payslips.
      allowedPermissions: const [
        AppPermission.viewPayroll,
        AppPermission.viewOwnPayroll,
      ],
    ),
    _ShellDestination(
      branchIndex: 4,
      icon: Icons.more_horiz_outlined,
      selectedIcon: Icons.more_horiz,
      label: (l10n) => 'More',
      allowedPermissions: const [AppPermission.viewWorkerDashboard],
    ),
  ];
}

class PayMusterShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const PayMusterShell({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int branchIndex) {
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 768; // Tablet/Desktop threshold

    final authUser = ref.watch(authControllerProvider).user;
    final role = authUser?.role;
    final all = _destinations(l10n);
    // SUPER_ADMIN lands in the /admin back-office, not this shell, but keep
    // every destination visible for them defensively.
    final visible = role == null || role == UserRole.superAdmin
        ? all
        : all.where((d) => d.isVisibleFor(role)).toList();

    // Map a visible-list position to its shell branch index.
    int selectedVisibleIndex() {
      final index = visible.indexWhere(
        (d) => d.branchIndex == navigationShell.currentIndex,
      );
      return index < 0 ? 0 : index;
    }

    void onVisibleSelected(int index) {
      if (index >= 0 && index < visible.length) {
        _onTap(context, visible[index].branchIndex);
      }
    }

    final activeColor = isDark
        ? PMColors.brandPrimaryDark
        : PMColors.brandPrimaryLight;
    final inactiveColor = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final bgColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final borderColor = isDark
        ? PMColors.borderDefaultDark
        : PMColors.borderDefaultLight;

    if (isWide) {
      return AnnouncementCoordinator(
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                backgroundColor: bgColor,
                selectedIndex: selectedVisibleIndex(),
                onDestinationSelected: onVisibleSelected,
                labelType: NavigationRailLabelType.all,
                selectedLabelTextStyle: PMTypography.caption.copyWith(
                  color: activeColor,
                ),
                unselectedLabelTextStyle: PMTypography.caption.copyWith(
                  color: inactiveColor,
                ),
                selectedIconTheme: IconThemeData(color: activeColor, size: 24),
                unselectedIconTheme: IconThemeData(
                  color: inactiveColor,
                  size: 24,
                ),
                destinations: [
                  for (final d in visible)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label(l10n)),
                    ),
                ],
              ),
              VerticalDivider(thickness: 1, width: 1, color: borderColor),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return AnnouncementCoordinator(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor, width: 1)),
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
              selectedIndex: selectedVisibleIndex(),
              onDestinationSelected: onVisibleSelected,
              destinations: [
                for (final d in visible)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label(l10n),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
