import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/presentation/auth_controller.dart';

class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Super Admin', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Search Users', Icons.person_search, '/app/super-admin/search'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Search Companies', Icons.business, '/app/super-admin/companies'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Promote Owner', Icons.arrow_upward, '/app/super-admin/promote'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Remove Owner', Icons.arrow_downward, '/app/super-admin/demote'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Suspend User', Icons.block, '/app/super-admin/suspend'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Restore User', Icons.restore, '/app/super-admin/restore'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Block User', Icons.gavel, '/app/super-admin/block'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'View Audit Logs', Icons.list_alt, '/app/super-admin/audit'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'View Notifications', Icons.notifications, '/app/super-admin/notifications'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'View Requests', Icons.request_page, '/app/super-admin/requests'),
            const SizedBox(height: PMSpacing.s4),
            _buildAdminCard(context, isDark, textColor, surfaceColor, 'Platform Settings', Icons.settings, '/app/super-admin/settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, bool isDark, Color textColor, Color surfaceColor, String title, IconData icon, String route) {
    return Card(
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: PMRadius.md,
        side: BorderSide(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(PMSpacing.s4),
        leading: Icon(icon, color: PMColors.brandPrimaryLight, size: 28),
        title: Text(title, style: PMTypography.headline.copyWith(color: textColor)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (route == '/app/super-admin/search') {
            context.push('/app/super-admin/search');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title coming soon')),
            );
          }
        },
      ),
    );
  }
}
