import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/paymuster_tokens.dart';
import '../../../components/layout/pm_card.dart';
import '../domain/worker.dart';
import '../data/worker_repository.dart';

/// Worker profile backed by GET /api/v1/staff/:id. Every value rendered is
/// server data — no fabricated attendance stats, wages, or streaks (the roster
/// API intentionally excludes financial PII).
class WorkerProfileScreen extends ConsumerWidget {
  final String workerId;

  const WorkerProfileScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final workerAsync = ref.watch(workerDetailProvider(workerId));

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
      body: workerAsync.when(
        data: (worker) => _buildProfile(context, ref, worker, isDark),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(context, ref, isDark, error),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, Worker worker, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(worker, isDark),
          const SizedBox(height: PMSpacing.s4),
          _buildDetailsCard(worker, isDark),
          const SizedBox(height: PMSpacing.s6),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
            ),
            const SizedBox(height: PMSpacing.s4),
            Text('Worker profile unavailable', style: PMTypography.headline),
            const SizedBox(height: PMSpacing.s2),
            Text(
              error.toString(),
              style: PMTypography.body.copyWith(
                color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PMSpacing.s4),
            TextButton.icon(
              onPressed: () => ref.invalidate(workerDetailProvider(workerId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Worker worker, bool isDark) {
    final isActive = worker.status == 'ACTIVE';
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
                worker.initials,
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
                    Expanded(
                      child: Text(
                        worker.displayName,
                        style: PMTypography.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isDark ? PMColors.statusSuccessContainerDark : PMColors.statusSuccessContainerLight)
                            : (isDark ? PMColors.bgSunkenDark : PMColors.bgSunkenLight),
                        borderRadius: PMRadius.sm,
                      ),
                      child: Text(
                        worker.status,
                        style: PMTypography.caption.copyWith(
                          color: isActive
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
                  worker.workerType,
                  style: PMTypography.body.copyWith(
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: PMSpacing.s2),
                // Public ID — never the internal UUID — is what users see.
                if (worker.publicId != null)
                  Text(
                    'ID: ${worker.publicId}',
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

  Widget _buildDetailsCard(Worker worker, bool isDark) {
    final joinDate = worker.joinDate;
    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: PMTypography.headline),
          const SizedBox(height: PMSpacing.s4),
          if (worker.phone != null) _buildDetailRow('Phone', worker.phone!, isDark),
          if (worker.email != null) _buildDetailRow('Email', worker.email!, isDark),
          if (joinDate != null)
            _buildDetailRow(
              'Joined',
              '${joinDate.year}-${joinDate.month.toString().padLeft(2, '0')}-${joinDate.day.toString().padLeft(2, '0')}',
              isDark,
            ),
          _buildDetailRow('Documents on file', worker.documentCount.toString(), isDark),
          _buildDetailRow('Site assignments', worker.siteAssignmentCount.toString(), isDark),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PMSpacing.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: PMTypography.body.copyWith(
              color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: PMTypography.body.copyWith(
                color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
