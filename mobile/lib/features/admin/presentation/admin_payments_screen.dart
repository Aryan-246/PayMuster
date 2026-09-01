import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Platform billing/payments (§4/§ latest directive #2): every PaymentEvent
/// across companies — status, org/plan association, provider reference,
/// failure reasons. Honest empty state when no payments exist.
class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() =>
      _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  static const _statusFilters = ['ALL', 'RECEIVED', 'PROCESSED', 'IGNORED', 'FAILED'];

  final _searchController = TextEditingController();
  List<AdminPaymentEvent> _payments = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String _status = 'ALL';
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
        _payments = [];
      }
    });

    try {
      final result = await ref.read(adminApiClientProvider).getPayments(
            search: _search.isNotEmpty ? _search : null,
            status: _status,
            page: reset ? 1 : _page,
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final rows = result['payments'] as List<AdminPaymentEvent>;
        _payments = reset ? rows : [..._payments, ...rows];
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
    final body = _isLoading && _payments.isEmpty
        ? const AdminLoadingState()
        : _error != null && _payments.isEmpty
            ? AdminErrorState(error: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AdminSpacing.md),
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        _search = value.trim();
                        _load(reset: true);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search event, company or reference…',
                        prefixIcon: const Icon(Icons.search),
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
                        children: _statusFilters
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(right: AdminSpacing.sm),
                                child: ChoiceChip(
                                  label: Text(s == 'ALL' ? 'All' : s),
                                  selected: _status == s,
                                  onSelected: (selected) {
                                    if (!selected) return;
                                    setState(() => _status = s);
                                    _load(reset: true);
                                  },
                                  selectedColor:
                                      AdminColors.primary.withValues(alpha: 0.25),
                                  backgroundColor: AdminColors.surfaceContainer,
                                  labelStyle: AdminTypography.labelSm.copyWith(
                                    color: _status == s
                                        ? AdminColors.primary
                                        : AdminColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    if (_payments.isEmpty && !_isLoading)
                      const AdminEmptyState(
                        icon: Icons.payment_outlined,
                        title: 'No payment events',
                        message:
                            'Payments appear here once Razorpay webhooks and '
                            'checkout events are recorded. Nothing is fabricated.',
                      )
                    else
                      ..._payments.map(_buildPaymentCard),
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
                    if (_error != null && _payments.isNotEmpty)
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
        title: const Text('Billing & Payments'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildPaymentCard(AdminPaymentEvent p) {
    final isFailure = p.eventType.toLowerCase().contains('failed') ||
        p.status == 'FAILED' ||
        p.failureReason != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
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
                Icon(
                  isFailure ? Icons.error_outline : Icons.check_circle_outline,
                  size: 18,
                  color: isFailure ? AdminColors.danger : AdminColors.success,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    p.eventType.isEmpty ? 'Payment event' : p.eventType,
                    style: AdminTypography.titleMd.copyWith(
                      color: AdminColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AdminBadge.status(p.status),
              ],
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              '${p.orgName ?? 'No company'}${p.orgPublicId != null ? ' • ${p.orgPublicId}' : ''}',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            if (p.planCode != null || p.subscriptionStatus != null)
              const SizedBox(height: 2),
            if (p.planCode != null || p.subscriptionStatus != null)
              Text(
                'Subscription: ${p.subscriptionStatus ?? '—'}${p.planCode != null ? ' • ${p.planCode}' : ''}',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              'Ref: ${p.providerEventId.isEmpty ? '—' : p.providerEventId} • Provider: ${p.provider} • ${_fmt(p.createdAt)}',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceMuted,
              ),
            ),
            if (p.failureReason != null) ...[
              const SizedBox(height: AdminSpacing.xs),
              Text(
                'Failure: ${p.failureReason}',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
