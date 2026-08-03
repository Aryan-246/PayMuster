import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final role = user.role;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final bgSurface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final borderCol = isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: bgSurface,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(PMSpacing.s6),
        children: [
          _buildProfileHeader(context, user, textColor, bgSurface, borderCol),
          const SizedBox(height: PMSpacing.s8),
          if (role == UserRole.owner || role == UserRole.superAdmin || role == UserRole.admin)
            _buildSection(
              title: 'Administration',
              items: [
                if (role == UserRole.owner || role == UserRole.superAdmin || role == UserRole.admin)
                  _buildListTile(context, Icons.people, 'Staff', '/app/staff', textColor),
                if (role == UserRole.owner || role == UserRole.superAdmin)
                  _buildListTile(context, Icons.admin_panel_settings, 'Permission Center', '/app/permissions', textColor),
                if (role == UserRole.owner || role == UserRole.superAdmin)
                  _buildListTile(context, Icons.person_add, 'Join Requests', '/app/join-requests', textColor),
                if (role == UserRole.owner || role == UserRole.superAdmin)
                  _buildListTile(context, Icons.business, 'Company & Join Code', '/app/company-info', textColor),
              ],
            ),
          _buildSection(
            title: 'Site Operations',
            items: [
              _buildListTile(context, Icons.folder, 'Documents', '/app/documents', textColor),
              _buildListTile(context, Icons.calendar_month, 'Leaves', '/app/leaves', textColor),
              _buildListTile(context, Icons.construction, 'Equipment', '/app/equipment', textColor),
              _buildListTile(context, Icons.notifications, 'Notices', '/app/notices', textColor),
            ],
          ),
          _buildSection(
            title: 'Insights',
            items: [
              _buildListTile(context, Icons.bar_chart, 'Reports', '/app/reports', textColor),
              _buildListTile(context, Icons.analytics, 'Analytics', '/app/analytics', textColor),
            ],
          ),
          if (role == UserRole.superAdmin)
            _buildSection(
              title: 'Super Admin',
              items: [
                _buildListTile(context, Icons.security, 'Super Admin Panel', '/app/super-admin', textColor),
              ],
            ),
          _buildSection(
            title: 'Account',
            items: [
              _buildListTile(context, Icons.person, 'Profile', '/app/more/profile', textColor),
              _buildListTile(context, Icons.settings, 'Settings', '/app/more/settings', textColor),
              ListTile(
                leading: const Icon(Icons.logout, color: PMColors.statusDangerLight),
                title: Text('Logout', style: PMTypography.body.copyWith(color: PMColors.statusDangerLight)),
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User user, Color textColor, Color bgSurface, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s6),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(PMSpacing.s4),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: PMColors.brandPrimaryLight.withValues(alpha: 0.1),
            child: Text(
              user.name?.substring(0, 1).toUpperCase() ?? 'U',
              style: PMTypography.headline.copyWith(color: PMColors.brandPrimaryLight),
            ),
          ),
          const SizedBox(width: PMSpacing.s6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name ?? 'User', style: PMTypography.title.copyWith(color: textColor)),
                Text(user.email, style: PMTypography.caption.copyWith(color: textColor.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: PMSpacing.s4, bottom: PMSpacing.s2, top: PMSpacing.s4),
          child: Text(title, style: PMTypography.title.copyWith(color: PMColors.brandPrimaryLight)),
        ),
        ...items,
        const SizedBox(height: PMSpacing.s6),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String route, Color textColor) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: PMTypography.body.copyWith(color: textColor)),
      trailing: Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.5)),
      onTap: () => context.push(route),
    );
  }
}
