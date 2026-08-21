import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/presentation/auth_controller.dart';

class CareerScreen extends ConsumerWidget {
  const CareerScreen({super.key});

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

    final careerPaths = <_CareerPath>[
      _CareerPath(
        title: 'Supervisor',
        description: 'Lead teams and manage site operations.',
        icon: Icons.supervisor_account,
        nextRole: 'SUPERVISOR',
      ),
      _CareerPath(
        title: 'Accountant',
        description: 'Manage payroll and financial records.',
        icon: Icons.account_balance,
        nextRole: 'ACCOUNTANT',
      ),
      _CareerPath(
        title: 'Admin',
        description: 'Oversee company operations and staff.',
        icon: Icons.admin_panel_settings,
        nextRole: 'ADMIN',
      ),
      _CareerPath(
        title: 'Owner',
        description: 'Own and operate your own company.',
        icon: Icons.business,
        nextRole: 'OWNER',
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Career Paths', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(PMSpacing.s4),
        itemCount: careerPaths.length,
        itemBuilder: (context, index) {
          final path = careerPaths[index];
          return Card(
            margin: const EdgeInsets.only(bottom: PMSpacing.s4),
            color: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: PMRadius.md,
              side: BorderSide(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(PMSpacing.s4),
              leading: Icon(path.icon, color: PMColors.brandPrimaryLight, size: 32),
              title: Text(path.title, style: PMTypography.headline.copyWith(color: textColor)),
              subtitle: Text(path.description, style: PMTypography.body.copyWith(color: textColor.withValues(alpha: 0.7))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (path.nextRole == 'OWNER') {
                  context.push('/app/owner-request');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Promotion to ${path.title} coming soon'),
                      backgroundColor: PMColors.statusWarningDark,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _CareerPath {
  final String title;
  final String description;
  final IconData icon;
  final String nextRole;

  const _CareerPath({
    required this.title,
    required this.description,
    required this.icon,
    required this.nextRole,
  });
}
