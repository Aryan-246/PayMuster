import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/paymuster_tokens.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/data/notification_api.dart';
import '../data/company_provider.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  CompanyOverview? _overview;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadOverview);
  }

  Future<void> _loadOverview() async {
    final user = ref.read(authControllerProvider).user;
    final organizationId = user?.organizationId;
    if (user?.role != UserRole.owner || organizationId == null) {
      if (!mounted) return;
      setState(() {
        _overview = null;
        _error = 'Your account does not have an active Owner company context.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final overview = await ref
          .read(companyProvider)
          .getOverview(organizationId);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _overview = null;
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark
        ? PMColors.bgSurfaceDark
        : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Owner Dashboard',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          const _NotificationBell(),
          IconButton(
            tooltip: 'Refresh company overview',
            onPressed: _isLoading ? null : _loadOverview,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context, isDark, textColor, surfaceColor),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color surfaceColor,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PMSpacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business_outlined,
                size: 48,
                color: textColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: PMSpacing.s4),
              Text(
                'Company overview unavailable',
                style: PMTypography.headline.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                _error!,
                style: PMTypography.body.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s6),
              ElevatedButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final overview = _overview;
    if (overview == null) {
      return Center(
        child: Text(
          'No company overview is available.',
          style: PMTypography.body.copyWith(color: textColor),
        ),
      );
    }

    final companyIdentifier =
        overview.publicId ?? overview.referenceCode ?? overview.id;
    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PMSpacing.s6),
        children: [
          Text(
            overview.name,
            style: PMTypography.title.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s4),
          _buildInfoRow(
            isDark,
            textColor,
            surfaceColor,
            'Company ID',
            companyIdentifier,
            Icons.business,
          ),
          const SizedBox(height: PMSpacing.s3),
          _buildInfoRow(
            isDark,
            textColor,
            surfaceColor,
            'Join Code',
            overview.joinCode ?? 'Not available',
            Icons.qr_code,
          ),
          const SizedBox(height: PMSpacing.s6),
          Text(
            'Company Overview',
            style: PMTypography.title.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - (PMSpacing.s4 * 2)) / 3
                  : (constraints.maxWidth - PMSpacing.s4) / 2;
              return Wrap(
                spacing: PMSpacing.s4,
                runSpacing: PMSpacing.s4,
                children: [
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Users',
                    overview.userCount.toString(),
                    Icons.group_outlined,
                  ),
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Staff',
                    overview.staffCount.toString(),
                    Icons.badge_outlined,
                  ),
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Sites',
                    overview.siteCount.toString(),
                    Icons.location_city_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: PMSpacing.s6),
          Text(
            'Financial History',
            style: PMTypography.title.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s2),
          Text(
            'Expenses include approved and reimbursed records. Pay run totals do not indicate payment or disbursement.',
            style: PMTypography.caption.copyWith(
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: PMSpacing.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - (PMSpacing.s4 * 2)) / 3
                  : (constraints.maxWidth - PMSpacing.s4) / 2;
              final financials = overview.financialSummary;
              return Wrap(
                spacing: PMSpacing.s4,
                runSpacing: PMSpacing.s4,
                children: [
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Site-linked expenses',
                    _formatCurrency(
                      overview.currency,
                      financials.siteLinkedExpenseTotal,
                    ),
                    Icons.location_city_outlined,
                  ),
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Company-level expenses',
                    _formatCurrency(
                      overview.currency,
                      financials.companyLevelExpenseTotal,
                    ),
                    Icons.receipt_long_outlined,
                  ),
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Recorded pay runs',
                    financials.recordedPayRunCount.toString(),
                    Icons.event_note_outlined,
                  ),
                  _buildStatCard(
                    isDark,
                    textColor,
                    surfaceColor,
                    cardWidth,
                    'Recorded payroll total',
                    _formatCurrency(
                      overview.currency,
                      financials.recordedPayRunTotal,
                    ),
                    Icons.payments_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: PMSpacing.s6),
          ElevatedButton.icon(
            onPressed: () => context.go('/app/staff'),
            icon: const Icon(Icons.people_outline),
            label: const Text('Manage Staff'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: PMColors.brandPrimaryLight,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: PMSpacing.s3),
          OutlinedButton.icon(
            onPressed: () => context.go('/app/sites'),
            icon: const Icon(Icons.location_city_outlined),
            label: const Text('Manage Sites'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: PMSpacing.s3),
          OutlinedButton.icon(
            onPressed: () => context.go('/app/mail-supply'),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Mail Supply'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: PMSpacing.s3),
          OutlinedButton.icon(
            onPressed: () => context.go('/app/announcement-dispatch'),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Send Announcement'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: PMSpacing.s3),
          OutlinedButton.icon(
            onPressed: () => context.go('/app/subscription'),
            icon: const Icon(Icons.card_membership_outlined),
            label: const Text('Subscription'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    bool isDark,
    Color textColor,
    Color surfaceColor,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s5),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: PMRadius.md,
        border: Border.all(
          color: isDark
              ? PMColors.borderDefaultDark
              : PMColors.borderDefaultLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: PMColors.brandPrimaryLight, size: 28),
          const SizedBox(width: PMSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: PMTypography.caption.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: PMSpacing.s1),
                SelectableText(
                  value,
                  style: PMTypography.headline.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    bool isDark,
    Color textColor,
    Color surfaceColor,
    double width,
    String label,
    String value,
    IconData icon,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(PMSpacing.s4),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: PMRadius.md,
          border: Border.all(
            color: isDark
                ? PMColors.borderDefaultDark
                : PMColors.borderDefaultLight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: PMColors.brandPrimaryLight, size: 24),
            const SizedBox(height: PMSpacing.s2),
            Text(value, style: PMTypography.title.copyWith(color: textColor)),
            Text(
              label,
              style: PMTypography.caption.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCurrency(String currency, String amount) {
  final numericAmount = num.tryParse(amount) ?? 0;
  return '$currency ${numericAmount.toStringAsFixed(2)}';
}

/// Unread-notification bell (owner.txt dashboard section). Count comes from
/// the notifications API; the bell is hidden while the count is loading so
/// no fake state is ever shown.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: 'Notifications',
      key: const Key('owner-notification-bell'),
      onPressed: () => context.push('/app/notifications'),
      icon: unread.maybeWhen(
        data: (count) => count > 0
            ? _BadgeIcon(count: count)
            : const Icon(Icons.notifications_none_outlined),
        orElse: () => const Icon(Icons.notifications_none_outlined),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(child: Icon(Icons.notifications_none_outlined, size: 24)),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: PMColors.statusDangerLight,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
