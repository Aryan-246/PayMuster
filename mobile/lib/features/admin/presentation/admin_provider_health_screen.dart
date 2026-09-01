import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_api_client.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Provider Health (§ latest directive #7): live status of every integrated
/// provider — auth, AI, email, payments, push — as reported by the backend
/// registry. Degraded / misconfigured states are shown honestly; nothing is
/// assumed "ready" without server confirmation.
class AdminProviderHealthScreen extends ConsumerStatefulWidget {
  const AdminProviderHealthScreen({super.key});

  @override
  ConsumerState<AdminProviderHealthScreen> createState() =>
      _AdminProviderHealthScreenState();
}

class _AdminProviderHealthScreenState
    extends ConsumerState<AdminProviderHealthScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _freeOnly = false;
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
      _isLoading = _providers.isEmpty;
      _error = null;
    });

    try {
      final result = await ref.read(adminApiClientProvider).getProviderHealth();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _providers = result['providers'] as List<Map<String, dynamic>>;
        _freeOnly = result['freeOnly'] == true;
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
                    if (_freeOnly)
                      Container(
                        margin:
                            const EdgeInsets.only(bottom: AdminSpacing.md),
                        padding: const EdgeInsets.all(AdminSpacing.compact),
                        decoration: BoxDecoration(
                          color: AdminColors.info.withValues(alpha: 0.08),
                          borderRadius: AdminRadius.md,
                          border: Border.all(
                            color: AdminColors.info.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AdminColors.info, size: 18),
                            const SizedBox(width: AdminSpacing.sm),
                            Expanded(
                              child: Text(
                                'This deployment runs the free-provider tier. '
                                'Paid providers are intentionally disabled.',
                                style: AdminTypography.bodySm
                                    .copyWith(color: AdminColors.info),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const AdminSectionHeader(
                        title: 'Integrated providers'),
                    const SizedBox(height: AdminSpacing.sm),
                    if (_providers.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.dns_outlined,
                        title: 'No providers registered',
                        message:
                            'The provider registry returned no providers. '
                            'Check server configuration.',
                      )
                    else
                      ..._providers.map(_buildProviderCard),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Provider Health'),
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

  Widget _buildProviderCard(Map<String, dynamic> p) {
    final name = (p['provider'] as String?) ?? 'Unknown';
    final kind = (p['kind'] as String?) ?? '—';
    final status = (p['status'] as String?) ?? 'UNKNOWN';
    final enabled = p['enabled'] == true;
    final fallback = p['fallback'] as String?;
    final readiness = p['readiness'] as String?;
    final checkedAt = p['checkedAt'] as String?;
    final detail = p['detail'] as String?;

    // Status model (fixed at the backend source):
    //  CONNECTED           — live-verified (a real request succeeded)
    //  ENABLED             — configured and ready; live use verified per operation
    //  UNAVAILABLE         — a real operation failed
    //  INVALID_CONFIGURATION / NOT_CONFIGURED — enabled but config incomplete
    //  ENVIRONMENT_BLOCKED — intentionally blocked pending approval/policy
    //  DISABLED            — intentionally off (with fallback)
    final (color, icon) = switch (status) {
      'CONNECTED' => (AdminColors.success, Icons.check_circle_outline),
      'ENABLED' => (AdminColors.success, Icons.verified_outlined),
      'INVALID_CONFIGURATION' => (AdminColors.danger, Icons.error_outline),
      'NOT_CONFIGURED' => (AdminColors.danger, Icons.error_outline),
      'ENVIRONMENT_BLOCKED' => (AdminColors.warning, Icons.lock_outline),
      'RATE_LIMITED' => (AdminColors.warning, Icons.hourglass_bottom),
      'UNAVAILABLE' => (AdminColors.warning, Icons.warning_amber_outlined),
      'DISABLED' => (AdminColors.neutral, Icons.pause_circle_outline),
      _ => (AdminColors.neutral, Icons.help_outline),
    };

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
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: AdminTypography.titleMd
                        .copyWith(color: AdminColors.onSurface),
                  ),
                ),
                AdminBadge(label: status, color: color),
              ],
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              kind +
                  (enabled ? ' • enabled' : ' • disabled') +
                  (readiness != null && readiness.isNotEmpty
                      ? ' • readiness: $readiness'
                      : ''),
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            if (fallback != null && fallback.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Fallback: $fallback',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceVariant,
                ),
              ),
            ],
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: AdminSpacing.xs),
              Text(
                detail,
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceMuted,
                ),
              ),
            ],
            if (checkedAt != null && checkedAt.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Checked ${_fmt(checkedAt)}',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceMuted,
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
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
