import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Subscriptions — the platform subscriber list (§4). Real rows from
/// GET /admin/subscriptions with search/filter/sort and pagination; every
/// metric is server-derived.
class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  static const _statusFilters = [
    'ALL',
    'TRIALING',
    'ACTIVE',
    'PAST_DUE',
    'EXPIRED',
    'CANCELED',
    'NO_SUBSCRIPTION',
  ];

  /// Friendly labels for the status filter chips.
  static const _statusLabels = {
    'ALL': 'All',
    'NO_SUBSCRIPTION': 'No subscription',
  };

  final _searchController = TextEditingController();
  List<AdminSubscriber> _subscribers = [];
  AdminSubscriptionsSummary? _summary;
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String _status = 'ALL';
  String _trial = 'ALL';
  String _unlimited = 'ALL';
  String _search = '';
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _subscribers = [];
      }
    });

    try {
      final result = await ref.read(adminApiClientProvider).getSubscriptions(
            search: _search.isNotEmpty ? _search : null,
            status: _status,
            trial: _trial,
            unlimited: _unlimited,
            page: reset ? 1 : _page,
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final rows = result['subscribers'] as List<AdminSubscriber>;
        _subscribers = reset ? rows : [..._subscribers, ...rows];
        _summary = result['summary'] as AdminSubscriptionsSummary?;
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 1;
        _page = (result['page'] as num?)?.toInt() ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() => _load(reset: true);

  @override
  Widget build(BuildContext context) {
    final body = _isLoading && _subscribers.isEmpty
        ? const AdminLoadingState()
        : _error != null && _subscribers.isEmpty
            ? AdminErrorState(error: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AdminSpacing.md),
                  children: [
                    if (_summary != null) ...[
                      _buildSummary(_summary!),
                      const SizedBox(height: AdminSpacing.md),
                    ],
                    _buildFilterBar(),
                    const SizedBox(height: AdminSpacing.md),
                    if (_subscribers.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.card_membership_outlined,
                        title: 'No subscribers',
                        message:
                            'No organizations match the current filters. Every '
                            'organization on the platform is listed here — including '
                            'those without a subscription yet.',
                      )
                    else
                      ..._subscribers.map(_buildSubscriberCard),
                    if (_page < _totalPages)
                      Padding(
                        padding: const EdgeInsets.only(top: AdminSpacing.md),
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : () {
                            _page += 1;
                            _load(reset: false);
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'Load more ($_page/$_totalPages)',
                          ),
                        ),
                      ),
                    if (_error != null && _subscribers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AdminSpacing.md),
                        child: AdminErrorState(error: _error!, onRetry: _load),
                      ),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Subscriptions'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _applyFilter,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSummary(AdminSubscriptionsSummary s) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainer,
        borderRadius: AdminRadius.xl,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCell('Total', s.total, AdminColors.primary),
          ),
          Expanded(child: _summaryCell('Active', s.activeCount, AdminColors.success)),
          Expanded(child: _summaryCell('Trials', s.trialCount, AdminColors.warning)),
          Expanded(child: _summaryCell('Unlimited', s.unlimitedCount, AdminColors.info)),
          Expanded(child: _summaryCell('No plan', s.noSubscriptionCount, AdminColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: AdminTypography.titleMd.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AdminTypography.bodySm.copyWith(
            color: AdminColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _search = value.trim();
            _applyFilter();
          },
          decoration: InputDecoration(
            hintText: 'Search company, public ID or plan…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _search = '';
                      _applyFilter();
                    },
                  )
                : null,
            filled: true,
            fillColor: AdminColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: AdminRadius.md,
              borderSide: const BorderSide(color: AdminColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AdminRadius.md,
              borderSide: const BorderSide(color: AdminColors.glassBorder),
            ),
          ),
        ),
        const SizedBox(height: AdminSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('Status', _status, _statusFilters, (v) {
                setState(() => _status = v);
                _applyFilter();
              }, labels: _statusLabels),
              const SizedBox(width: AdminSpacing.sm),
              _filterChip(
                'Trial',
                _trial,
                const ['ALL', 'ACTIVE', 'EXPIRED', 'NONE'],
                (v) {
                  setState(() => _trial = v);
                  _applyFilter();
                },
              ),
              const SizedBox(width: AdminSpacing.sm),
              _filterChip(
                'Access',
                _unlimited,
                const ['ALL', 'GRANTED', 'STANDARD'],
                (v) {
                  setState(() => _unlimited = v);
                  _applyFilter();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onSelected, {
    Map<String, String> labels = const {},
  }) {
    String display(String v) => labels[v] ?? (v == 'ALL' ? 'All' : v);
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (o) => PopupMenuItem(value: o, child: Text(display(o))),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.compact,
          vertical: AdminSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: value == 'ALL'
              ? AdminColors.surfaceContainerHigh
              : AdminColors.primary.withValues(alpha: 0.12),
          borderRadius: AdminRadius.full,
          border: Border.all(
            color: value == 'ALL'
                ? AdminColors.glassBorder
                : AdminColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${display(value)}',
              style: AdminTypography.labelSm.copyWith(
                color: value == 'ALL'
                    ? AdminColors.onSurfaceVariant
                    : AdminColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: AdminColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriberCard(AdminSubscriber s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AdminRadius.xl,
          onTap: () => context.go('/admin/subscriptions/${s.orgId}'),
          child: Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminColors.surfaceContainer,
              borderRadius: AdminRadius.xl,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.orgName,
                        style: AdminTypography.titleMd.copyWith(
                          color: AdminColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.unlimitedAccess)
                      const Padding(
                        padding: EdgeInsets.only(left: AdminSpacing.sm),
                        child: AdminBadge(
                          label: 'UNLIMITED',
                          color: AdminColors.info,
                          icon: Icons.all_inclusive,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  '${s.orgPublicId} • ${s.ownerName ?? 'No owner'}'
                  '${s.ownerPublicId != null ? ' (${s.ownerPublicId})' : ''}',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AdminSpacing.sm),
                Row(
                  children: [
                    AdminBadge.status(
                      s.isTrialActive ? 'TRIALING' : s.status,
                    ),
                    const SizedBox(width: AdminSpacing.sm),
                    if (s.hasSubscription)
                      AdminBadge(
                        label: s.planCode,
                        color: AdminColors.secondary,
                      )
                    else
                      const AdminBadge(
                        label: 'NO PLAN',
                        color: AdminColors.neutral,
                        icon: Icons.info_outline,
                      ),
                    const Spacer(),
                    Text(
                      s.hasSubscription && s.currentPeriodEnd != null
                          ? 'Ends ${_shortDate(s.currentPeriodEnd!)}'
                          : 'No active period',
                      style: AdminTypography.bodySm.copyWith(
                        color: AdminColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
