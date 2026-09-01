import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/financial_api.dart';
import '../data/payroll_api.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  final _searchController = TextEditingController();
  final _expandedRunIds = <String>{};
  String _query = '';
  String _status = 'ALL';
  String _tab = 'runs';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(payRunsProvider);
    try {
      await ref.read(payRunsProvider.future);
    } catch (_) {
      // The provider retains the typed failure for the error state below.
    }
  }

  List<PayRunSummary> _filterRuns(List<PayRunSummary> runs) {
    final query = _query.trim().toLowerCase();
    return runs
        .where((run) {
          if (_status != 'ALL' && run.payCycle.status != _status) return false;
          if (query.isEmpty) return true;
          return run.id.toLowerCase().contains(query) ||
              (run.publicId?.toLowerCase().contains(query) ?? false) ||
              run.payCycle.status.toLowerCase().contains(query) ||
              (run.approvedBy?.displayName.toLowerCase().contains(query) ??
                  false) ||
              run.items.any(
                (item) =>
                    item.staff.displayName.toLowerCase().contains(query) ||
                    item.staff.publicId.toLowerCase().contains(query) ||
                    item.staff.workerType.toLowerCase().contains(query),
              );
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? PMColors.bgPrimaryDark
        : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final runs = ref.watch(payRunsProvider);
    final role = ref.watch(
      authControllerProvider.select((state) => state.user?.role),
    );
    final canViewFinancial = role == UserRole.owner ||
        role == UserRole.superAdmin ||
        role == UserRole.admin;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Payroll',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh payroll',
            onPressed: runs.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (canViewFinancial)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PMSpacing.s5,
                PMSpacing.s4,
                PMSpacing.s5,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  key: const Key('payroll-tab-segment'),
                  segments: const [
                    ButtonSegment(value: 'runs', label: Text('Pay Runs')),
                    ButtonSegment(value: 'payments', label: Text('Payments')),
                    ButtonSegment(value: 'expenses', label: Text('Expenses')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) =>
                      setState(() => _tab = selection.first),
                ),
              ),
            ),
          Expanded(
            child: switch (_tab) {
              'payments' => const _PaymentsTab(),
              'expenses' => const _ExpensesTab(),
              _ => runs.when(
        loading: () => const PMListSkeleton(itemCount: 4),
        error: (error, _) => _PayrollErrorState(
          message: _errorMessage(error),
          onRetry: _refresh,
        ),
        data: (allRuns) {
          final filteredRuns = _filterRuns(allRuns);
          final statuses = {
            ...allRuns.map((run) => run.payCycle.status),
            if (_status != 'ALL') _status,
          }.toList()..sort();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PMSpacing.s5,
                          PMSpacing.s5,
                          PMSpacing.s5,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PayrollSummary(runs: allRuns),
                            const SizedBox(height: PMSpacing.s4),
                            _buildFilters(context, statuses),
                            const SizedBox(height: PMSpacing.s4),
                            Text(
                              '${filteredRuns.length} ${filteredRuns.length == 1 ? 'pay run' : 'pay runs'}',
                              style: PMTypography.caption.copyWith(
                                color: isDark
                                    ? PMColors.textSecondaryDark
                                    : PMColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (filteredRuns.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _PayrollEmptyState(hasFilters: allRuns.isNotEmpty),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      PMSpacing.s5,
                      PMSpacing.s3,
                      PMSpacing.s5,
                      PMSpacing.s8,
                    ),
                    sliver: SliverList.separated(
                      itemCount: filteredRuns.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: PMSpacing.s3),
                      itemBuilder: (context, index) {
                        final run = filteredRuns[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: _PayRunCard(
                              run: run,
                              expanded: _expandedRunIds.contains(run.id),
                              onToggleExpanded: () {
                                setState(() {
                                  if (!_expandedRunIds.add(run.id)) {
                                    _expandedRunIds.remove(run.id);
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, List<String> statuses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? PMColors.borderStrongDark
        : PMColors.borderStrongLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search payroll',
            hintText: 'Run ID, staff, or worker type',
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
            border: OutlineInputBorder(
              borderRadius: PMRadius.sm,
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        );
        final status = DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: InputDecoration(
            labelText: 'Pay cycle status',
            prefixIcon: const Icon(Icons.filter_list),
            border: OutlineInputBorder(
              borderRadius: PMRadius.sm,
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          items: [
            const DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
            ...statuses.map(
              (value) =>
                  DropdownMenuItem(value: value, child: Text(_humanize(value))),
            ),
          ],
          onChanged: (value) => setState(() => _status = value ?? 'ALL'),
        );

        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              search,
              const SizedBox(height: PMSpacing.s3),
              status,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: PMSpacing.s3),
            Expanded(child: status),
          ],
        );
      },
    );
  }

  String _errorMessage(Object error) {
    if (error is TenantApiException) return error.message;
    return 'Payroll could not be loaded. Please try again.';
  }
}

class _PayrollSummary extends StatelessWidget {
  const _PayrollSummary({required this.runs});

  final List<PayRunSummary> runs;

  @override
  Widget build(BuildContext context) {
    final totalAmount = runs.fold<double>(
      0,
      (total, run) => total + run.totalAmount,
    );
    final staffEntries = runs.fold<int>(
      0,
      (total, run) => total + run.staffCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - (PMSpacing.s3 * 2)) / 3
            : constraints.maxWidth >= 440
            ? (constraints.maxWidth - PMSpacing.s3) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: PMSpacing.s3,
          runSpacing: PMSpacing.s3,
          children: [
            SizedBox(
              width: width,
              child: _SummaryTile(
                icon: Icons.receipt_long_outlined,
                label: 'Pay runs',
                value: runs.length.toString(),
              ),
            ),
            SizedBox(
              width: width,
              child: _SummaryTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payroll value',
                value: _formatCurrency(totalAmount),
              ),
            ),
            SizedBox(
              width: width,
              child: _SummaryTile(
                icon: Icons.badge_outlined,
                label: 'Staff entries',
                value: staffEntries.toString(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent = isDark
        ? PMColors.brandPrimaryDark
        : PMColors.brandPrimaryLight;

    return PMCard.stat(
      accentColor: accent,
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: PMSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PMTypography.headline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayRunCard extends StatelessWidget {
  const _PayRunCard({
    required this.run,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final PayRunSummary run;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final border = isDark
        ? PMColors.borderDefaultDark
        : PMColors.borderDefaultLight;

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateRange(
                      run.payCycle.startDate,
                      run.payCycle.endDate,
                    ),
                    style: PMTypography.headline,
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  Text(
                    'Run ${_runLabel(run)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PMTypography.caption.copyWith(color: secondary),
                  ),
                ],
              );
              final amount = Column(
                crossAxisAlignment: constraints.maxWidth < 560
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(run.totalAmount),
                    style: PMTypography.headline,
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  _StatusBadge(status: run.payCycle.status),
                ],
              );

              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: PMSpacing.s3),
                    amount,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: PMSpacing.s4),
                  amount,
                ],
              );
            },
          ),
          const SizedBox(height: PMSpacing.s4),
          Wrap(
            spacing: PMSpacing.s5,
            runSpacing: PMSpacing.s2,
            children: [
              _MetadataValue(
                icon: Icons.badge_outlined,
                text:
                    '${run.staffCount} ${run.staffCount == 1 ? 'staff entry' : 'staff entries'}',
              ),
              _MetadataValue(
                icon: Icons.schedule_outlined,
                text: 'Created ${_formatDateTime(run.createdAt)}',
              ),
              if (run.approvedAt != null)
                _MetadataValue(
                  icon: Icons.verified_outlined,
                  text: 'Approved ${_formatDateTime(run.approvedAt!)}',
                ),
              if (run.approvedBy != null)
                _MetadataValue(
                  icon: Icons.person_outline,
                  text: 'By ${run.approvedBy!.displayName}',
                ),
            ],
          ),
          const SizedBox(height: PMSpacing.s3),
          Divider(height: 1, color: border),
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.only(top: PMSpacing.s3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      expanded ? 'Hide staff details' : 'View staff details',
                      style: PMTypography.labelLarge,
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: PMSpacing.s4),
            if (run.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: PMSpacing.s4),
                child: Text(
                  'No active staff items are attached to this pay run.',
                  textAlign: TextAlign.center,
                  style: PMTypography.body.copyWith(color: secondary),
                ),
              )
            else
              ...run.items.indexed.map((entry) {
                final index = entry.$1;
                final item = entry.$2;
                return Column(
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: PMSpacing.s3,
                        ),
                        child: Divider(height: 1, color: border),
                      ),
                    _PayrollItemView(item: item),
                  ],
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _PayrollItemView extends StatelessWidget {
  const _PayrollItemView({required this.item});

  final PayRunItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final positive = isDark
        ? PMColors.statusSuccessDark
        : PMColors.statusSuccessLight;
    final negative = isDark
        ? PMColors.statusDangerDark
        : PMColors.statusDangerLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.staff.displayName, style: PMTypography.labelLarge),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  '${item.staff.publicId} | ${_humanize(item.staff.workerType)} | ${_humanize(item.staff.status)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
              ],
            );
            final net = Column(
              crossAxisAlignment: constraints.maxWidth < 520
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(
                  'Net pay',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  _formatCurrency(item.netPay),
                  style: PMTypography.labelLarge,
                ),
              ],
            );

            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: PMSpacing.s3),
                  net,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: PMSpacing.s3),
                net,
              ],
            );
          },
        ),
        const SizedBox(height: PMSpacing.s3),
        Wrap(
          spacing: PMSpacing.s4,
          runSpacing: PMSpacing.s2,
          children: [
            _MoneyComponent(label: 'Gross', amount: item.grossPay),
            _MoneyComponent(
              label: 'Additions',
              amount: item.additionTotal,
              color: positive,
            ),
            _MoneyComponent(
              label: 'Arrears',
              amount: item.arrearsTotal,
              color: positive,
            ),
            _MoneyComponent(
              label: 'Deductions',
              amount: item.deductionTotal,
              color: negative,
            ),
          ],
        ),
        if (item.additions.isNotEmpty ||
            item.arrears.isNotEmpty ||
            item.deductions.isNotEmpty) ...[
          const SizedBox(height: PMSpacing.s3),
          _AdjustmentDetails(item: item),
        ],
      ],
    );
  }
}

class _MoneyComponent extends StatelessWidget {
  const _MoneyComponent({
    required this.label,
    required this.amount,
    this.color,
  });

  final String label;
  final double amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PMTypography.caption.copyWith(color: secondary)),
          const SizedBox(height: PMSpacing.s1),
          Text(
            _formatCurrency(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PMTypography.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentDetails extends StatelessWidget {
  const _AdjustmentDetails({required this.item});

  final PayRunItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight;

    final entries = <({String label, String name, double amount})>[
      ...item.additions.entries.map(
        (entry) => (label: 'Addition', name: entry.key, amount: entry.value),
      ),
      ...item.arrears.entries.map(
        (entry) => (label: 'Arrears', name: entry.key, amount: entry.value),
      ),
      ...item.deductions.entries.map(
        (entry) => (label: 'Deduction', name: entry.key, amount: entry.value),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(PMSpacing.s3),
      decoration: BoxDecoration(color: background, borderRadius: PMRadius.sm),
      child: Column(
        children: entries
            .map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: PMSpacing.s1),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.label}: ${entry.name}',
                        style: PMTypography.caption,
                      ),
                    ),
                    const SizedBox(width: PMSpacing.s3),
                    Text(
                      _formatCurrency(entry.amount),
                      style: PMTypography.caption,
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _MetadataValue extends StatelessWidget {
  const _MetadataValue({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: PMSpacing.s1),
        Text(text, style: PMTypography.caption.copyWith(color: color)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isApproved = status == 'APPROVED' || status == 'LOCKED';
    final foreground = isApproved
        ? (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight)
        : (isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight);
    final background = isApproved
        ? (isDark
              ? PMColors.statusSuccessContainerDark
              : PMColors.statusSuccessContainerLight)
        : (isDark
              ? PMColors.statusWarningContainerDark
              : PMColors.statusWarningContainerLight);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s2,
        vertical: PMSpacing.s1,
      ),
      decoration: BoxDecoration(color: background, borderRadius: PMRadius.sm),
      child: Text(
        _humanize(status).toUpperCase(),
        style: PMTypography.overline.copyWith(color: foreground),
      ),
    );
  }
}

class _PayrollEmptyState extends StatelessWidget {
  const _PayrollEmptyState({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s3),
            Text(
              hasFilters ? 'No matching pay runs' : 'No pay runs yet',
              style: PMTypography.headline,
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              hasFilters
                  ? 'Adjust the search or pay cycle status filter.'
                  : 'Calculated payroll runs will appear here.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollErrorState extends StatelessWidget {
  const _PayrollErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark
        ? PMColors.statusDangerDark
        : PMColors.statusDangerLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: danger),
            const SizedBox(height: PMSpacing.s3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PMTypography.body,
            ),
            const SizedBox(height: PMSpacing.s4),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _runLabel(PayRunSummary run) {
  final publicId = run.publicId;
  if (publicId != null) return publicId;
  if (run.id.length <= 12) return run.id;
  return '${run.id.substring(0, 12)}...';
}

String _formatCurrency(double amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return 'INR $buffer.${parts.last}';
}

String _formatDateRange(DateTime start, DateTime end) {
  return '${_formatDate(start)} - ${_formatDate(end)}';
}

String _formatDate(DateTime value) {
  final date = value.toUtc();
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String _formatDateTime(DateTime value) {
  final date = value.toLocal();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_months[date.month - 1]} ${date.year}, $hour:$minute';
}

String _humanize(String value) {
  if (value.isEmpty) return value;
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

const _months = [
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

// ---------------------------------------------------------------------------
// Payments / Expenses tabs (owner.txt payroll section) — backend lists from
// GET /financial/payments and /financial/expenses (view_payroll-gated).
// ---------------------------------------------------------------------------

class _PaymentsTab extends ConsumerStatefulWidget {
  const _PaymentsTab();

  @override
  ConsumerState<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<_PaymentsTab> {
  final _items = <PaymentRecord>[];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(financialApiProvider).listPayments();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await ref
          .read(financialApiProvider)
          .listPayments(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _message(Object error) => error is TenantApiException
      ? error.message
      : 'Payments could not be loaded. Please try again.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;

    return _isLoading
        ? const PMListSkeleton(itemCount: 5)
        : _error != null
            ? _PayrollErrorState(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          _FinancialEmptyState(
                            icon: Icons.payments_outlined,
                            title: 'No payments recorded',
                            message:
                                'Approved payroll payments will appear here once they are recorded.',
                            secondary: secondary,
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(PMSpacing.s5),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: PMSpacing.s3),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return Padding(
                              padding: const EdgeInsets.all(PMSpacing.s4),
                              child: FilledButton.tonalIcon(
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Load more'),
                              ),
                            );
                          }
                          return _PaymentCard(payment: _items[index]);
                        },
                      ),
              );
  }
}

class _ExpensesTab extends ConsumerStatefulWidget {
  const _ExpensesTab();

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  final _items = <ExpenseRecord>[];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(financialApiProvider).listExpenses();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error is TenantApiException
            ? error.message
            : 'Expenses could not be loaded. Please try again.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await ref
          .read(financialApiProvider)
          .listExpenses(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;

    return _isLoading
        ? const PMListSkeleton(itemCount: 5)
        : _error != null
            ? _PayrollErrorState(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          _FinancialEmptyState(
                            icon: Icons.receipt_outlined,
                            title: 'No expenses recorded',
                            message:
                                'Site expenses you record will appear here for approval tracking.',
                            secondary: secondary,
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(PMSpacing.s5),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: PMSpacing.s3),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return Padding(
                              padding: const EdgeInsets.all(PMSpacing.s4),
                              child: FilledButton.tonalIcon(
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Load more'),
                              ),
                            );
                          }
                          return _ExpenseCard(expense: _items[index]);
                        },
                      ),
              );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary =
        isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.staffName,
                      style: PMTypography.headline.copyWith(color: textColor),
                    ),
                    if (payment.staffPublicId.isNotEmpty)
                      Text(
                        payment.staffPublicId,
                        style: PMTypography.caption.copyWith(color: secondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(double.tryParse(payment.amount) ?? 0),
                    style: PMTypography.headline.copyWith(color: textColor),
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  _FinancialStatusBadge(status: payment.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: PMSpacing.s3),
          Wrap(
            spacing: PMSpacing.s4,
            runSpacing: PMSpacing.s2,
            children: [
              _MetadataValue(
                icon: Icons.account_balance_outlined,
                text: _humanize(payment.mode),
              ),
              _MetadataValue(
                icon: Icons.schedule_outlined,
                text: 'Recorded ${_formatDateTime(payment.createdAt)}',
              ),
              if (payment.referenceId != null)
                _MetadataValue(
                  icon: Icons.tag_outlined,
                  text: 'Ref ${payment.referenceId}',
                ),
            ],
          ),
          if (payment.failureReason != null &&
              payment.failureReason!.isNotEmpty) ...[
            const SizedBox(height: PMSpacing.s3),
            Text(
              'Failure reason: ${payment.failureReason}',
              style: PMTypography.caption.copyWith(
                color: isDark
                    ? PMColors.statusDangerDark
                    : PMColors.statusDangerLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary =
        isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.siteName.isNotEmpty
                          ? expense.siteName
                          : 'Unassigned site',
                      style: PMTypography.headline.copyWith(color: textColor),
                    ),
                    Text(
                      '${_humanize(expense.category)} · ${_formatDate(expense.date)}',
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(double.tryParse(expense.amount) ?? 0),
                    style: PMTypography.headline.copyWith(color: textColor),
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  _FinancialStatusBadge(status: expense.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: PMSpacing.s3),
          Wrap(
            spacing: PMSpacing.s4,
            runSpacing: PMSpacing.s2,
            children: [
              if (expense.paymentMethod != null)
                _MetadataValue(
                  icon: Icons.account_balance_outlined,
                  text: _humanize(expense.paymentMethod!),
                ),
              if (expense.paidByName.isNotEmpty)
                _MetadataValue(
                  icon: Icons.person_outline,
                  text: 'Paid by ${expense.paidByName}',
                ),
            ],
          ),
          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            const SizedBox(height: PMSpacing.s3),
            Text(
              expense.notes!,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialStatusBadge extends StatelessWidget {
  const _FinancialStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGood = status == 'PAID' ||
        status == 'APPROVED' ||
        status == 'REIMBURSED' ||
        status == 'VERIFIED';
    final isBad = status == 'FAILED' || status == 'REJECTED';
    final foreground = isBad
        ? (isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight)
        : isGood
            ? (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight)
            : (isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight);
    final background = isBad
        ? (isDark
              ? PMColors.statusDangerContainerDark
              : PMColors.statusDangerContainerLight)
        : isGood
            ? (isDark
                  ? PMColors.statusSuccessContainerDark
                  : PMColors.statusSuccessContainerLight)
            : (isDark
                  ? PMColors.statusWarningContainerDark
                  : PMColors.statusWarningContainerLight);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s2,
        vertical: PMSpacing.s1,
      ),
      decoration: BoxDecoration(color: background, borderRadius: PMRadius.sm),
      child: Text(
        _humanize(status).toUpperCase(),
        style: PMTypography.overline.copyWith(color: foreground),
      ),
    );
  }
}

class _FinancialEmptyState extends StatelessWidget {
  const _FinancialEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s3),
            Text(title, style: PMTypography.headline),
            const SizedBox(height: PMSpacing.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}
