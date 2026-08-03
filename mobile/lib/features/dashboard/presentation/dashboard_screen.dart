import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

// Unified Dashboard Screen leveraging a Registry pattern
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PayMuster Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${user.name ?? user.email}', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Role: ${user.role.name.toUpperCase()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).primaryColor)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: _buildModulesForUser(context, user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModulesForUser(BuildContext context, User user) {
    final modules = <Widget>[];
    final role = user.role;

    if (role == UserRole.superAdmin) {
      modules.add(_buildModuleCard(context, 'Search Users', Icons.person_search));
      modules.add(_buildModuleCard(context, 'Search Companies', Icons.business));
      modules.add(_buildModuleCard(context, 'Promote Owner', Icons.arrow_upward));
      modules.add(_buildModuleCard(context, 'Remove Owner', Icons.arrow_downward));
      modules.add(_buildModuleCard(context, 'Suspend User', Icons.block));
      modules.add(_buildModuleCard(context, 'Restore User', Icons.restore));
      modules.add(_buildModuleCard(context, 'Block User', Icons.gavel));
      modules.add(_buildModuleCard(context, 'View Audit Logs', Icons.list_alt));
      modules.add(_buildModuleCard(context, 'View Notifications', Icons.notifications));
      modules.add(_buildModuleCard(context, 'View Requests', Icons.request_page));
      modules.add(_buildModuleCard(context, 'Platform Settings', Icons.settings));
    } else if (role == UserRole.owner) {
      modules.add(_buildModuleCard(context, 'Join Requests', Icons.person_add));
      modules.add(_buildModuleCard(context, 'Promotion Requests', Icons.upgrade));
      modules.add(_buildModuleCard(context, 'Permission Center', Icons.security));
      modules.add(_buildModuleCard(context, 'Staff Management', Icons.people));
      modules.add(_buildModuleCard(context, 'Site Management', Icons.location_city));
      modules.add(_buildModuleCard(context, 'Company Code', Icons.qr_code));
      modules.add(_buildModuleCard(context, 'Company Details', Icons.info));
      modules.add(_buildModuleCard(context, 'Company Settings', Icons.settings));
    } else if (role == UserRole.admin) {
      modules.add(_buildModuleCard(context, 'Manage Workers', Icons.people));
      modules.add(_buildModuleCard(context, 'Manage Sites', Icons.location_city));
      modules.add(_buildModuleCard(context, 'Manage Attendance', Icons.access_time));
      modules.add(_buildModuleCard(context, 'Manage Payroll', Icons.payments));
    } else if (role == UserRole.staff && user.organizationId == null) {
      modules.add(_buildModuleCard(context, 'Join Company', Icons.business_center, route: '/app/join-company'));
    } else {
      // General worker / supervisor / accountant view (simplified)
      if (role == UserRole.supervisor) {
        modules.add(_buildModuleCard(context, 'Attendance', Icons.access_time));
        modules.add(_buildModuleCard(context, 'Site Documents', Icons.folder));
      } else if (role == UserRole.accountant) {
        modules.add(_buildModuleCard(context, 'Payroll', Icons.payments));
        modules.add(_buildModuleCard(context, 'Reports', Icons.bar_chart));
      }
    }
    
    // Everyone sees their own profile
    modules.add(_buildModuleCard(context, 'My Profile', Icons.person));

    return modules;
  }

  Widget _buildModuleCard(BuildContext context, String title, IconData icon, {String? route}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (route != null) {
            // context.push(route);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
