import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Customer Reviews admin (§ latest directive #5): rating summary (average,
/// distribution, total) + tabbed list All/Pending/Published/Hidden/Flagged +
/// search. Tap → moderation detail. All rows are real Review records.
class AdminReviewsScreen extends ConsumerStatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  ConsumerState<AdminReviewsScreen> createState() =>
      _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends ConsumerState<AdminReviewsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['ALL', 'PENDING', 'PUBLISHED', 'HIDDEN', 'FLAGGED'];

  final _searchController = TextEditingController();
  late final TabController _tabController;

  List<AdminReview> _reviews = [];
  AdminReviewSummary? _summary;
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String _search = '';
  String _status = 'ALL';
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final status = _tabs[_tabController.index];
    if (status == _status) return;
    _status = status;
    _load(reset: true);
  }

  Future<void> _load({bool reset = true}) async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _reviews = [];
      }
    });

    try {
      final client = ref.read(adminApiClientProvider);
      final results = await Future.wait([
        client.getReviews(
          search: _search.isNotEmpty ? _search : null,
          status: _status,
          page: reset ? 1 : _page,
        ),
        reset ? client.getReviewSummary() : Future.value(null),
      ]);
      if (!mounted || generation != _loadGeneration) return;

      final result = results[0] as Map<String, dynamic>;
      final summary = results[1] as AdminReviewSummary?;
      setState(() {
        final rows = result['reviews'] as List<AdminReview>;
        _reviews = reset ? rows : [..._reviews, ...rows];
        if (summary != null) _summary = summary;
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

  @override
  Widget build(BuildContext context) {
    final body = _isLoading && _reviews.isEmpty && _summary == null
        ? const AdminLoadingState()
        : _error != null && _reviews.isEmpty
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
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        _search = value.trim();
                        _load(reset: true);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search review ID, text, user or company…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _search = '';
                                  _load(reset: true);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AdminColors.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: AdminRadius.md,
                          borderSide:
                              const BorderSide(color: AdminColors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AdminRadius.md,
                          borderSide:
                              const BorderSide(color: AdminColors.glassBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    if (_reviews.isEmpty && !_isLoading)
                      AdminEmptyState(
                        icon: Icons.rate_review_outlined,
                        title: _status == 'ALL'
                            ? 'No reviews yet'
                            : 'No ${_status.toLowerCase()} reviews',
                        message: _status == 'PENDING'
                            ? 'Newly submitted reviews await moderation here.'
                            : 'Company users can submit reviews from their '
                                'app; they appear here immediately.',
                      )
                    else
                      ..._reviews.map(_buildReviewCard),
                    if (_page < _totalPages)
                      Padding(
                        padding: const EdgeInsets.only(top: AdminSpacing.md),
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _page += 1;
                                  _load(reset: false);
                                },
                          icon: const Icon(Icons.expand_more),
                          label: Text('Load more ($_page/$_totalPages)'),
                        ),
                      ),
                    if (_error != null && _reviews.isNotEmpty)
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
        title: const Text('Customer Reviews'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _load(reset: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AdminColors.primary,
          labelColor: AdminColors.primary,
          unselectedLabelColor: AdminColors.onSurfaceVariant,
          tabs: [
            const Tab(text: 'All'),
            Tab(text: 'Pending${_summary?.pendingCount != null ? ' (${_summary!.pendingCount})' : ''}'),
            Tab(text: 'Published${_summary?.publishedCount != null ? ' (${_summary!.publishedCount})' : ''}'),
            Tab(text: 'Hidden${_summary?.hiddenCount != null ? ' (${_summary!.hiddenCount})' : ''}'),
            Tab(text: 'Flagged${_summary?.flaggedCount != null ? ' (${_summary!.flaggedCount})' : ''}'),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildSummary(AdminReviewSummary s) {
    return Container(
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
              const Icon(Icons.reviews_outlined,
                  color: AdminColors.primary, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                'Rating summary — published reviews',
                style:
                    AdminTypography.titleSm.copyWith(color: AdminColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    s.total == 0 ? '—' : s.average.toStringAsFixed(1),
                    style: AdminTypography.statValue.copyWith(
                      color: AdminColors.primary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < s.average.round() ? Icons.star : Icons.star_border,
                        color: AdminColors.primary,
                        size: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${s.total} published',
                    style: AdminTypography.bodySm.copyWith(
                      color: AdminColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AdminSpacing.lg),
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((stars) {
                    final count = s.distribution[stars] ?? 0;
                    final ratio = s.total > 0 ? count / s.total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '$stars★',
                            style: AdminTypography.labelSm.copyWith(
                              color: AdminColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AdminSpacing.sm),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: AdminRadius.full,
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 5,
                                backgroundColor:
                                    AdminColors.surfaceContainerHigh,
                                valueColor: const AlwaysStoppedAnimation(
                                    AdminColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: AdminSpacing.sm),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: AdminTypography.labelSm.copyWith(
                                color: AdminColors.onSurfaceMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(AdminReview r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AdminRadius.xl,
          onTap: () async {
            await context.push('/admin/reviews/${r.id}');
            _load(reset: true);
          },
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < r.rating ? Icons.star : Icons.star_border,
                          color: AdminColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _statusBadge(r.status),
                  ],
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  r.text,
                  style: AdminTypography.bodySm
                      .copyWith(color: AdminColors.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  '${r.userName ?? r.userEmail ?? 'Unknown user'}'
                  '${r.userPublicId != null ? ' (${r.userPublicId})' : ''}'
                  '${r.orgName != null ? ' • ${r.orgName}' : ''}',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.publicId} • ${_fmt(r.createdAt)}',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'PUBLISHED' => AdminColors.success,
      'PENDING' => AdminColors.warning,
      'FLAGGED' => AdminColors.danger,
      _ => AdminColors.neutral,
    };
    return AdminBadge(label: status, color: color);
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
