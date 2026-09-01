import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Review moderation detail (§ latest directive #5): full review text, user,
/// company, status, admin response — with Publish / Hide / Flag / Respond
/// actions behind confirmations. Every action is audited server-side and
/// notifies the submitter.
class AdminReviewDetailScreen extends ConsumerStatefulWidget {
  const AdminReviewDetailScreen({super.key, required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<AdminReviewDetailScreen> createState() =>
      _AdminReviewDetailScreenState();
}

class _AdminReviewDetailScreenState
    extends ConsumerState<AdminReviewDetailScreen> {
  AdminReview? _review;
  bool _isLoading = true;
  bool _isActing = false;
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
      _isLoading = _review == null;
      _error = null;
    });

    try {
      final review =
          await ref.read(adminApiClientProvider).getReviewDetail(widget.reviewId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _review = review;
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

  Future<void> _runAction({
    required String action,
    required String confirmTitle,
    required String confirmBody,
    String? response,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surfaceContainerHigh,
        title: Text(
          confirmTitle,
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        content: Text(
          confirmBody,
          style:
              AdminTypography.bodyMd.copyWith(color: AdminColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: action == 'PUBLISH'
                  ? AdminColors.success
                  : AdminColors.primary,
              foregroundColor: AdminColors.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    try {
      await ref.read(adminApiClientProvider).moderateReview(
            widget.reviewId,
            action: action,
            response: response,
          );
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
            style: TextStyle(color: AdminColors.onErrorContainer),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _respond() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surfaceContainerHigh,
        title: Text(
          'Respond to review',
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Public response',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: AdminColors.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final text = controller.text.trim();
    controller.dispose();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response cannot be empty.')),
      );
      return;
    }

    await _runAction(
      action: 'RESPOND',
      confirmTitle: 'Publish response?',
      confirmBody:
          'Your response will be attached to this review and the submitter '
          'will be notified.',
      response: text,
      successMessage: 'Response sent and submitter notified.',
    );
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
                    _buildReviewCard(_review!),
                    const SizedBox(height: AdminSpacing.md),
                    _buildActions(_review!),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(_review?.publicId ?? 'Review'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading || _isActing ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildReviewCard(AdminReview r) {
    final statusColor = switch (r.status) {
      'PUBLISHED' => AdminColors.success,
      'PENDING' => AdminColors.warning,
      'FLAGGED' => AdminColors.danger,
      _ => AdminColors.neutral,
    };
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < r.rating ? Icons.star : Icons.star_border,
                    color: AdminColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              AdminBadge(label: r.status, color: statusColor),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            r.text,
            style: AdminTypography.bodyMd.copyWith(color: AdminColors.onSurface),
          ),
          const SizedBox(height: AdminSpacing.md),
          _infoRow('Review ID', r.publicId),
          _infoRow('User', r.userName ?? '—'),
          _infoRow('User ID', r.userPublicId ?? '—'),
          if (r.userEmail != null) _infoRow('Email', r.userEmail!),
          if (r.userRole != null) _infoRow('Role', r.userRole!),
          _infoRow('Company', r.orgName ?? '—'),
          if (r.orgPublicId != null) _infoRow('Company ID', r.orgPublicId!),
          _infoRow('Submitted', _fmt(r.createdAt)),
          if (r.moderatedAt != null)
            _infoRow('Moderated', _fmt(r.moderatedAt!)),
          if (r.adminResponse != null && r.adminResponse!.isNotEmpty) ...[
            const Divider(color: AdminColors.glassBorder),
            Text(
              'Admin response',
              style: AdminTypography.labelSm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AdminSpacing.compact),
              decoration: BoxDecoration(
                color: AdminColors.primary.withValues(alpha: 0.08),
                borderRadius: AdminRadius.md,
                border: Border.all(
                  color: AdminColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                r.adminResponse!,
                style: AdminTypography.bodySm
                    .copyWith(color: AdminColors.onSurface),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(AdminReview r) {
    if (_isActing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AdminSpacing.md),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isPending = r.status == 'PENDING';
    final isPublished = r.status == 'PUBLISHED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPending || !isPublished)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: AdminColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
            ),
            onPressed: () => _runAction(
              action: 'PUBLISH',
              confirmTitle: 'Publish this review?',
              confirmBody:
                  'The review will become publicly visible in the company’s '
                  'published ratings. The submitter will be notified.',
              successMessage: 'Review published.',
            ),
            icon: const Icon(Icons.public_outlined, size: 18),
            label: const Text('Publish'),
          ),
        if (isPending || isPublished)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.warning,
              side: const BorderSide(color: AdminColors.warning),
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
            ),
            onPressed: () => _runAction(
              action: 'HIDE',
              confirmTitle: 'Hide this review?',
              confirmBody:
                  'The review will be removed from public ratings but kept '
                  'for records. The submitter will be notified.',
              successMessage: 'Review hidden.',
            ),
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
            label: const Text('Hide'),
          ),
        if (r.status != 'FLAGGED')
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.danger,
              side: const BorderSide(color: AdminColors.danger),
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
            ),
            onPressed: () => _runAction(
              action: 'FLAG',
              confirmTitle: 'Flag this review?',
              confirmBody:
                  'The review will be marked as flagged for policy review and '
                  'removed from public ratings. The submitter will be notified.',
              successMessage: 'Review flagged.',
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Flag'),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.primary,
            side: const BorderSide(color: AdminColors.primary),
            padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
          ),
          onPressed: _respond,
          icon: const Icon(Icons.reply_outlined, size: 18),
          label: Text(
            r.adminResponse == null || r.adminResponse!.isEmpty
                ? 'Respond'
                : 'Update response',
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurface),
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
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
