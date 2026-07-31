import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/layout/pm_card.dart';
import '../domain/worker.dart';
import '../data/worker_repository.dart';

class WorkerProfileScreen extends ConsumerWidget {
  final String workerId;

  const WorkerProfileScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now we'll just watch the list and find the worker, or use a specific provider.
    final workersAsync = ref.watch(workersListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Worker Profile',
          style: PMTypography.title.copyWith(
            color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: workersAsync.when(
        data: (workers) {
          final worker = workers.firstWhere(
            (w) => w.id == workerId,
            orElse: () => const Worker(
              id: '',
              firstName: 'Unknown',
              lastName: 'Worker',
              role: '',
              employeeId: '',
              siteId: '',
              siteName: '',
              dailyWage: 0,
              status: '',
            ),
          );
          
          if (worker.id.isEmpty) {
            return const Center(child: Text('Worker not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileHeader(worker, isDark),
                const SizedBox(height: PMSpacing.s4),
                _buildStatsRow(isDark),
                const SizedBox(height: PMSpacing.s4),
                _buildFinancialsRow(isDark),
                const SizedBox(height: PMSpacing.s6),
                _buildStreakCard(isDark),
                const SizedBox(height: PMSpacing.s6),
                _buildTabs(isDark),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildProfileHeader(Worker worker, bool isDark) {
    return PMCard.standard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? PMColors.bgSunkenDark : PMColors.bgSunkenLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                worker.firstName.substring(0, 1) + worker.lastName.substring(0, 1),
                style: PMTypography.display.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(width: PMSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(worker.fullName, style: PMTypography.title),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: worker.status == 'Active'
                            ? (isDark ? PMColors.statusSuccessContainerDark : PMColors.statusSuccessContainerLight)
                            : (isDark ? PMColors.bgSunkenDark : PMColors.bgSunkenLight),
                        borderRadius: PMRadius.sm,
                      ),
                      child: Text(
                        worker.status,
                        style: PMTypography.caption.copyWith(
                          color: worker.status == 'Active'
                              ? (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight)
                              : (isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  worker.role,
                  style: PMTypography.body.copyWith(
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: PMSpacing.s2),
                Text(
                  'ID: ${worker.employeeId}',
                  style: PMTypography.caption.copyWith(
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ),
                Text(
                  'Site: ${worker.siteName}',
                  style: PMTypography.caption.copyWith(
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem('Present', '24', PMColors.statusSuccessDark, isDark),
        _buildStatItem('Absent', '1', PMColors.statusDangerDark, isDark),
        _buildStatItem('Half Day', '2', PMColors.statusWarningDark, isDark),
        _buildStatItem('OT Days', '4', isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight, isDark),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: PMTypography.title.copyWith(color: color),
        ),
        const SizedBox(height: PMSpacing.s1),
        Text(
          label,
          style: PMTypography.caption.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialsRow(bool isDark) {
    return PMCard.standard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFinItem('Monthly Wage', '₹24,500', isDark),
          _buildFinItem('Advances', '₹3,200', isDark),
          _buildFinItem('Total Earnings', '₹27,700', isDark, isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildFinItem(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PMTypography.caption.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: PMSpacing.s1),
        Text(
          value,
          style: PMTypography.headline.copyWith(
            color: isHighlight
                ? (isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight)
                : (isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(bool isDark) {
    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attendance Streak', style: PMTypography.headline),
              Text('18 Days', style: PMTypography.label.copyWith(color: PMColors.statusSuccessDark)),
            ],
          ),
          const SizedBox(height: PMSpacing.s4),
          // Stub for graph
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(15, (index) {
              final isAbsent = index == 4 || index == 9;
              final height = isAbsent ? 10.0 : 40.0;
              return Container(
                width: 12,
                height: height,
                decoration: BoxDecoration(
                  color: isAbsent ? PMColors.statusDangerDark : PMColors.statusSuccessDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTab('Timeline', true, isDark),
        _buildTab('Documents', false, isDark),
        _buildTab('Skills', false, isDark),
        _buildTab('Notes', false, isDark),
      ],
    );
  }

  Widget _buildTab(String label, bool isActive, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: PMTypography.label.copyWith(
            color: isActive
                ? (isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight)
                : (isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight),
          ),
        ),
        const SizedBox(height: PMSpacing.s1),
        if (isActive)
          Container(
            height: 2,
            width: 24,
            color: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
          )
        else
          const SizedBox(height: 2),
      ],
    );
  }
}
