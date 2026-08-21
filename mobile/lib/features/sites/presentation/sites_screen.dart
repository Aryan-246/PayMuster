import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/site_api.dart';

class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  final _searchController = TextEditingController();
  final _expandedSiteIds = <String>{};
  String _query = '';
  String _status = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(sitesProvider);
    try {
      await ref.read(sitesProvider.future);
    } catch (_) {
      // The provider retains the typed failure for the error state below.
    }
  }

  List<SiteSummary> _filterSites(List<SiteSummary> sites) {
    final query = _query.trim().toLowerCase();
    return sites
        .where((site) {
          if (_status != 'ALL' && site.status != _status) return false;
          if (query.isEmpty) return true;
          return site.name.toLowerCase().contains(query) ||
              site.publicId.toLowerCase().contains(query) ||
              (site.address?.toLowerCase().contains(query) ?? false) ||
              (site.manager?.displayName.toLowerCase().contains(query) ??
                  false) ||
              (site.supervisor?.displayName.toLowerCase().contains(query) ??
                  false) ||
              site.workers.any(
                (worker) =>
                    worker.displayName.toLowerCase().contains(query) ||
                    worker.publicId.toLowerCase().contains(query),
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
    final sites = ref.watch(sitesProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Sites',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh sites',
            onPressed: sites.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: sites.when(
        loading: () => const PMListSkeleton(itemCount: 4),
        error: (error, _) =>
            _SitesErrorState(message: _errorMessage(error), onRetry: _refresh),
        data: (allSites) {
          final filteredSites = _filterSites(allSites);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
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
                            _SitesSummary(sites: allSites),
                            const SizedBox(height: PMSpacing.s4),
                            _buildFilters(context),
                            const SizedBox(height: PMSpacing.s4),
                            Text(
                              '${filteredSites.length} ${filteredSites.length == 1 ? 'site' : 'sites'}',
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
                if (filteredSites.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SitesEmptyState(hasFilters: allSites.isNotEmpty),
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
                      itemCount: filteredSites.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: PMSpacing.s3),
                      itemBuilder: (context, index) {
                        final site = filteredSites[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: _SiteCard(
                              site: site,
                              expanded: _expandedSiteIds.contains(site.id),
                              onToggleExpanded: () {
                                setState(() {
                                  if (!_expandedSiteIds.add(site.id)) {
                                    _expandedSiteIds.remove(site.id);
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
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            labelText: 'Search sites',
            hintText: 'Name, ID, address, or person',
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
            labelText: 'Status',
            prefixIcon: const Icon(Icons.filter_list),
            border: OutlineInputBorder(
              borderRadius: PMRadius.sm,
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
            DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
            DropdownMenuItem(value: 'PLANNED', child: Text('Planned')),
            DropdownMenuItem(value: 'ON_HOLD', child: Text('On hold')),
            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
            DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
          ],
          onChanged: (value) => setState(() => _status = value ?? 'ALL'),
        );

        if (constraints.maxWidth < 620) {
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
    return 'Sites could not be loaded. Please try again.';
  }
}

class _SitesSummary extends StatelessWidget {
  const _SitesSummary({required this.sites});

  final List<SiteSummary> sites;

  @override
  Widget build(BuildContext context) {
    final activeSites = sites.where((site) => site.isActive).length;
    final activeWorkers = sites
        .where((site) => site.isActive)
        .fold<int>(0, (total, site) => total + site.workerCount);
    final approvedExpenses = sites.fold<double>(
      0,
      (total, site) => total + site.approvedExpenseTotal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - (PMSpacing.s3 * 2)) / 3
            : constraints.maxWidth >= 420
            ? (constraints.maxWidth - PMSpacing.s3) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: PMSpacing.s3,
          runSpacing: PMSpacing.s3,
          children: [
            _SummaryTile(
              width: width,
              icon: Icons.location_city_outlined,
              label: 'Active sites',
              value: activeSites.toString(),
            ),
            _SummaryTile(
              width: width,
              icon: Icons.badge_outlined,
              label: 'Active placements',
              value: activeWorkers.toString(),
            ),
            _SummaryTile(
              width: width,
              icon: Icons.receipt_long_outlined,
              label: 'Approved expenses',
              value: _formatCurrency(approvedExpenses),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent = isDark
        ? PMColors.brandPrimaryDark
        : PMColors.brandPrimaryLight;

    return SizedBox(
      width: width,
      child: PMCard.stat(
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
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PMTypography.headline.copyWith(color: textColor),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PMTypography.caption.copyWith(color: secondary),
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

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final SiteSummary site;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final statusColor = _statusColor(site.status, isDark);

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.name,
                      style: PMTypography.headline.copyWith(color: textColor),
                    ),
                    const SizedBox(height: PMSpacing.s1),
                    SelectableText(
                      site.publicId,
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PMSpacing.s3),
              _StatusBadge(status: site.status, color: statusColor),
            ],
          ),
          if (site.address != null) ...[
            const SizedBox(height: PMSpacing.s3),
            _InfoLine(icon: Icons.location_on_outlined, value: site.address!),
          ],
          const SizedBox(height: PMSpacing.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                _DetailField(
                  label: 'Workers',
                  value: site.workerCount.toString(),
                ),
                _DetailField(
                  label: 'Manager',
                  value: site.manager?.displayName ?? 'Not assigned',
                ),
                _DetailField(
                  label: 'Supervisor',
                  value: site.supervisor?.displayName ?? 'Not assigned',
                ),
                _DetailField(
                  label: 'Approved expenses',
                  value: _formatCurrency(site.approvedExpenseTotal),
                ),
              ];
              final fieldWidth = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - (PMSpacing.s4 * 3)) / 4
                  : constraints.maxWidth >= 400
                  ? (constraints.maxWidth - PMSpacing.s4) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: PMSpacing.s4,
                runSpacing: PMSpacing.s3,
                children: [
                  for (final field in fields)
                    SizedBox(width: fieldWidth, child: field),
                ],
              );
            },
          ),
          if (site.startDate != null || site.expectedEndDate != null) ...[
            const SizedBox(height: PMSpacing.s4),
            Text(
              _dateRange(site),
              style: PMTypography.caption.copyWith(color: secondary),
            ),
          ],
          const SizedBox(height: PMSpacing.s2),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: expanded
                  ? 'Hide assigned workers'
                  : 'Show assigned workers',
              onPressed: onToggleExpanded,
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ),
          ),
          AnimatedCrossFade(
            duration: PMMotion.fast,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _AssignedWorkers(workers: site.workers),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s2,
        vertical: PMSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: PMRadius.sm,
      ),
      child: Text(
        _humanize(status),
        style: PMTypography.caption.copyWith(color: color),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: PMSpacing.s2),
        Expanded(
          child: Text(value, style: PMTypography.body.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PMTypography.caption.copyWith(color: secondary)),
        const SizedBox(height: PMSpacing.s1),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: PMTypography.labelLarge.copyWith(color: textColor),
        ),
      ],
    );
  }
}

class _AssignedWorkers extends StatelessWidget {
  const _AssignedWorkers({required this.workers});

  final List<SiteWorker> workers;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final border = isDark
        ? PMColors.borderDefaultDark
        : PMColors.borderDefaultLight;

    return Container(
      padding: const EdgeInsets.only(top: PMSpacing.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assigned workers',
            style: PMTypography.labelLarge.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s2),
          if (workers.isEmpty)
            Text(
              'No active workers are assigned.',
              style: PMTypography.body.copyWith(color: secondary),
            )
          else
            ...workers.map(
              (worker) => Padding(
                padding: const EdgeInsets.symmetric(vertical: PMSpacing.s2),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      child: Text(_initials(worker.displayName)),
                    ),
                    const SizedBox(width: PMSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.displayName,
                            style: PMTypography.labelLarge.copyWith(
                              color: textColor,
                            ),
                          ),
                          Text(
                            '${worker.publicId}  |  ${_humanize(worker.workerType)}',
                            style: PMTypography.caption.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SitesErrorState extends StatelessWidget {
  const _SitesErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
            Icon(Icons.location_off_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'Sites unavailable',
              textAlign: TextAlign.center,
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
            const SizedBox(height: PMSpacing.s5),
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

class _SitesEmptyState extends StatelessWidget {
  const _SitesEmptyState({required this.hasFilters});

  final bool hasFilters;

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
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s4),
            Text(
              hasFilters ? 'No matching sites' : 'No sites available',
              textAlign: TextAlign.center,
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              hasFilters
                  ? 'Try a different search or status filter.'
                  : 'Sites will appear here when they are available.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status, bool isDark) {
  return switch (status) {
    'ACTIVE' =>
      isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight,
    'ON_HOLD' =>
      isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight,
    'CANCELLED' =>
      isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight,
    'COMPLETED' =>
      isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
    _ => isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
  };
}

String _formatCurrency(double amount) => 'INR ${amount.toStringAsFixed(2)}';

String _humanize(String value) {
  final words = value.toLowerCase().split('_');
  return words
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

String _dateRange(SiteSummary site) {
  final start = site.startDate == null ? null : _formatDate(site.startDate!);
  final end = site.expectedEndDate == null
      ? null
      : _formatDate(site.expectedEndDate!);
  if (start != null && end != null) return '$start - $end';
  if (start != null) return 'Started $start';
  return 'Expected completion $end';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
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
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
