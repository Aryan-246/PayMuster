import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/admin_theme.dart';
import 'theme/admin_tokens.dart';
import '../../auth/presentation/auth_controller.dart';

/// The navigation items that map to each StatefulShellBranch index.
/// Branch 0: Dashboard
/// Branch 1: Users (includes Owner Requests)
/// Branch 2: Companies (includes Sites, Attendance, Payroll)
/// Branch 3: Audit Logs
/// Branch 4: More (includes Notifications)
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int branchIndex;
  final String? route; // If non-null, navigate to this route instead of branch

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.branchIndex,
    this.route,
  });
}

const _sidebarItems = <_NavItem>[
  _NavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
    branchIndex: 0,
  ),
  _NavItem(
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    label: 'Users',
    branchIndex: 1,
  ),
  _NavItem(
    icon: Icons.how_to_reg_outlined,
    activeIcon: Icons.how_to_reg,
    label: 'Owner Requests',
    branchIndex: 1,
    route: '/admin/owner-requests',
  ),
  _NavItem(
    icon: Icons.business_outlined,
    activeIcon: Icons.business,
    label: 'Companies',
    branchIndex: 2,
  ),
  _NavItem(
    icon: Icons.location_on_outlined,
    activeIcon: Icons.location_on,
    label: 'Sites',
    branchIndex: 2,
    route: '/admin/sites',
  ),
  _NavItem(
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
    label: 'Attendance',
    branchIndex: 2,
    route: '/admin/attendance',
  ),
  _NavItem(
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet,
    label: 'Payroll',
    branchIndex: 2,
    route: '/admin/payroll',
  ),
  _NavItem(
    icon: Icons.security_outlined,
    activeIcon: Icons.security,
    label: 'Audit Logs',
    branchIndex: 3,
  ),
  _NavItem(
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    label: 'Notifications',
    branchIndex: 4,
    route: '/admin/notifications',
  ),
  _NavItem(
    icon: Icons.verified_outlined,
    activeIcon: Icons.verified,
    label: 'Documents',
    branchIndex: 4,
    route: '/admin/documents',
  ),
  _NavItem(
    icon: Icons.build_outlined,
    activeIcon: Icons.build,
    label: 'Maintenance',
    branchIndex: 4,
    route: '/admin/maintenance',
  ),
  _NavItem(
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    label: 'AI Assistant',
    branchIndex: 4,
    route: '/admin/ai',
  ),
];

const _bottomNavItems = <_NavItem>[
  _NavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
    branchIndex: 0,
  ),
  _NavItem(
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    label: 'Users',
    branchIndex: 1,
  ),
  _NavItem(
    icon: Icons.business_outlined,
    activeIcon: Icons.business,
    label: 'Companies',
    branchIndex: 2,
  ),
  _NavItem(
    icon: Icons.security_outlined,
    activeIcon: Icons.security,
    label: 'Audit',
    branchIndex: 3,
  ),
  _NavItem(
    icon: Icons.more_horiz_outlined,
    activeIcon: Icons.more_horiz,
    label: 'More',
    branchIndex: 4,
  ),
];

/// Section titles mapped by branch index.
const _branchTitles = <int, String>{
  0: 'Dashboard',
  1: 'Users',
  2: 'Companies',
  3: 'Audit Logs',
  4: 'More',
};

class AdminScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminScaffold({super.key, required this.navigationShell});

  void _onBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _onNavItem(BuildContext context, _NavItem item) {
    if (item.route != null) {
      context.go(item.route!);
    } else {
      _onBranch(item.branchIndex);
    }
  }

  String _currentLocation(BuildContext context) =>
      GoRouterState.of(context).matchedLocation;

  String _currentTitle(BuildContext context) {
    final location = _currentLocation(context);
    if (location.startsWith('/admin/users/')) return 'User Details';
    if (location.startsWith('/admin/users')) return 'Users';
    if (location.startsWith('/admin/owner-requests')) {
      return 'Owner Requests';
    }
    if (location.startsWith('/admin/companies/')) return 'Company Details';
    if (location.startsWith('/admin/companies')) return 'Companies';
    if (location.startsWith('/admin/sites/')) return 'Site Details';
    if (location.startsWith('/admin/sites')) return 'Sites';
    if (location.startsWith('/admin/attendance')) return 'Attendance';
    if (location.startsWith('/admin/payroll')) return 'Payroll';
    if (location.startsWith('/admin/audit-logs')) return 'Audit Logs';
    if (location.startsWith('/admin/notifications')) return 'Notifications';
    if (location.startsWith('/admin/documents')) return 'Documents';
    if (location.startsWith('/admin/maintenance')) return 'Maintenance';
    if (location.startsWith('/admin/ai')) return 'AI Assistant';
    if (location.startsWith('/admin/settings')) return 'Settings';
    if (location.startsWith('/admin/profile')) return 'Profile';
    if (location.startsWith('/admin/more')) return 'More';
    return _branchTitles[navigationShell.currentIndex] ?? 'Admin';
  }

  int _activeSidebarIndex(BuildContext context) {
    final location = _currentLocation(context);
    // Find the best matching sidebar item
    for (int i = _sidebarItems.length - 1; i >= 0; i--) {
      final item = _sidebarItems[i];
      if (item.route != null && location.startsWith(item.route!)) {
        return i;
      }
    }
    // Fallback: match by branch index
    for (int i = 0; i < _sidebarItems.length; i++) {
      if (_sidebarItems[i].branchIndex == navigationShell.currentIndex &&
          _sidebarItems[i].route == null) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: AdminTheme.theme,
      child: Builder(
        builder: (context) {
          final isWide = MediaQuery.of(context).size.width >= 768;
          return isWide
              ? _buildDesktop(context, ref)
              : _buildMobile(context, ref);
        },
      ),
    );
  }

  // ─── DESKTOP ──────────────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context, WidgetRef ref) {
    final activeIndex = _activeSidebarIndex(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──
          _AdminSidebar(
            activeIndex: activeIndex,
            userName: user?.name ?? user?.email ?? 'Super Admin',
            userEmail: user?.email ?? '',
            onItemTap: (item) => _onNavItem(context, item),
            onLogout: () => ref.read(authControllerProvider.notifier).signOut(),
          ),

          // ── Divider ──
          const VerticalDivider(
            thickness: 1,
            width: 1,
            color: AdminColors.glassBorder,
          ),

          // ── Content area ──
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  title: _currentTitle(context),
                  onNotifications: () => context.go('/admin/notifications'),
                ),
                const Divider(height: 1, color: AdminColors.glassBorder),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── MOBILE ───────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTitle(context),
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            color: AdminColors.onSurfaceVariant,
            onPressed: () => context.go('/admin/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AdminColors.glassBorder, width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            backgroundColor: AdminColors.surfaceContainerLow,
            indicatorColor: AdminColors.primaryContainer.withValues(
              alpha: 0.12,
            ),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return AdminTypography.labelSm.copyWith(
                color: selected
                    ? AdminColors.primaryContainer
                    : AdminColors.onSurfaceVariant,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected
                    ? AdminColors.primaryContainer
                    : AdminColors.onSurfaceVariant,
                size: 22,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onBranch,
            destinations: _bottomNavItems
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  SIDEBAR WIDGET
// ═════════════════════════════════════════════════════════════════════

class _AdminSidebar extends StatelessWidget {
  final int activeIndex;
  final String userName;
  final String userEmail;
  final ValueChanged<_NavItem> onItemTap;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.activeIndex,
    required this.userName,
    required this.userEmail,
    required this.onItemTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AdminColors.surfaceContainerLowest,
      child: Column(
        children: [
          // ── Brand header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.md,
              AdminSpacing.lg,
              AdminSpacing.md,
              AdminSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AdminColors.primaryContainer,
                    borderRadius: AdminRadius.md,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PM',
                    style: AdminTypography.labelSm.copyWith(
                      color: AdminColors.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PayMuster OS',
                        style: AdminTypography.titleMd.copyWith(
                          color: AdminColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Super Admin',
                        style: AdminTypography.labelSm.copyWith(
                          color: AdminColors.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AdminSpacing.sm),

          // ── Navigation items ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm),
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) {
                final item = _sidebarItems[index];
                final isActive = index == activeIndex;
                return _SidebarNavItem(
                  item: item,
                  isActive: isActive,
                  onTap: () => onItemTap(item),
                );
              },
            ),
          ),

          // ── Bottom section ──
          const Divider(height: 1, color: AdminColors.glassBorder),
          Padding(
            padding: const EdgeInsets.all(AdminSpacing.sm),
            child: Column(
              children: [
                // User info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.sm,
                    vertical: AdminSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.surfaceContainer,
                    borderRadius: AdminRadius.lg,
                    border: Border.all(color: AdminColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AdminColors.secondaryContainer,
                        child: Text(
                          _initials(userName),
                          style: AdminTypography.labelSm.copyWith(
                            color: AdminColors.onSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AdminSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: AdminTypography.bodyMd.copyWith(
                                color: AdminColors.onSurface,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userEmail,
                              style: AdminTypography.labelSm.copyWith(
                                color: AdminColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AdminSpacing.xs),
                // Logout
                _SidebarActionItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  color: AdminColors.error,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'SA';
  }
}

// ═════════════════════════════════════════════════════════════════════
//  SIDEBAR NAV ITEM
// ═════════════════════════════════════════════════════════════════════

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final hovered = _isHovered && !active;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        selected: active,
        label: widget.item.label,
        excludeSemantics: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AdminRadius.md,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: 40,
              decoration: BoxDecoration(
                color: active
                    ? AdminColors.primaryContainer.withValues(alpha: 0.10)
                    : hovered
                    ? AdminColors.onSurface.withValues(alpha: 0.04)
                    : Colors.transparent,
                borderRadius: AdminRadius.md,
              ),
              child: Row(
                children: [
                  // Active accent bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: active ? 24 : 0,
                    decoration: BoxDecoration(
                      color: active
                          ? AdminColors.primaryContainer
                          : Colors.transparent,
                      borderRadius: AdminRadius.full,
                    ),
                  ),
                  SizedBox(width: active ? 9 : 12),
                  Icon(
                    active ? widget.item.activeIcon : widget.item.icon,
                    size: 20,
                    color: active
                        ? AdminColors.primaryContainer
                        : AdminColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.item.label,
                    style: AdminTypography.bodyMd.copyWith(
                      color: active
                          ? AdminColors.onSurface
                          : AdminColors.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  SIDEBAR ACTION ITEM (Logout, Help, etc.)
// ═════════════════════════════════════════════════════════════════════

class _SidebarActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SidebarActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SidebarActionItem> createState() => _SidebarActionItemState();
}

class _SidebarActionItemState extends State<_SidebarActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AdminRadius.md,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: AdminRadius.md,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.color.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: AdminTypography.bodyMd.copyWith(
                    color: widget.color.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  TOP BAR
// ═════════════════════════════════════════════════════════════════════

class _AdminTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onNotifications;

  const _AdminTopBar({required this.title, required this.onNotifications});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      color: AdminColors.surface,
      child: Row(
        children: [
          Text(
            title,
            style: AdminTypography.titleMd.copyWith(
              color: AdminColors.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 20),
            color: AdminColors.onSurfaceVariant,
            onPressed: onNotifications,
            tooltip: 'Notifications',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
