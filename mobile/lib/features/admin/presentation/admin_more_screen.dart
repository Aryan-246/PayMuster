import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/admin_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textColor = AdminColors.onSurface;
    const surfaceColor = AdminColors.surfaceContainer;
    final authState = ref.watch(authControllerProvider);

    final user = authState.user;

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Control Menu',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AdminSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: AdminRadius.md,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AdminColors.primary,
                  child: Text(
                    (user?.name?.trim().isNotEmpty ?? false)
                        ? user!.name!.trim()[0].toUpperCase()
                        : 'A',
                    style: AdminTypography.titleMd.copyWith(
                      color: AdminColors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Super Admin',
                        style: AdminTypography.titleSm.copyWith(
                          color: textColor,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: AdminTypography.bodySm.copyWith(
                          color: AdminColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.xs),
                      const AdminBadge(
                        label: 'Super Admin',
                        color: AdminColors.primary,
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          const AdminSectionHeader(title: 'Administration'),
          const SizedBox(height: AdminSpacing.sm),
          _buildMenuTile(
            context,
            icon: Icons.people_outline,
            title: 'User Accounts',
            subtitle: 'Search, role changes, blocking & password resets',
            route: '/admin/users',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Owner Promotion Requests',
            subtitle: 'Approve new companies & assign owner roles',
            route: '/admin/owner-requests',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.business_outlined,
            title: 'Companies Directory',
            subtitle: 'View registered organizations & join codes',
            route: '/admin/companies',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          const SizedBox(height: AdminSpacing.lg),
          const AdminSectionHeader(title: 'Operations'),
          const SizedBox(height: AdminSpacing.sm),
          _buildMenuTile(
            context,
            icon: Icons.location_city_outlined,
            title: 'Sites & Locations',
            subtitle: 'Global view of all construction/work sites',
            route: '/admin/sites',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Attendance Monitor',
            subtitle: 'System-wide attendance records & geo-logs',
            route: '/admin/attendance',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payroll Center',
            subtitle: 'View pay cycles, pay runs & disbursement stats',
            route: '/admin/payroll',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          const SizedBox(height: AdminSpacing.lg),
          const AdminSectionHeader(title: 'System & Audit'),
          const SizedBox(height: AdminSpacing.sm),
          _buildMenuTile(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'Audit Trail',
            subtitle: 'Immutable security & admin action logs',
            route: '/admin/audit-logs',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.notifications_none_outlined,
            title: 'Notifications Dispatch',
            subtitle: 'System notifications and broadcasts',
            route: '/admin/notifications',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.verified_outlined,
            title: 'Document Review',
            subtitle: 'Verify or reject pending staff documents',
            route: '/admin/documents',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.build_outlined,
            title: 'Maintenance Mode',
            subtitle: 'View and change the live platform access state',
            route: '/admin/maintenance',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.auto_awesome_outlined,
            title: 'AI Assistant',
            subtitle: 'Platform operations analysis',
            route: '/admin/ai',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          const SizedBox(height: AdminSpacing.lg),
          const AdminSectionHeader(title: 'Account & System'),
          const SizedBox(height: AdminSpacing.sm),
          _buildMenuTile(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Theme, localization & system preferences',
            route: '/admin/settings',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          _buildMenuTile(
            context,
            icon: Icons.person_outline,
            title: 'My Profile',
            subtitle: 'View admin profile details',
            route: '/admin/profile',
            surfaceColor: surfaceColor,
            textColor: textColor,
          ),
          const SizedBox(height: AdminSpacing.md),
          ListTile(
            shape: const RoundedRectangleBorder(borderRadius: AdminRadius.md),
            tileColor: AdminColors.danger.withValues(alpha: 0.1),
            leading: const Icon(Icons.logout, color: AdminColors.danger),
            title: Text(
              'Sign Out',
              style: AdminTypography.titleSm.copyWith(
                color: AdminColors.danger,
              ),
            ),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: AdminSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color surfaceColor,
    required Color textColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      color: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: AdminRadius.md,
        side: BorderSide(color: AdminColors.glassBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: AdminColors.primary),
        title: Text(
          title,
          style: AdminTypography.titleSm.copyWith(color: textColor),
        ),
        subtitle: Text(
          subtitle,
          style: AdminTypography.bodySm.copyWith(
            color: AdminColors.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.go(route),
      ),
    );
  }
}
