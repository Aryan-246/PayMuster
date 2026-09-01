import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../company/data/company_provider.dart';

/// The non-admin home. Every number rendered here comes from the real
/// GET /api/v1/company overview for the user's organization — no fabricated
/// metrics, weather, or activity timelines. Loading, error+retry, and empty
/// states are all explicit.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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
    if (user == null || organizationId == null) {
      if (!mounted) return;
      setState(() {
        _overview = null;
        _error = null;
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

    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user.organizationId == null) {
      return _buildNoCompanyDashboard(context, isDark, user);
    }

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOverview,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PMSpacing.s4),
            children: [
              _buildHeader(isDark, user),
              const SizedBox(height: PMSpacing.s4),
              _buildOverviewSection(isDark),
              const SizedBox(height: PMSpacing.s4),
              _buildQuickActions(isDark, context),
              const SizedBox(height: PMSpacing.s6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoCompanyDashboard(BuildContext context, bool isDark, User user) {
    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PMSpacing.s6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.business, size: 80, color: PMColors.brandPrimaryLight),
              const SizedBox(height: PMSpacing.s6),
              Text(
                'Welcome, ${user.name ?? 'User'}!',
                style: PMTypography.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                'You are not associated with any company yet.',
                style: PMTypography.body.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s8),
              PMButton.primary(
                label: 'Join a Company',
                onPressed: () => context.push('/app/join-company'),
                icon: Icons.login,
              ),
              const SizedBox(height: PMSpacing.s4),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: PMSpacing.s4),
              // Registering a company is the real owner-request flow
              // (/app/owner-request) — no dead routes.
              PMButton.secondary(
                label: 'Register New Company',
                onPressed: () => context.push('/app/owner-request'),
                icon: Icons.add_business,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, User user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Real company name from the overview, or an honest fallback
                // while it loads — never a fabricated site name.
                _overview?.name ?? 'Your Company',
                style: PMTypography.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_greeting()}, ${user.name?.split(' ').first ?? 'User'}',
                style: PMTypography.body.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(PMSpacing.s2),
          decoration: BoxDecoration(
            color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
          ),
          child: Icon(
            Icons.notifications_none,
            color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewSection(bool isDark) {
    if (_isLoading && _overview == null) {
      return _buildSurface(
        isDark,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(PMSpacing.s8),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildSurface(
        isDark,
        child: Padding(
          padding: const EdgeInsets.all(PMSpacing.s6),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
              ),
              const SizedBox(height: PMSpacing.s3),
              Text(
                'Company overview unavailable',
                style: PMTypography.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                _error!,
                style: PMTypography.body.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s4),
              PMButton.secondary(
                label: 'Retry',
                onPressed: _loadOverview,
                icon: Icons.refresh,
              ),
            ],
          ),
        ),
      );
    }

    final overview = _overview;
    if (overview == null) {
      return _buildSurface(
        isDark,
        child: Padding(
          padding: const EdgeInsets.all(PMSpacing.s6),
          child: Text(
            'No company overview is available yet.',
            style: PMTypography.body.copyWith(
              color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _buildSurface(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PMColors.brandPrimaryLight.withValues(alpha: 0.12),
                    borderRadius: PMRadius.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: PMColors.brandPrimaryLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE DATA',
                        style: PMTypography.caption.copyWith(color: PMColors.brandPrimaryLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PMSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    isDark,
                    overview.staffCount.toString(),
                    'Staff on record',
                  ),
                ),
                const SizedBox(width: PMSpacing.s3),
                Expanded(
                  child: _buildMetric(
                    isDark,
                    overview.userCount.toString(),
                    'Team accounts',
                  ),
                ),
                const SizedBox(width: PMSpacing.s3),
                Expanded(
                  child: _buildMetric(
                    isDark,
                    overview.siteCount.toString(),
                    'Sites',
                  ),
                ),
              ],
            ),
            const SizedBox(height: PMSpacing.s5),
            SizedBox(
              width: double.infinity,
              child: PMButton.primary(
                label: 'VIEW ATTENDANCE',
                onPressed: () => context.go('/app/attendance'),
                icon: Icons.checklist_rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(bool isDark, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: PMTypography.headline),
        const SizedBox(height: PMSpacing.s1),
        Text(
          label,
          style: PMTypography.caption.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildLargeActionItem(
            icon: Icons.payments,
            label: 'Payroll',
            isDark: isDark,
            onTap: () => context.go('/app/payroll'),
          ),
        ),
        const SizedBox(width: PMSpacing.s3),
        Expanded(
          child: _buildLargeActionItem(
            icon: Icons.how_to_reg,
            label: 'Sites',
            isDark: isDark,
            onTap: () => context.go('/app/sites'),
          ),
        ),
        const SizedBox(width: PMSpacing.s3),
        Expanded(
          child: _buildLargeActionItem(
            icon: Icons.notifications_outlined,
            label: 'Notices',
            isDark: isDark,
            onTap: () => context.go('/app/notices'),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeActionItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: PMSpacing.s4),
        decoration: BoxDecoration(
          color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
          borderRadius: PMRadius.md,
          border: Border.all(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              label,
              style: PMTypography.caption.copyWith(
                color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurface(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
        borderRadius: PMRadius.lg,
        border: Border.all(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
        boxShadow: isDark ? PMElevation.floatingDark : PMElevation.floatingLight,
      ),
      child: child,
    );
  }
}

/// Greeting follows the viewer's actual local time — no hardcoded time of day.
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}
