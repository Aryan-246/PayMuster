import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../../components/layout/pm_card.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../sites/data/site_api.dart';
import 'attendance_controller.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? PMColors.bgPrimaryDark
        : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Attendance',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh attendance',
            onPressed: state.isLoading || state.isSubmitting
                ? null
                : () => ref.read(attendanceControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildBody(state)),
            if (!state.isLoading && state.error == null)
              _SubmitBar(
                pendingCount: state.selections.length,
                isSubmitting: state.isSubmitting,
                onSubmit: state.selections.isEmpty
                    ? null
                    : () => ref
                          .read(attendanceControllerProvider.notifier)
                          .submit(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AttendanceState state) {
    if (state.isLoading) return const PMListSkeleton(itemCount: 5);
    if (state.error != null) {
      return _AttendanceMessage(
        icon: Icons.event_busy_outlined,
        title: 'Attendance unavailable',
        message: state.error!,
        actionLabel: 'Retry',
        onAction: () => ref.read(attendanceControllerProvider.notifier).load(),
      );
    }
    if (state.sites.isEmpty) {
      return const _AttendanceMessage(
        icon: Icons.location_off_outlined,
        title: 'No active sites',
        message: 'Attendance can be marked only for workers at active sites.',
      );
    }

    final query = _query.trim().toLowerCase();
    final workers = state.workers
        .where((worker) {
          return query.isEmpty ||
              worker.displayName.toLowerCase().contains(query) ||
              worker.publicId.toLowerCase().contains(query) ||
              worker.workerType.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => ref.read(attendanceControllerProvider.notifier).load(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildControls(state)),
          if (state.notice != null)
            SliverToBoxAdapter(child: _NoticeBanner(message: state.notice!)),
          SliverToBoxAdapter(child: _AttendanceSummary(state: state)),
          if (workers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _AttendanceMessage(
                icon: Icons.badge_outlined,
                title: state.workers.isEmpty
                    ? 'No assigned workers'
                    : 'No matching workers',
                message: state.workers.isEmpty
                    ? 'This site has no active Staff assignments.'
                    : 'Try a different worker search.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PMSpacing.s5,
                PMSpacing.s2,
                PMSpacing.s5,
                PMSpacing.s6,
              ),
              sliver: SliverList.separated(
                itemCount: workers.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PMSpacing.s3),
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _WorkerAttendanceCard(
                        worker: worker,
                        status: state.statusFor(worker.id),
                        persisted: state.isPersisted(worker.id),
                        enabled: !state.isSubmitting,
                        onStatusChanged: (status) => ref
                            .read(attendanceControllerProvider.notifier)
                            .markAttendance(worker.id, status),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(AttendanceState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PMSpacing.s5,
            PMSpacing.s5,
            PMSpacing.s5,
            PMSpacing.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final site = DropdownButtonFormField<String>(
                    initialValue: state.selectedSiteId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Site',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: state.sites
                        .map(
                          (site) => DropdownMenuItem(
                            value: site.id,
                            child: Text(
                              site.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: state.isSubmitting
                        ? null
                        : (siteId) {
                            if (siteId != null) {
                              ref
                                  .read(attendanceControllerProvider.notifier)
                                  .selectSite(siteId);
                            }
                          },
                  );
                  final date = OutlinedButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () => _selectDate(state.selectedDate),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_formatDate(state.selectedDate)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(180, 56),
                    ),
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        site,
                        const SizedBox(height: PMSpacing.s3),
                        date,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: site),
                      const SizedBox(width: PMSpacing.s3),
                      date,
                    ],
                  );
                },
              ),
              const SizedBox(height: PMSpacing.s3),
              PMTextInput(
                controller: _searchController,
                hintText: 'Search assigned workers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                enabled: !state.isSubmitting,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: PMSpacing.s2),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: state.isSubmitting || state.workers.isEmpty
                      ? null
                      : () => ref
                            .read(attendanceControllerProvider.notifier)
                            .markAllPresent(),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark unsaved present'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(DateTime selectedDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    await ref.read(attendanceControllerProvider.notifier).selectDate(picked);
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({required this.state});

  final AttendanceState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PMSpacing.s5,
            vertical: PMSpacing.s2,
          ),
          child: Wrap(
            spacing: PMSpacing.s3,
            runSpacing: PMSpacing.s2,
            children: [
              _SummaryItem(label: 'Workers', value: state.workers.length),
              _SummaryItem(
                label: 'Present',
                value: state.countStatus('PRESENT'),
                color: _successColor(context),
              ),
              _SummaryItem(
                label: 'Absent',
                value: state.countStatus('ABSENT'),
                color: _dangerColor(context),
              ),
              _SummaryItem(
                label: 'Saved',
                value: state.records.length,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        color ??
        (isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s3,
        vertical: PMSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
        borderRadius: PMRadius.sm,
      ),
      child: Text(
        '$label: $value',
        style: PMTypography.caption.copyWith(color: foreground),
      ),
    );
  }
}

class _WorkerAttendanceCard extends StatelessWidget {
  const _WorkerAttendanceCard({
    required this.worker,
    required this.status,
    required this.persisted,
    required this.enabled,
    required this.onStatusChanged,
  });

  final SiteWorker worker;
  final String? status;
  final bool persisted;
  final bool enabled;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return PMCard.standard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Text(_initials(worker.displayName)),
              ),
              const SizedBox(width: PMSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PMTypography.headline.copyWith(color: textColor),
                    ),
                    const SizedBox(height: PMSpacing.s1),
                    Text(
                      '${worker.publicId}  |  ${_humanize(worker.workerType)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          );
          final controls = _StatusControls(
            status: status,
            persisted: persisted,
            enabled: enabled,
            onChanged: onStatusChanged,
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: PMSpacing.s3),
                controls,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: PMSpacing.s4),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _StatusControls extends StatelessWidget {
  const _StatusControls({
    required this.status,
    required this.persisted,
    required this.enabled,
    required this.onChanged,
  });

  final String? status;
  final bool persisted;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (persisted) {
      return _StatusBadge(status: status ?? 'RECORDED', persisted: true);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Present',
          onPressed: enabled ? () => onChanged('PRESENT') : null,
          isSelected: status == 'PRESENT',
          icon: const Icon(Icons.check),
        ),
        const SizedBox(width: PMSpacing.s2),
        IconButton.filledTonal(
          tooltip: 'Absent',
          onPressed: enabled ? () => onChanged('ABSENT') : null,
          isSelected: status == 'ABSENT',
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: PMSpacing.s2),
        PopupMenuButton<String>(
          tooltip: 'More attendance statuses',
          enabled: enabled,
          onSelected: onChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'HALF_DAY', child: Text('Half day')),
            PopupMenuItem(value: 'LEAVE', child: Text('Leave')),
            PopupMenuItem(value: 'HOLIDAY', child: Text('Holiday')),
          ],
          icon: const Icon(Icons.more_horiz),
        ),
        if (status != null) ...[
          const SizedBox(width: PMSpacing.s2),
          Flexible(child: _StatusBadge(status: status!, persisted: false)),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.persisted});

  final String status;
  final bool persisted;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s2,
        vertical: PMSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: PMRadius.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (persisted) ...[
            Icon(Icons.cloud_done_outlined, size: 14, color: color),
            const SizedBox(width: PMSpacing.s1),
          ],
          Flexible(
            child: Text(
              _humanize(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PMTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.pendingCount,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int pendingCount;
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark
                ? PMColors.borderDefaultDark
                : PMColors.borderDefaultLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SizedBox(
              width: double.infinity,
              child: PMButton.primary(
                label: pendingCount == 0
                    ? 'No unsaved attendance'
                    : 'Save $pendingCount ${pendingCount == 1 ? 'record' : 'records'}',
                icon: Icons.cloud_upload_outlined,
                isLoading: isSubmitting,
                onPressed: onSubmit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            PMSpacing.s5,
            PMSpacing.s2,
            PMSpacing.s5,
            0,
          ),
          padding: const EdgeInsets.all(PMSpacing.s3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: PMRadius.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: color),
              const SizedBox(width: PMSpacing.s2),
              Expanded(
                child: Text(
                  message,
                  style: PMTypography.body.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceMessage extends StatelessWidget {
  const _AttendanceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: PMSpacing.s5),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  return switch (status) {
    'PRESENT' => _successColor(context),
    'ABSENT' => _dangerColor(context),
    'HALF_DAY' || 'LEAVE' || 'HOLIDAY' =>
      Theme.of(context).brightness == Brightness.dark
          ? PMColors.statusWarningDark
          : PMColors.statusWarningLight,
    _ => Theme.of(context).colorScheme.primary,
  };
}

Color _successColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? PMColors.statusSuccessDark
      : PMColors.statusSuccessLight;
}

Color _dangerColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? PMColors.statusDangerDark
      : PMColors.statusDangerLight;
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _humanize(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _initials(String name) {
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
