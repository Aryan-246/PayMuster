import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/subscription_state_api.dart';

final _subscriptionStateProvider =
    FutureProvider<SubscriptionState>((ref) {
  return ref.watch(subscriptionStateApiProvider).getState();
});

class SubscriptionStateScreen extends ConsumerWidget {
  const SubscriptionStateScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(_subscriptionStateProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final state = ref.watch(_subscriptionStateProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Subscription',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh subscription state',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: state.when(
            loading: () => const PMListSkeleton(itemCount: 3),
            error: (error, _) => _StateErrorState(
              message: error is TenantApiException
                  ? error.message
                  : 'Subscription state could not be loaded.',
              onRetry: () => _refresh(ref),
            ),
            data: (state) => RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.all(PMSpacing.s5),
                children: [
                  if (state.enforcementEnabled != null)
                    _EnforcementBanner(enforcementEnabled: state.enforcementEnabled!),
                  const SizedBox(height: PMSpacing.s4),
                  _SubscriptionCard(subscription: state.subscription),
                  const SizedBox(height: PMSpacing.s4),
                  _AccessCard(access: state.effectiveAccess),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnforcementBanner extends StatelessWidget {
  const _EnforcementBanner({required this.enforcementEnabled});

  final bool enforcementEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent = enforcementEnabled
        ? (isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight)
        : (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight);

    return PMCard.stat(
      accentColor: accent,
      child: Row(
        children: [
          Icon(
            enforcementEnabled
                ? Icons.enhanced_encryption_outlined
                : Icons.lock_open_outlined,
            color: accent,
          ),
          const SizedBox(width: PMSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enforcementEnabled
                      ? 'Enforcement is ON'
                      : 'Enforcement is paused',
                  style: PMTypography.headline.copyWith(color: textColor),
                ),
                Text(
                  enforcementEnabled
                      ? 'Plan limits are enforced normally.'
                      : 'Subscription enforcement is paused platform-wide — '
                          'full access for everyone. Billing state is unchanged.',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final SubscriptionInfo? subscription;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    if (subscription == null) {
      return PMCard.standard(
        child: Column(
          children: [
            Icon(Icons.subscriptions_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s3),
            Text(
              'No subscription yet',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'This organization is on the free plan. Plan limits apply when enforcement is on.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    final sub = subscription!;
    final active = const ['TRIALING', 'ACTIVE', 'PAST_DUE'].contains(sub.status);
    final statusColor = active
        ? (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight)
        : (isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight);

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sub.plan.name,
                  style: PMTypography.headline.copyWith(color: textColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PMSpacing.s3,
                  vertical: PMSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: PMRadius.sm,
                ),
                child: Text(
                  sub.status,
                  style: PMTypography.caption.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: PMSpacing.s3),
          _DetailRow(
            label: 'Plan code',
            value: '${sub.plan.code} · ${sub.plan.interval}',
          ),
          _DetailRow(
            label: 'Current period',
            value:
                '${_formatDate(sub.currentPeriodStart)} – ${_formatDate(sub.currentPeriodEnd)}',
          ),
          if (sub.trialEndsAt != null)
            _DetailRow(
              label: 'Trial ends',
              value: _formatDate(sub.trialEndsAt!),
            ),
          _DetailRow(
            label: 'Renewal',
            value: sub.cancelAtPeriodEnd
                ? 'Cancels at period end'
                : 'Renews automatically',
          ),
          if (sub.unlimitedAccess)
            _DetailRow(
              label: 'Access',
              value: 'Unlimited (admin grant)',
            ),
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.access});

  final SubscriptionEffectiveAccess access;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Effective access',
            style: PMTypography.headline.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s3),
          _DetailRow(
            label: 'Mail supply',
            value: access.unlimited
                ? 'Unlimited'
                : 'Limit ${access.limit} / month',
          ),
          _DetailRow(label: 'Allowed', value: access.allowed ? 'Yes' : 'No'),
          _DetailRow(label: 'Source', value: access.source),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PMSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: PMTypography.caption.copyWith(color: secondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PMTypography.body.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateErrorState extends StatelessWidget {
  const _StateErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: PMColors.statusDangerLight,
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s4),
            PMButton.secondary(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
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
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
