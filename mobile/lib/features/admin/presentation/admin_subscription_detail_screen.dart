import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Subscription detail (§4): plan, lifecycle state, unlimited grant/revoke with
/// confirmation, offers, mail usage, invoices, payment events and history —
/// all real rows; every mutation audits + notifies owners + refreshes.
class AdminSubscriptionDetailScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionDetailScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<AdminSubscriptionDetailScreen> createState() =>
      _AdminSubscriptionDetailScreenState();
}

class _AdminSubscriptionDetailScreenState
    extends ConsumerState<AdminSubscriptionDetailScreen> {
  AdminSubscriptionDetail? _detail;
  bool _isLoading = true;
  String? _error;
  bool _actionInProgress = false;
  int _loadGeneration = 0;

  String get _orgId => widget.orgId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() => _isLoading = _detail == null);

    try {
      final detail = await ref
          .read(adminApiClientProvider)
          .getSubscriptionDetail(_orgId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runAction(String confirmTitle, String confirmBody,
      Future<void> Function() action, String successMessage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surfaceContainerHigh,
        title: Text(confirmTitle,
            style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface)),
        content: Text(confirmBody,
            style: AdminTypography.bodyMd
                .copyWith(color: AdminColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: AdminColors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminColors.errorContainer,
          content: Text(
            'Action failed: $e',
            style: AdminTypography.bodySm.copyWith(color: AdminColors.onErrorContainer),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _grantUnlimited() => _runAction(
        'Grant unlimited access?',
        _detail?.noSubscription == true
            ? 'This organization has no subscription record. A subscription on '
                'the cheapest active plan will be provisioned first, then '
                'unlimited access is granted on top of it — bypassing ALL plan '
                'limits immediately. The owners will be notified and every '
                'change is audited.'
            : 'This company will bypass ALL plan limits immediately — mail, payroll, '
                'every entitlement — with no billing change. Billing history is '
                'preserved. The owners will be notified.',
        () => ref.read(adminApiClientProvider).grantUnlimited(_orgId),
        'Unlimited access granted. Owners notified and audit recorded.',
      );

  Future<void> _revokeUnlimited() => _runAction(
        'Revoke unlimited access?',
        'The company returns to its plan limits immediately. Existing billing '
        'history is preserved and the owners will be notified.',
        () => ref.read(adminApiClientProvider).revokeUnlimited(_orgId),
        'Unlimited access revoked. Owners notified and audit recorded.',
      );

  Future<void> _grantOffer() async {
    final keyController = TextEditingController();
    String valueChoice = 'unlimited';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AdminColors.surfaceContainerHigh,
          title: Text('Grant an offer',
              style: AdminTypography.titleMd
                  .copyWith(color: AdminColors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Offer key (e.g. offer:diwali-2026)',
                  hintText: 'offer:diwali-2026',
                ),
              ),
              const SizedBox(height: AdminSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: valueChoice,
                items: const [
                  DropdownMenuItem(value: 'unlimited', child: Text('Unlimited access')),
                  DropdownMenuItem(value: '10', child: Text('Limit: 10 / month')),
                  DropdownMenuItem(value: '50', child: Text('Limit: 50 / month')),
                  DropdownMenuItem(value: '100', child: Text('Limit: 100 / month')),
                ],
                onChanged: (v) => setDialogState(() => valueChoice = v ?? 'unlimited'),
                decoration: const InputDecoration(labelText: 'Value'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'key': keyController.text.trim(),
                  'value': valueChoice,
                });
              },
              child: const Text('Grant'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final key = result['key'] as String;
    if (key.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An offer key is required.')),
      );
      return;
    }

    await _runAction(
      'Grant offer "$key"?',
      'This offer takes effect immediately for the whole company and expires '
      'only when revoked. The owners will be notified and the grant is audited.',
      () async {
        final value = result['value'] as String;
        await ref.read(adminApiClientProvider).grantOffer(
              _orgId,
              key: key,
              value: value == 'unlimited' ? 'unlimited' : int.tryParse(value) ?? 10,
            );
      },
      'Offer granted. Owners notified and audit recorded.',
    );
  }

  Future<void> _revokeOffer(String key) => _runAction(
        'Revoke offer "$key"?',
        'The company loses this offer immediately and returns to its plan '
        'limits. The owners will be notified.',
        () => ref.read(adminApiClientProvider).revokeOffer(_orgId, key),
        'Offer revoked. Owners notified and audit recorded.',
      );

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
                    _buildHeader(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildUnlimitedCard(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildOffersCard(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildMailUsageCard(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildHistoryCard(),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Subscription'),
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

  Widget _buildHeader() {
    final d = _detail!;
    final sub = d.subscription;
    final org = d.org ?? const {};
    final plan = sub['plan'] as Map<String, dynamic>? ?? const {};
    final status = d.noSubscription
        ? 'NO_SUBSCRIPTION'
        : (sub['status'] as String? ?? '').toUpperCase();
    final trialEnds = sub['trialEndsAt'] as String?;
    final periodEnd = sub['currentPeriodEnd'] as String?;
    final unlimited = sub['unlimitedAccess'] as bool? ?? false;
    final amountMinor = plan['amountMinor']?.toString() ?? '0';
    final amount = (int.tryParse(amountMinor) ?? 0) / 100;

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
              Expanded(
                child: Text(
                  org['name'] as String? ?? 'Company',
                  style: AdminTypography.headlineSm
                      .copyWith(color: AdminColors.onSurface),
                ),
              ),
              AdminBadge.status(status),
            ],
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            '${org['publicId'] as String? ?? '—'} • Owner: ${d.owners.isNotEmpty ? '${d.owners.first['firstName'] as String? ?? ''} ${d.owners.first['lastName'] as String? ?? ''}' : 'none'}'
            '${d.ownerRequestId != null ? ' • ${d.ownerRequestId}' : ''}',
            style: AdminTypography.bodySm
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
          const SizedBox(height: AdminSpacing.md),
          if (d.noSubscription) ...[
            Text(
              'This organization has no subscription record yet — it has not '
              'started a trial or paid plan. Granting unlimited access below '
              'provisions a subscription on the cheapest active plan first, so '
              'access can still be managed here.',
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            ),
            const SizedBox(height: AdminSpacing.md),
          ],
          _infoRow(
            'Plan',
            d.noSubscription
                ? 'No active plan'
                : '${plan['name'] ?? 'Unknown'} (${plan['code'] ?? '—'})',
          ),
          if (!d.noSubscription) ...[
            _infoRow('Price', '₹$amount ${plan['currency'] ?? 'INR'} / ${plan['interval'] ?? 'MONTH'}'),
            _infoRow(
              'Trial',
              trialEnds != null ? 'Ends ${_fmt(trialEnds)}' : 'No trial',
            ),
            _infoRow(
              'Current period ends',
              periodEnd != null ? _fmt(periodEnd) : '—',
            ),
            _infoRow(
              'Cancellation',
              (sub['cancelAtPeriodEnd'] as bool? ?? false)
                  ? 'Cancels at period end'
                  : 'Renews automatically',
            ),
          ],
          _infoRow('Access', unlimited ? 'UNLIMITED (granted)' : 'Plan limits'),
        ],
      ),
    );
  }

  Widget _buildUnlimitedCard() {
    final unlimited =
        (_detail!.subscription['unlimitedAccess'] as bool? ?? false);
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: unlimited
            ? AdminColors.info.withValues(alpha: 0.08)
            : AdminColors.surfaceContainer,
        borderRadius: AdminRadius.xl,
        border: Border.all(
          color: unlimited
              ? AdminColors.info.withValues(alpha: 0.35)
              : AdminColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.all_inclusive,
                  color: AdminColors.info, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                'Unlimited access',
                style:
                    AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
              ),
              const Spacer(),
              AdminBadge(
                label: unlimited ? 'GRANTED' : 'STANDARD',
                color: unlimited ? AdminColors.info : AdminColors.neutral,
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            unlimited
                ? 'This company bypasses all plan limits. Grant/revocation is '
                    'audited, owners are notified, and billing history is never altered.'
                : _detail?.noSubscription == true
                    ? 'Granting unlimited access provisions a subscription on the '
                        'cheapest active plan first, then bypasses all plan limits. '
                        'Billing history is preserved.'
                    : 'Granting unlimited access bypasses all plan limits for this '
                        'company. Billing history is preserved.',
            style: AdminTypography.bodySm
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _actionInProgress ? null : _grantUnlimited,
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: const Text('Grant Unlimited'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.info,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_actionInProgress || !unlimited) ? null : _revokeUnlimited,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Revoke'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersCard() {
    final entitlements = (_detail!.subscription['entitlements']
            as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final offers = entitlements
        .where((e) => (e['source'] as String? ?? '') == 'OFFER')
        .toList();

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
              const Icon(Icons.local_offer_outlined,
                  color: AdminColors.tertiary, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: Text(
                  'Offers & free access',
                  style:
                      AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
                ),
              ),
              TextButton.icon(
                onPressed: _actionInProgress ? null : _grantOffer,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Grant'),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          if (offers.isEmpty)
            Text(
              'No active offers. Grants appear here with their value, expiry and revocation control.',
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            )
          else
            ...offers.map(
              (offer) => Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer['key'] as String? ?? '—',
                            style: AdminTypography.titleSm
                                .copyWith(color: AdminColors.onSurface),
                          ),
                          Text(
                            'Value: ${offer['value']}${offer['expiresAt'] != null ? ' • expires ${_fmt(offer['expiresAt'] as String)}' : ' • no expiry'}',
                            style: AdminTypography.bodySm
                                .copyWith(color: AdminColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _actionInProgress ? null : () => _revokeOffer(
                                offer['key'] as String? ?? '',
                              ),
                      child: const Text('Revoke'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMailUsageCard() {
    final d = _detail!;
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
              const Icon(Icons.mail_outline, color: AdminColors.secondary, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                'Mail usage this month',
                style:
                    AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            '${d.mailSentThisMonth} emails sent${d.mailPeriodEnd != null ? ' • resets ${_fmt(d.mailPeriodEnd!)}' : ''}',
            style: AdminTypography.bodyMd
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final d = _detail!;
    final history = d.history;
    final invoices =
        (d.subscription['invoices'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final paymentEvents = (d.subscription['paymentEvents'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

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
          const AdminSectionHeader(title: 'Lifecycle history'),
          const SizedBox(height: AdminSpacing.sm),
          if (history.isEmpty)
            Text(
              'No subscription changes recorded yet.',
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            )
          else
            ...history.map(
              (h) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  (h['status'] as String? ?? '') == 'EXPIRED'
                      ? Icons.event_busy_outlined
                      : (h['status'] as String? ?? '') == 'ACTIVE'
                          ? Icons.check_circle_outline
                          : Icons.timeline_outlined,
                  size: 18,
                  color: AdminColors.primary,
                ),
                title: Text(
                  '${h['status']} • ${h['unlimitedAccess'] == true ? 'unlimited' : 'plan limits'}',
                  style: AdminTypography.titleSm.copyWith(color: AdminColors.onSurface),
                ),
                subtitle: Text(
                  _fmt(h['createdAt']?.toString() ?? ''),
                  style: AdminTypography.bodySm
                      .copyWith(color: AdminColors.onSurfaceMuted),
                ),
              ),
            ),
          if (invoices.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            const AdminSectionHeader(title: 'Invoices'),
            const SizedBox(height: AdminSpacing.sm),
            ...invoices.map(
              (inv) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_outlined,
                    size: 18, color: AdminColors.secondary),
                title: Text(
                  '${inv['invoiceNumber']} • ${(inv['status'] as String? ?? '')}',
                  style: AdminTypography.titleSm.copyWith(color: AdminColors.onSurface),
                ),
                subtitle: Text(
                  '₹${((int.tryParse(inv['totalMinor']?.toString() ?? '0') ?? 0) / 100).toStringAsFixed(2)}',
                  style: AdminTypography.bodySm
                      .copyWith(color: AdminColors.onSurfaceVariant),
                ),
              ),
            ),
          ],
          if (paymentEvents.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            const AdminSectionHeader(title: 'Payment events'),
            const SizedBox(height: AdminSpacing.sm),
            ...paymentEvents.map(
              (ev) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  (ev['eventType'] as String? ?? '').contains('failed')
                      ? Icons.error_outline
                      : Icons.payment_outlined,
                  size: 18,
                  color: (ev['eventType'] as String? ?? '').contains('failed')
                      ? AdminColors.danger
                      : AdminColors.success,
                ),
                title: Text(
                  '${ev['eventType']} • ${ev['status']}',
                  style: AdminTypography.titleSm.copyWith(color: AdminColors.onSurface),
                ),
                subtitle: Text(
                  _fmt(ev['createdAt']?.toString() ?? ''),
                  style: AdminTypography.bodySm
                      .copyWith(color: AdminColors.onSurfaceMuted),
                ),
                onTap: () => context.go(
                    '/admin/payments'), // platform payment list has the full record
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  AdminTypography.bodySm.copyWith(color: AdminColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
