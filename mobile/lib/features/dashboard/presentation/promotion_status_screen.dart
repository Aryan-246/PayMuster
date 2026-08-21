import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../company/data/company_provider.dart';

class PromotionStatusScreen extends ConsumerStatefulWidget {
  const PromotionStatusScreen({super.key});

  @override
  ConsumerState<PromotionStatusScreen> createState() =>
      _PromotionStatusScreenState();
}

class _PromotionStatusScreenState extends ConsumerState<PromotionStatusScreen> {
  OwnerRequest? _request;
  bool _isLoading = true;
  bool _isOpeningDashboard = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequest();
  }

  Future<void> _fetchRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final request = await ref.read(companyProvider).getMyOwnerRequest();
      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Promotion & Ownership Status',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh),
            onPressed: _isOpeningDashboard ? null : _fetchRequest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Failed to load status',
                      style: PMTypography.headline.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: PMTypography.body.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchRequest,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _request == null
          ? _buildEmptyState(context, textColor)
          : _buildRequestCard(
              context,
              _request!,
              isDark,
              textColor,
              surfaceColor,
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 64,
              color: PMColors.brandPrimaryLight,
            ),
            const SizedBox(height: PMSpacing.s6),
            Text(
              'No Active Promotion Requests',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'You have not submitted an owner promotion request yet. Apply now to register your business on PayMuster.',
              style: PMTypography.body.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PMSpacing.s8),
            ElevatedButton.icon(
              onPressed: () => context.push('/app/owner-request'),
              icon: const Icon(Icons.business_center),
              label: const Text('Apply for Company Ownership'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                backgroundColor: PMColors.brandPrimaryLight,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOwnerDashboard() async {
    if (_isOpeningDashboard) return;
    setState(() => _isOpeningDashboard = true);

    final refreshedUser = await ref
        .read(authControllerProvider.notifier)
        .fetchMe();
    if (!mounted) return;

    final isEligible =
        refreshedUser?.role == UserRole.owner &&
        refreshedUser?.organizationId != null;
    if (isEligible) {
      context.go('/app/owner-dashboard');
      return;
    }

    setState(() => _isOpeningDashboard = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your account is not ready for the Owner dashboard. Refresh status after the organization is provisioned.',
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    OwnerRequest request,
    bool isDark,
    Color textColor,
    Color surfaceColor,
  ) {
    final status = request.status;
    final companyName = request.companyName;
    final publicId = request.publicId ?? request.id;
    final deleteReason = request.rejectionReason;

    final isPending = status == 'PENDING';
    final isApproved = status == 'APPROVED';

    final statusColor = isApproved
        ? PMColors.statusSuccessLight
        : isPending
        ? PMColors.statusWarningLight
        : PMColors.statusDangerLight;

    final statusIcon = isApproved
        ? Icons.check_circle_outline
        : isPending
        ? Icons.hourglass_top_outlined
        : Icons.cancel_outlined;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: Container(
          padding: const EdgeInsets.all(PMSpacing.s6),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: PMRadius.md,
            border: Border.all(
              color: isDark
                  ? PMColors.borderDefaultDark
                  : PMColors.borderDefaultLight,
            ),
            boxShadow: isDark
                ? PMElevation.raisedDark
                : PMElevation.raisedLight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 64, color: statusColor),
              const SizedBox(height: PMSpacing.s4),
              Text(
                isApproved
                    ? 'Owner Request Approved!'
                    : isPending
                    ? 'Request Pending Review'
                    : 'Request Not Approved',
                style: PMTypography.title.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                'Company: $companyName',
                style: PMTypography.headline.copyWith(
                  color: PMColors.brandPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Request ID: $publicId',
                style: PMTypography.caption.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: PMSpacing.s6),
              if (isPending) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PMColors.statusWarningLight.withValues(alpha: 0.1),
                    borderRadius: PMRadius.sm,
                  ),
                  child: Text(
                    'Your application is currently being reviewed by Super Admin. You will be notified once a decision is made.',
                    style: PMTypography.body.copyWith(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else if (isApproved) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PMColors.statusSuccessLight.withValues(alpha: 0.1),
                    borderRadius: PMRadius.sm,
                  ),
                  child: Text(
                    'Congratulations! Your organization has been created and your role has been upgraded to OWNER.',
                    style: PMTypography.body.copyWith(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: PMSpacing.s6),
                ElevatedButton.icon(
                  onPressed: _isOpeningDashboard ? null : _openOwnerDashboard,
                  icon: _isOpeningDashboard
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.dashboard),
                  label: Text(
                    _isOpeningDashboard
                        ? 'Refreshing account'
                        : 'Open Owner Dashboard',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    backgroundColor: PMColors.brandPrimaryLight,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PMColors.statusDangerLight.withValues(alpha: 0.1),
                    borderRadius: PMRadius.sm,
                  ),
                  child: Text(
                    deleteReason ??
                        'Your owner request was not approved. Please verify your company details and try submitting again.',
                    style: PMTypography.body.copyWith(
                      color: PMColors.statusDangerLight,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: PMSpacing.s6),
                ElevatedButton.icon(
                  onPressed: () => context.push('/app/owner-request'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-submit Request'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    backgroundColor: PMColors.brandPrimaryLight,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
