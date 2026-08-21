import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

import '../../admin/presentation/admin_dashboard_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

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

    if (user.role == UserRole.superAdmin) {
      return const AdminDashboardScreen();
    }

    if (user.organizationId == null) {
      return _buildNoCompanyDashboard(context, isDark, user);
    }


    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Dashboard', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: textColor),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PMSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome, ${user.name ?? user.email}', style: PMTypography.headline.copyWith(color: textColor)),
            const SizedBox(height: PMSpacing.s2),
            Text('Role: ${user.role.name.toUpperCase()}', style: PMTypography.body.copyWith(color: PMColors.brandPrimaryLight)),
            const SizedBox(height: PMSpacing.s6),
            _buildModuleGrid(context, user, isDark, textColor, surfaceColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCompanyDashboard(BuildContext context, bool isDark, User user) {
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Dashboard', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PMSpacing.s6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.business, size: 80, color: PMColors.brandPrimaryLight),
              const SizedBox(height: PMSpacing.s6),
              Text(
                'Welcome, ${user.name ?? 'User'}!',
                style: PMTypography.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                'You are not associated with any company yet.',
                style: PMTypography.body.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s8),
              PMButton.primary(
                label: 'Join a Company',
                onPressed: () => context.push('/app/join-company'),
                icon: Icons.login,
              ),
              if (user.role == UserRole.owner) ...[
                const SizedBox(height: PMSpacing.s4),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: PMSpacing.s4),
                PMButton.secondary(
                  label: 'Register New Company',
                  onPressed: () => context.push('/app/owner-request'),
                  icon: Icons.add_business,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context, User user, bool isDark, Color textColor, Color surfaceColor) {
    final modules = <Widget>[];
    final role = user.role;

    if (role == UserRole.superAdmin) {
      modules.add(_buildModuleCard(context, 'Super Admin Panel', Icons.admin_panel_settings, () => context.push('/app/super-admin')));
      modules.add(_buildModuleCard(context, 'Search Users', Icons.person_search, () => context.push('/app/super-admin/search')));
    } else if (role == UserRole.owner) {
      modules.add(_buildModuleCard(context, 'Owner Dashboard', Icons.dashboard, () => context.push('/app/owner-dashboard')));
      modules.add(_buildModuleCard(context, 'Join Requests', Icons.person_add, () => context.push('/app/join-requests')));
      modules.add(_buildModuleCard(context, 'Career Paths', Icons.work, () => context.push('/app/career')));
      modules.add(_buildModuleCard(context, 'Promotion Status', Icons.arrow_upward, () => context.push('/app/promotion-status')));
      modules.add(_buildModuleCard(context, 'Documents', Icons.folder, () => context.push('/app/documents')));
      modules.add(_buildModuleCard(context, 'Verification', Icons.verified, () => context.push('/app/verification')));
      modules.add(_buildModuleCard(context, 'Company Settings', Icons.settings, () => context.push('/app/company-info')));
    } else if (role == UserRole.admin) {
      modules.add(_buildModuleCard(context, 'Manage Workers', Icons.people, () {}));
      modules.add(_buildModuleCard(context, 'Manage Sites', Icons.location_city, () {}));
      modules.add(_buildModuleCard(context, 'Attendance', Icons.access_time, () => context.go('/app/attendance')));
      modules.add(_buildModuleCard(context, 'Payroll', Icons.payments, () => context.go('/app/payroll')));
    } else {
      if (role == UserRole.supervisor) {
        modules.add(_buildModuleCard(context, 'Attendance', Icons.access_time, () => context.go('/app/attendance')));
        modules.add(_buildModuleCard(context, 'Site Documents', Icons.folder, () => context.push('/app/documents')));
      } else if (role == UserRole.accountant) {
        modules.add(_buildModuleCard(context, 'Payroll', Icons.payments, () => context.go('/app/payroll')));
        modules.add(_buildModuleCard(context, 'Reports', Icons.bar_chart, () {}));
      }
    }

    modules.add(_buildModuleCard(context, 'My Profile', Icons.person, () => context.push('/app/more/profile')));

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: PMSpacing.s4,
      mainAxisSpacing: PMSpacing.s4,
      childAspectRatio: 1.4,
      children: modules,
    );
  }

  Widget _buildModuleCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;

    return Card(
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: PMRadius.md,
        side: BorderSide(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: PMRadius.md,
        child: Padding(
          padding: const EdgeInsets.all(PMSpacing.s4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: PMColors.brandPrimaryLight),
              const SizedBox(height: PMSpacing.s2),
              Text(title, style: PMTypography.label.copyWith(color: textColor), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
