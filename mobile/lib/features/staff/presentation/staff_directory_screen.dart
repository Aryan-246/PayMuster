import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/staff_directory_api.dart';
import 'staff_directory_controller.dart';

/// Owner/ADMIN staff directory: server-side search + filters + pagination
/// against GET /api/v1/staff (view_staff). Financial PII lives only in the
/// manage_staff-gated profile screen reached by tapping a row.
class StaffDirectoryScreen extends ConsumerWidget {
  const StaffDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;

    final state = ref.watch(staffDirectoryControllerProvider);
    final controller =
        ref.read(staffDirectoryControllerProvider.notifier);
    final user = ref.watch(authControllerProvider).user;
    final canManageStaff =
        user?.role == UserRole.owner ||
        user?.role == UserRole.admin ||
        user?.role == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Staff',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh staff',
            onPressed:
                state.isLoading ? null : () => controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canManageStaff
          ? FloatingActionButton.extended(
              heroTag: 'add-staff',
              onPressed: () => context.push('/app/staff/new'),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add Worker'),
            )
          : null,
      body: Column(
        children: [
          _StaffFilters(state: state, controller: controller),
          Expanded(
            child: state.isLoading
                ? const PMListSkeleton(itemCount: 6)
                : state.error != null && state.items.isEmpty
                    ? _StaffErrorState(
                        message: state.error!,
                        onRetry: controller.refresh,
                      )
                    : RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: state.items.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  _StaffEmptyState(),
                                ],
                              )
                            : _StaffList(state: state),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StaffFilters extends StatelessWidget {
  const _StaffFilters({required this.state, required this.controller});

  final StaffDirectoryState state;
  final StaffDirectoryController controller;

  static const _statusFilters = [
    (null, 'All'),
    ('ACTIVE', 'Active'),
    ('INACTIVE', 'Inactive'),
    ('TERMINATED', 'Terminated'),
  ];

  static const _workerTypeFilters = [
    (null, 'All types'),
    ('DAILY', 'Daily'),
    ('MONTHLY', 'Monthly'),
    ('CONTRACT', 'Contract'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final border =
        isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;

    return Material(
      color: surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PMSpacing.s5, PMSpacing.s4, PMSpacing.s5, PMSpacing.s4,
        ),
        child: Column(
          children: [
            TextField(
              key: const Key('staff-search-field'),
              onChanged: controller.setSearch,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email or ID',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: PMSpacing.s4,
                  vertical: PMSpacing.s3,
                ),
                border: OutlineInputBorder(
                  borderRadius: PMRadius.md,
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: PMRadius.md,
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: PMSpacing.s3),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (value, label) in _statusFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: PMSpacing.s2),
                      child: _FilterChip(
                        label: label,
                        selected: state.status == value,
                        onTap: () => controller.setStatus(value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: PMSpacing.s2),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (value, label) in _workerTypeFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: PMSpacing.s2),
                      child: _FilterChip(
                        label: label,
                        selected: state.workerType == value,
                        onTap: () => controller.setWorkerType(value),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;
    final border =
        isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;

    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: PMRadius.md,
        side: BorderSide(color: selected ? accent : border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: PMRadius.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s4),
          child: Center(
            child: Text(
              label,
              style: PMTypography.caption.copyWith(
                color: selected ? accent : null,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffList extends ConsumerWidget {
  const _StaffList({required this.state});

  final StaffDirectoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(staffDirectoryControllerProvider.notifier);
    final items = state.items;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        PMSpacing.s5, PMSpacing.s4, PMSpacing.s5, PMSpacing.s12,
      ),
      itemCount: items.length + (state.hasMore || state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: PMSpacing.s3),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(PMSpacing.s4),
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(PMSpacing.s4),
            child: PMButton.secondary(
              label: 'Load more',
              icon: Icons.expand_more,
              onPressed: controller.loadMore,
            ),
          );
        }
        final member = items[index];
        return _StaffMemberCard(member: member);
      },
    );
  }
}

class _StaffMemberCard extends StatelessWidget {
  const _StaffMemberCard({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent =
        isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;

    return PMCard.standard(
      child: InkWell(
        borderRadius: PMRadius.md,
        onTap: () => context.push('/app/staff/${member.id}'),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Text(
                member.firstName.isNotEmpty
                    ? member.firstName.substring(0, 1).toUpperCase()
                    : '?',
                style: PMTypography.headline.copyWith(color: accent),
              ),
            ),
            const SizedBox(width: PMSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: PMTypography.headline.copyWith(color: textColor),
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  Text(
                    [
                      member.publicId,
                      _workerTypeLabel(member.workerType),
                      if (member.phone != null) member.phone!,
                    ].join(' · '),
                    style: PMTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: member.status),
            const SizedBox(width: PMSpacing.s2),
            Icon(Icons.chevron_right, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'ACTIVE' => (PMColors.statusSuccessLight, 'Active'),
      'INACTIVE' => (PMColors.statusWarningLight, 'Inactive'),
      'TERMINATED' => (PMColors.statusDangerLight, 'Terminated'),
      _ => (PMColors.statusWarningLight, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s3,
        vertical: PMSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: PMRadius.sm,
      ),
      child: Text(
        label,
        style: PMTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StaffEmptyState extends StatelessWidget {
  const _StaffEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'No workers found',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'Adjust the filters, or add your first worker with the button below.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffErrorState extends StatelessWidget {
  const _StaffErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: PMColors.statusDangerLight,
              ),
              const SizedBox(height: PMSpacing.s4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PMTypography.body.copyWith(color: textColor),
              ),
              const SizedBox(height: PMSpacing.s4),
              PMButton.secondary(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _workerTypeLabel(String workerType) {
  return switch (workerType) {
    'DAILY' => 'Daily wage',
    'MONTHLY' => 'Monthly',
    'CONTRACT' => 'Contract',
    _ => workerType,
  };
}
