import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/admin_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  AdminDashboardMetrics? _metrics;
  bool _isLoading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final metrics = await ref
          .read(adminApiClientProvider)
          .getDashboardMetrics();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _metrics = metrics;
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
    final textColor = AdminColors.onSurface;
    final bgColor = AdminColors.background;
    final surfaceColor = AdminColors.surface;
    final authState = ref.watch(authControllerProvider);

    final user = authState.user;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Super Admin Control Center',
              style: AdminTypography.titleMd.copyWith(
                color: textColor,
                fontSize: 18,
              ),
            ),
            Text(
              user?.email ?? 'Platform Administrator',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.primary,
              ),
            ),
          ],
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: _loadMetrics,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.go('/admin/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMetrics,
        child: _isLoading
            ? const AdminLoadingState()
            : _error != null
            ? AdminErrorState(error: _error!, onRetry: _loadMetrics)
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AdminSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildExecutiveHeader(textColor),
                    const SizedBox(height: AdminSpacing.lg),
                    _buildMetricsGrid(context, _metrics!),
                    const SizedBox(height: AdminSpacing.lg),
                    _buildQuickActionsRow(context),
                    const SizedBox(height: AdminSpacing.lg),
                    _buildRecentActivity(
                      context,
                      _metrics!.recentAuditLogs,
                      textColor,
                      surfaceColor,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildExecutiveHeader(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.primary.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(color: AdminColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AdminSpacing.compact),
            decoration: const BoxDecoration(
              color: AdminColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: AdminColors.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PayMuster System Master Engine',
                  style: AdminTypography.headlineSm.copyWith(color: textColor),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AdminColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Live platform metrics loaded from the admin API',
                        style: AdminTypography.bodySm.copyWith(
                          color: AdminColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, AdminDashboardMetrics m) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        final availableCardWidth =
            constraints.maxWidth - (AdminSpacing.sm * (crossAxisCount - 1));
        final cardWidth = availableCardWidth / crossAxisCount;
        final proportionalHeight = cardWidth / 1.45;
        final cardHeight = proportionalHeight < 152
            ? 152.0
            : proportionalHeight;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AdminSpacing.sm,
          mainAxisSpacing: AdminSpacing.sm,
          childAspectRatio: cardWidth / cardHeight,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            AdminStatCard(
              title: 'Total Users',
              value: m.users.toString(),
              icon: Icons.people_outline,
              color: AdminColors.info,
              onTap: () => context.go('/admin/users'),
            ),
            AdminStatCard(
              title: 'Owners',
              value: m.owners.toString(),
              icon: Icons.verified_user_outlined,
              color: AdminColors.primary,
              onTap: () => context.go('/admin/users?role=OWNER'),
            ),
            AdminStatCard(
              title: 'Companies',
              value: m.companies.toString(),
              icon: Icons.business_outlined,
              color: AdminColors.secondary,
              onTap: () => context.go('/admin/companies'),
            ),
            AdminStatCard(
              title: 'Sites',
              value: m.sites.toString(),
              icon: Icons.location_city_outlined,
              color: AdminColors.primary,
              onTap: () => context.go('/admin/sites'),
            ),
            AdminStatCard(
              title: 'Attendance',
              value: m.attendance.toString(),
              icon: Icons.fact_check_outlined,
              color: AdminColors.success,
              onTap: () => context.go('/admin/attendance'),
            ),
            AdminStatCard(
              title: 'Pay Runs',
              value: m.payroll.toString(),
              icon: Icons.account_balance_wallet_outlined,
              color: AdminColors.warning,
              onTap: () => context.go('/admin/payroll'),
            ),
            AdminStatCard(
              title: 'Pending Requests',
              value: m.pendingRequests.toString(),
              icon: Icons.hourglass_top_outlined,
              color: m.pendingRequests > 0
                  ? AdminColors.warning
                  : AdminColors.neutral,
              onTap: () => context.go('/admin/owner-requests'),
            ),
            AdminStatCard(
              title: 'Blocked Users',
              value: m.blockedUsers.toString(),
              icon: Icons.block_outlined,
              color: m.blockedUsers > 0
                  ? AdminColors.danger
                  : AdminColors.neutral,
              onTap: () => context.go('/admin/users?status=BLOCKED'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(title: 'Administrative Commands'),
        const SizedBox(height: AdminSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.person_search,
                label: 'Search Users',
                color: AdminColors.info,
                onTap: () => context.go('/admin/users'),
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.how_to_reg,
                label: 'Owner Requests',
                color: AdminColors.primary,
                onTap: () => context.go('/admin/owner-requests'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.domain,
                label: 'Companies',
                color: AdminColors.secondary,
                onTap: () => context.go('/admin/companies'),
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.receipt_long,
                label: 'Audit Logs',
                color: AdminColors.info,
                onTap: () => context.go('/admin/audit-logs'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final surfaceColor = AdminColors.surfaceContainer;
    final borderCol = AdminColors.glassBorder;
    final textColor = AdminColors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdminRadius.md,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.md,
            vertical: AdminSpacing.compact,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: AdminRadius.md,
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AdminTypography.titleSm.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: textColor.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    List<AdminAuditLog> logs,
    Color textColor,
    Color surfaceColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeader(
          title: 'System Audit Stream',
          actionLabel: 'View All',
          onAction: () => context.go('/admin/audit-logs'),
        ),
        const SizedBox(height: AdminSpacing.sm),
        if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: AdminRadius.xl,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: Center(
              child: Text(
                'No recent audit activity',
                style: AdminTypography.bodyMd.copyWith(
                  color: AdminColors.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: AdminRadius.xl,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AdminColors.glassBorder),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      log.action == 'APPROVE'
                          ? Icons.check_circle_outline
                          : log.action == 'DELETE'
                          ? Icons.delete_outline
                          : log.action == 'CREATE'
                          ? Icons.add_circle_outline
                          : Icons.info_outline,
                      size: 16,
                      color: AdminColors.primary,
                    ),
                  ),
                  title: Text(
                    '${log.action} • ${log.entityType}',
                    style: AdminTypography.titleSm.copyWith(color: textColor),
                  ),
                  subtitle: Text(
                    '${log.userName ?? log.userEmail ?? 'System'} ${log.companyName != null ? '(${log.companyName})' : ''}',
                    style: AdminTypography.bodySm.copyWith(
                      color: AdminColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    log.createdAt.length >= 10
                        ? log.createdAt.substring(0, 10)
                        : log.createdAt,
                    style: AdminTypography.bodySm.copyWith(
                      color: AdminColors.onSurfaceMuted,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
