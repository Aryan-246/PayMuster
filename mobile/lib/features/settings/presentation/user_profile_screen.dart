import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/user.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.user;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('User Profile', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: PMColors.brandPrimaryLight,
                child: Text(
                  'U',
                  style: PMTypography.displayLarge.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: PMSpacing.s6),
            Text(
              'User ID',
              style: PMTypography.caption.copyWith(color: textColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: PMSpacing.s1),
            Text(
              userId,
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'Name',
              style: PMTypography.caption.copyWith(color: textColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: PMSpacing.s1),
            Text(
              currentUser?.name ?? 'Unknown',
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'Email',
              style: PMTypography.caption.copyWith(color: textColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: PMSpacing.s1),
            Text(
              currentUser?.email ?? 'Unknown',
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'Role',
              style: PMTypography.caption.copyWith(color: textColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: PMSpacing.s1),
            Text(
              currentUser?.role.name.toUpperCase() ?? 'UNKNOWN',
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s8),
            if (currentUser?.role == UserRole.superAdmin || currentUser?.role == UserRole.owner || currentUser?.role == UserRole.admin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User actions coming soon')),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Manage User'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: PMColors.brandPrimaryLight,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
