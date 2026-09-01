import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Mail Supply admin (§5 / directive #3): platform quota overview + dispatch
/// history + entry into the composer. All numbers are real MailDispatch /
/// UsageRecord rows; nothing is estimated.
class AdminMailSupplyScreen extends ConsumerStatefulWidget {
  const AdminMailSupplyScreen({super.key});

  @override
  ConsumerState<AdminMailSupplyScreen> createState() =>
      _AdminMailSupplyScreenState();
}

class _AdminMailSupplyScreenState extends ConsumerState<AdminMailSupplyScreen> {
  AdminMailOverview? _overview;
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
      final overview = await ref.read(adminApiClientProvider).getMailOverview();
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
                    _buildSummary(),
                    const SizedBox(height: AdminSpacing.md),
                    const AdminSectionHeader(title: 'Dispatch history'),
                    const SizedBox(height: AdminSpacing.sm),
                    if (_overview!.dispatches.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.mark_email_unread_outlined,
                        title: 'No emails sent yet',
                        message:
                            'Platform and company email campaigns appear here with '
                            'their delivery results.',
                      )
                    else
                      ..._overview!.dispatches.map(_buildDispatchCard),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Mail Supply'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/mail/compose');
          _load();
        },
        backgroundColor: AdminColors.primary,
        foregroundColor: AdminColors.onPrimary,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Compose'),
      ),
      body: body,
    );
  }

  Widget _buildSummary() {
    final o = _overview!;
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
              const Icon(Icons.email_outlined,
                  color: AdminColors.secondary, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                'Platform mail overview',
                style:
                    AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              Expanded(
                child: _stat('Dispatches', o.totalDispatches.toString(),
                    AdminColors.primary),
              ),
              Expanded(
                child: _stat('Delivered', o.totalSent.toString(),
                    AdminColors.success),
              ),
              Expanded(
                child: _stat('Failed', o.totalFailed.toString(),
                    o.totalFailed > 0 ? AdminColors.danger : AdminColors.neutral),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _stat('This month', o.mailSentThisMonth.toString(),
                    AdminColors.info),
              ),
              Expanded(
                child: _stat('Orgs mailing', '${o.orgsUsingMail}/${o.orgCount}',
                    AdminColors.secondary),
              ),
              Expanded(
                child: _stat('Free limit', '${o.freePlanMonthlyLimit}/mo',
                    AdminColors.tertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AdminTypography.titleMd.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

  Widget _buildDispatchCard(AdminMailDispatch d) {
    final statusColor = d.status == 'SENT'
        ? AdminColors.success
        : d.status == 'PARTIAL'
            ? AdminColors.warning
            : d.status == 'FAILED'
                ? AdminColors.danger
                : AdminColors.neutral;
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
                Expanded(
                  child: Text(
                    d.subject,
                    style: AdminTypography.titleSm.copyWith(
                      color: AdminColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AdminBadge(label: d.status, color: statusColor),
              ],
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              '${d.targetType} • ${d.sent}/${d.recipientCount} delivered'
              '${d.failed > 0 ? ' • ${d.failed} failed' : ''}'
              '${d.orgName != null ? ' • ${d.orgName}' : ' • Platform'}',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _fmt(d.createdAt),
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
