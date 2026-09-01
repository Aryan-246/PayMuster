import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Reports & Analytics (§ latest directive #6/§ plan): real 30-day daily
/// series aggregated server-side from actual rows. Static bars — no animated
/// effects over data; every number traces to a table.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  static const _metrics = [
    ('users', 'New users', Icons.person_add_outlined, AdminColors.primary),
    ('companies', 'New companies', Icons.apartment_outlined, AdminColors.secondary),
    ('subscriptions', 'New subscriptions', Icons.card_membership_outlined, AdminColors.tertiary),
    ('payments', 'Payment events', Icons.payments_outlined, AdminColors.success),
    ('mail', 'Mail dispatches', Icons.email_outlined, AdminColors.info),
    ('reviews', 'Reviews submitted', Icons.rate_review_outlined, AdminColors.warning),
    ('attendance', 'Attendance records', Icons.how_to_reg_outlined, AdminColors.neutral),
    ('auditEvents', 'Audit events', Icons.fact_check_outlined, AdminColors.danger),
  ];

  AdminReportsOverview? _overview;
  bool _isLoading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = _overview == null;
      _error = null;
    });

    try {
      final overview =
          await ref.read(adminApiClientProvider).getReportsOverview();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _overview = overview;
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
    final body = _isLoading
        ? const AdminLoadingState()
        : _error != null
            ? AdminErrorState(error: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AdminSpacing.md),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AdminSpacing.compact),
                      decoration: BoxDecoration(
                        color: AdminColors.surfaceContainer,
                        borderRadius: AdminRadius.md,
                        border: Border.all(color: AdminColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insights_outlined,
                              color: AdminColors.primary, size: 18),
                          const SizedBox(width: AdminSpacing.sm),
                          Expanded(
                            child: Text(
                              'Trailing 30 days — every count is aggregated '
                              'from live database rows.',
                              style: AdminTypography.bodySm.copyWith(
                                color: AdminColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    if (_overview != null) ..._metrics.map(_buildMetricCard),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildMetricCard((String, String, IconData, Color) metric) {
    final (key, label, icon, color) = metric;
    final o = _overview!;
    final series = o.series[key] ?? const <String, int>{};
    final total = o.totals[key] ?? series.values.fold<int>(0, (sum, v) => sum + v);
    final values = o.days.map((d) => series[d] ?? 0).toList();
    final peak = values.fold(0, (m, v) => v > m ? v : m);

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
                Icon(icon, color: color, size: 18),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AdminTypography.titleSm
                        .copyWith(color: AdminColors.onSurface),
                  ),
                ),
                Text(
                  '$total',
                  style: AdminTypography.titleMd.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (peak > 0) ...[
              const SizedBox(height: AdminSpacing.sm),
              SizedBox(
                height: 56,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: values
                      .map(
                        (v) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: FractionallySizedBox(
                              heightFactor: v / peak,
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      color.withValues(alpha: v > 0 ? 0.85 : 0.2),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    o.days.isNotEmpty ? o.days.first : '',
                    style: AdminTypography.labelSm.copyWith(
                      color: AdminColors.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    'peak $peak/day',
                    style: AdminTypography.labelSm.copyWith(
                      color: AdminColors.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    o.days.isNotEmpty ? o.days.last : '',
                    style: AdminTypography.labelSm.copyWith(
                      color: AdminColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: AdminSpacing.sm),
                child: Text(
                  'No activity in the last 30 days.',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.onSurfaceMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
