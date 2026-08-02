import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/paymuster_tokens.dart';
import '../../components/foundation/pm_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PMSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: PMSpacing.s4),
              _buildHeroActionCard(isDark, context),
              const SizedBox(height: PMSpacing.s4),
              _buildActionPriorityCard(
                title: '3 Crane Operators Missing',
                subtitle: 'Site B has 2 available operators.',
                actionLabel: 'Reallocate Now',
                imagePath: 'assets/images/placeholders/site_placeholder.png',
                isDark: isDark,
              ),
              const SizedBox(height: PMSpacing.s4),
              _buildActionPriorityCard(
                title: '14 Pending Leaves',
                subtitle: 'Requires immediate approval.',
                actionLabel: 'Review Leaves',
                imagePath: 'assets/images/placeholders/equipment_placeholder.png',
                isDark: isDark,
              ),
              const SizedBox(height: PMSpacing.s4),
              _buildQuickActions(isDark, context),
              const SizedBox(height: PMSpacing.s6),
              _buildSimpleTimeline(isDark),
              const SizedBox(height: PMSpacing.s6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mohali Tower A', style: PMTypography.title),
            Text(
              'Good Morning, Aryan',
              style: PMTypography.body.copyWith(
                color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(PMSpacing.s2),
              decoration: BoxDecoration(
                color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
              ),
              child: Icon(
                Icons.notifications_none,
                color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
                size: 24,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: PMColors.statusDangerDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroActionCard(bool isDark, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: PMRadius.lg,
        image: const DecorationImage(
          image: AssetImage('assets/images/placeholders/worker_placeholder.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: isDark ? PMElevation.floatingDark : PMElevation.floatingLight,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: PMRadius.lg,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(PMSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PMColors.statusSuccessDark.withValues(alpha: 0.2),
                    borderRadius: PMRadius.sm,
                    border: Border.all(color: PMColors.statusSuccessDark.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: PMColors.statusSuccessDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('LIVE', style: PMTypography.caption.copyWith(color: PMColors.statusSuccessDark)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.wb_sunny, color: PMColors.statusWarningDark, size: 16),
                    const SizedBox(width: 4),
                    Text('28°C', style: PMTypography.label.copyWith(color: Colors.white)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 60),
            Text(
              '284',
              style: PMTypography.displayLarge.copyWith(color: Colors.white, fontSize: 56),
            ),
            Text(
              'Workers Present',
              style: PMTypography.title.copyWith(color: Colors.white),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              '12 Absent • 3 Pending Approvals',
              style: PMTypography.body.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: PMSpacing.s5),
            SizedBox(
              width: double.infinity,
              child: PMButton.primary(
                label: 'START ROLL CALL',
                onPressed: () => context.go('/app/attendance'),
                icon: Icons.checklist_rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPriorityCard({
    required String title,
    required String subtitle,
    required String actionLabel,
    required String imagePath,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
        borderRadius: PMRadius.md,
        border: Border.all(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
        boxShadow: isDark ? null : PMElevation.raisedLight,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PMSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PMTypography.headline,
                ),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  subtitle,
                  style: PMTypography.body.copyWith(
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: PMSpacing.s4),
                SizedBox(
                  width: double.infinity,
                  child: PMButton.secondary(
                    label: actionLabel,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildLargeActionItem(
            icon: Icons.person_add,
            label: 'Add Worker',
            isDark: isDark,
            onTap: () {},
          ),
        ),
        const SizedBox(width: PMSpacing.s3),
        Expanded(
          child: _buildLargeActionItem(
            icon: Icons.payments,
            label: 'Payroll',
            isDark: isDark,
            onTap: () => context.go('/app/payroll'),
          ),
        ),
        const SizedBox(width: PMSpacing.s3),
        Expanded(
          child: _buildLargeActionItem(
            icon: Icons.how_to_reg,
            label: 'Staff List',
            isDark: isDark,
            onTap: () => context.go('/app/sites'),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeActionItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: PMSpacing.s4),
        decoration: BoxDecoration(
          color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
          borderRadius: PMRadius.md,
          border: Border.all(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              label,
              style: PMTypography.caption.copyWith(
                color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTimeline(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today\'s Log', style: PMTypography.title),
        const SizedBox(height: PMSpacing.s4),
        _buildTimelineRow('08:00 AM', 'Site Opened & Muster Started', isDark),
        const SizedBox(height: PMSpacing.s3),
        _buildTimelineRow('10:30 AM', 'Material Delivery: Cement (200 Bags)', isDark),
        const SizedBox(height: PMSpacing.s3),
        _buildTimelineRow('01:00 PM', 'Lunch Break & Shift Change', isDark),
      ],
    );
  }

  Widget _buildTimelineRow(String time, String event, bool isDark) {
    return Row(
      children: [
        Text(
          time,
          style: PMTypography.label.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: PMSpacing.s4),
        Expanded(
          child: Text(
            event,
            style: PMTypography.body,
          ),
        ),
      ],
    );
  }
}
