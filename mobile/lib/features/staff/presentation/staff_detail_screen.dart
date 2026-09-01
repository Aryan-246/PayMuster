import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/staff_directory_api.dart';

final staffProfileProvider = FutureProvider.family<StaffProfile, String>((
  ref,
  staffId,
) {
  return ref.watch(staffDirectoryApiProvider).getProfile(staffId);
});

/// Enriched Owner/ADMIN staff profile (manage_staff-gated endpoint):
/// verification state, bank details, salary rules, payment history, documents
/// with approve/reject review, and site assignments.
class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;

    final profile = ref.watch(staffProfileProvider(staffId));

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Worker Profile',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: () => ref.invalidate(staffProfileProvider(staffId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const PMListSkeleton(itemCount: 5),
        error: (error, _) => _ProfileErrorState(
          message: error is TenantApiException
              ? error.message
              : 'The worker profile could not be loaded.',
          onRetry: () => ref.invalidate(staffProfileProvider(staffId)),
        ),
        data: (data) => _ProfileBody(profile: data),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final StaffProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    final member = profile.member;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(staffProfileProvider(member.id)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PMSpacing.s5),
        children: [
          // Header: identity + blue-tick verification state.
          PMCard.standard(
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: PMColors.brandPrimaryLight
                          .withValues(alpha: 0.12),
                      child: Text(
                        member.firstName.isNotEmpty
                            ? member.firstName.substring(0, 1).toUpperCase()
                            : '?',
                        style: PMTypography.title.copyWith(
                          color: PMColors.brandPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: PMSpacing.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.fullName,
                                  style: PMTypography.title.copyWith(
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (profile.verification.verified) ...[
                                const SizedBox(width: PMSpacing.s2),
                                const Icon(
                                  Icons.verified,
                                  color: PMColors.statusSuccessLight,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: PMSpacing.s1),
                          Text(
                            [
                              member.publicId,
                              _workerTypeLabel(member.workerType),
                              member.status,
                            ].join(' · '),
                            style: PMTypography.caption
                                .copyWith(color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PMSpacing.s4),
                _VerificationPanel(verification: profile.verification),
              ],
            ),
          ),
          const SizedBox(height: PMSpacing.s5),

          _SectionTitle('Contact'),
          _InfoRow(label: 'Phone', value: member.phone ?? 'Not provided'),
          _InfoRow(label: 'Email', value: member.email ?? 'Not provided'),
          _InfoRow(
            label: 'Joined',
            value: member.joinDate == null
                ? 'Not recorded'
                : _formatDate(member.joinDate!),
          ),
          const SizedBox(height: PMSpacing.s5),

          _SectionTitle('Payment details'),
          _InfoRow(
            label: 'Bank account',
            value: profile.bankAccountNumber ?? 'Not provided',
          ),
          _InfoRow(
            label: 'IFSC',
            value: profile.ifscCode ?? 'Not provided',
          ),
          _InfoRow(label: 'UPI ID', value: profile.upiId ?? 'Not provided'),
          _InfoRow(
            label: 'Preferred method',
            value: profile.preferredPaymentMethod ?? 'Not set',
          ),
          const SizedBox(height: PMSpacing.s5),

          _SectionTitle(
            'Salary rules',
            trailing: profile.salaryRules.isEmpty
                ? null
                : '${profile.salaryRules.length}',
          ),
          if (profile.salaryRules.isEmpty)
            const _EmptyHint(
              icon: Icons.payments_outlined,
              message:
                  'No salary rules recorded. Payroll amounts are computed from attendance by the backend.',
            )
          else
            for (final rule in profile.salaryRules)
              PMCard.standard(
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: PMColors.brandPrimaryLight,
                    ),
                    const SizedBox(width: PMSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rateTypeLabel(rule.rateType),
                            style: PMTypography.headline
                                .copyWith(color: textColor),
                          ),
                          Text(
                            '₹${rule.amount} · effective ${_formatDate(rule.effectiveDate)}',
                            style: PMTypography.caption
                                .copyWith(color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: PMSpacing.s5),

          _SectionTitle(
            'Payments',
            trailing: profile.payments.isEmpty
                ? null
                : '${profile.payments.length}',
          ),
          if (profile.payments.isEmpty)
            const _EmptyHint(
              icon: Icons.account_balance_wallet_outlined,
              message: 'No payments recorded for this worker yet.',
            )
          else
            for (final payment in profile.payments)
              PMCard.standard(
                child: Row(
                  children: [
                    _PaymentStatusDot(status: payment.status),
                    const SizedBox(width: PMSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${payment.amount} · ${payment.mode}',
                            style: PMTypography.headline
                                .copyWith(color: textColor),
                          ),
                          Text(
                            '${payment.status} · ${_formatDate(payment.createdAt)}'
                            '${payment.referenceId != null ? ' · ref ${payment.referenceId}' : ''}',
                            style: PMTypography.caption
                                .copyWith(color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: PMSpacing.s5),

          _SectionTitle(
            'Documents',
            trailing: profile.documents.isEmpty
                ? null
                : '${profile.documents.length}',
          ),
          if (profile.documents.isEmpty)
            const _EmptyHint(
              icon: Icons.folder_outlined,
              message:
                  'No documents uploaded. The worker submits documents from their own app.',
            )
          else
            for (final document in profile.documents)
              _DocumentCard(
                key: ValueKey('staff-document-${document.id}'),
                staffId: member.id,
                document: document,
              ),
          const SizedBox(height: PMSpacing.s5),

          _SectionTitle(
            'Site assignments',
            trailing: profile.siteAssignments.isEmpty
                ? null
                : '${profile.siteAssignments.length}',
          ),
          if (profile.siteAssignments.isEmpty)
            const _EmptyHint(
              icon: Icons.location_city_outlined,
              message: 'This worker is not assigned to any site.',
            )
          else
            for (final assignment in profile.siteAssignments)
              PMCard.standard(
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: PMColors.brandPrimaryLight,
                    ),
                    const SizedBox(width: PMSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.siteName,
                            style: PMTypography.headline
                                .copyWith(color: textColor),
                          ),
                          Text(
                            'Assigned ${_formatDate(assignment.assignedAt)}',
                            style: PMTypography.caption
                                .copyWith(color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: PMSpacing.s8),
        ],
      ),
    );
  }
}

/// The owner.txt blue-tick gate: verification is earned only when payment
/// details are complete AND at least one document is approved. The panel
/// states exactly what is missing — never a fake tick.
class _VerificationPanel extends StatelessWidget {
  const _VerificationPanel({required this.verification});

  final StaffVerification verification;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    final color = verification.verified
        ? PMColors.statusSuccessLight
        : PMColors.statusWarningLight;
    final title = verification.verified
        ? 'Verified'
        : 'Verification pending';
    final details = verification.verified
        ? 'Payment details complete and documents approved.'
        : [
            if (!verification.bankDetailsComplete)
              'Add bank/UPI details',
            if (!verification.documentApproved)
              'Approve at least one document',
          ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PMSpacing.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: PMRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            verification.verified
                ? Icons.verified_outlined
                : Icons.hourglass_top_outlined,
            color: color,
          ),
          const SizedBox(width: PMSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PMTypography.headline.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  details,
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

class _DocumentCard extends ConsumerStatefulWidget {
  const _DocumentCard({
    super.key,
    required this.staffId,
    required this.document,
  });

  final String staffId;
  final StaffDocument document;

  @override
  ConsumerState<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends ConsumerState<_DocumentCard> {
  bool _submitting = false;

  Future<void> _review(String action, {String? reason}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(staffDirectoryApiProvider).reviewDocument(
            widget.staffId,
            widget.document.id,
            action,
            reason: reason,
          );
      ref.invalidate(staffProfileProvider(widget.staffId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'REJECTED'
                  ? 'Document rejected'
                  : 'Document approved',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TenantApiException
                  ? error.message
                  : 'The review could not be saved.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _rejectWithReason() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectionDialog(),
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await _review('REJECTED', reason: reason.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final document = widget.document;

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                document.isApproved
                    ? Icons.task_alt_outlined
                    : document.status == 'REJECTED'
                        ? Icons.cancel_outlined
                        : Icons.description_outlined,
                color: document.isApproved
                    ? PMColors.statusSuccessLight
                    : document.status == 'REJECTED'
                        ? PMColors.statusDangerLight
                        : PMColors.statusWarningLight,
              ),
              const SizedBox(width: PMSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.originalFilename ?? document.type,
                      style: PMTypography.headline.copyWith(color: textColor),
                    ),
                    Text(
                      '${document.type} · v${document.version} · '
                      '${_formatDate(document.createdAt)}',
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PMSpacing.s3,
                  vertical: PMSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(document).withValues(alpha: 0.14),
                  borderRadius: PMRadius.sm,
                ),
                child: Text(
                  _statusLabel(document),
                  style: PMTypography.caption.copyWith(
                    color: _statusColor(document),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (document.status == 'REJECTED' &&
              document.rejectionReason != null) ...[
            const SizedBox(height: PMSpacing.s2),
            Text(
              'Rejected: ${document.rejectionReason}',
              style: PMTypography.caption.copyWith(
                color: PMColors.statusDangerLight,
              ),
            ),
          ],
          if (document.isPending) ...[
            const SizedBox(height: PMSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: PMButton.primary(
                    label: 'Approve',
                    icon: Icons.check,
                    isLoading: _submitting,
                    onPressed: _submitting
                        ? null
                        : () => _review('APPROVED'),
                  ),
                ),
                const SizedBox(width: PMSpacing.s3),
                Expanded(
                  child: PMButton.secondary(
                    label: 'Reject',
                    icon: Icons.close,
                    onPressed:
                        _submitting ? null : _rejectWithReason,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog();

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The worker will see this reason and can resubmit.',
          ),
          const SizedBox(height: PMSpacing.s4),
          TextField(
            key: const Key('rejection-reason-field'),
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'e.g. The scan is blurry',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.only(
        left: PMSpacing.s2,
        bottom: PMSpacing.s3,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: PMTypography.title.copyWith(
              color: PMColors.brandPrimaryLight,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: PMTypography.caption.copyWith(color: textColor),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
    final border =
        isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;

    return Container(
      margin: const EdgeInsets.only(bottom: PMSpacing.s2),
      padding: const EdgeInsets.symmetric(
        horizontal: PMSpacing.s4,
        vertical: PMSpacing.s3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: PMRadius.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: PMTypography.caption.copyWith(color: secondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: PMTypography.body.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s5),
      decoration: BoxDecoration(
        borderRadius: PMRadius.md,
        border: Border.all(
          color: isDark
              ? PMColors.borderDefaultDark
              : PMColors.borderDefaultLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: secondary),
          const SizedBox(width: PMSpacing.s3),
          Expanded(
            child: Text(
              message,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusDot extends StatelessWidget {
  const _PaymentStatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PAID' => PMColors.statusSuccessLight,
      'FAILED' => PMColors.statusDangerLight,
      'DRAFT' => PMColors.textSecondaryLight,
      _ => PMColors.statusWarningLight,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
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

Color _statusColor(StaffDocument document) {
  if (document.isApproved) return PMColors.statusSuccessLight;
  if (document.status == 'REJECTED') return PMColors.statusDangerLight;
  return PMColors.statusWarningLight;
}

String _statusLabel(StaffDocument document) {
  return switch (document.status) {
    'APPROVED' || 'VERIFIED' => 'Approved',
    'REJECTED' => 'Rejected',
    'EXPIRED' => 'Expired',
    'PENDING' => 'Pending',
    'PENDING_REVIEW' => 'Pending review',
    'UNDER_REVIEW' => 'Under review',
    'UPLOADED' => 'Uploaded',
    _ => document.status,
  };
}

String _workerTypeLabel(String workerType) {
  return switch (workerType) {
    'DAILY' => 'Daily wage',
    'MONTHLY' => 'Monthly',
    'CONTRACT' => 'Contract',
    _ => workerType,
  };
}

String _rateTypeLabel(String rateType) {
  return switch (rateType) {
    'HOURLY' => 'Hourly rate',
    'DAILY' => 'Daily rate',
    'MONTHLY' => 'Monthly salary',
    'OVERTIME' => 'Overtime rate',
    'NIGHT_SHIFT' => 'Night shift rate',
    'HOLIDAY' => 'Holiday rate',
    _ => rateType,
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
