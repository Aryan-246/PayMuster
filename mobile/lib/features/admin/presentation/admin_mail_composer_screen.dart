import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';

/// Platform mail composer (§5): audience resolution (ALL / ROLE / ORG /
/// INDIVIDUAL) with a REAL estimated recipient count from
/// POST /admin/mail/preview, bulk-send confirmation, and an honest
/// Sent/Failed/Partial/Queued result — never a fake success.
class AdminMailComposerScreen extends ConsumerStatefulWidget {
  const AdminMailComposerScreen({super.key});

  @override
  ConsumerState<AdminMailComposerScreen> createState() =>
      _AdminMailComposerScreenState();
}

class _AdminMailComposerScreenState
    extends ConsumerState<AdminMailComposerScreen> {
  static const _targetTypes = ['ALL', 'ROLE', 'ORGANIZATION', 'INDIVIDUAL'];
  static const _roles = ['OWNER', 'ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF', 'VIEWER'];

  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _orgIdController = TextEditingController();
  final _userIdController = TextEditingController();

  String _targetType = 'ALL';
  String? _targetRole;
  int? _estimatedCount;
  bool _previewing = false;
  bool _sending = false;
  String? _previewError;
  AdminMailSendResult? _result;
  String? _sendError;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _orgIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  bool get _canPreview =>
      _subjectController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      !_previewing &&
      !_sending;

  bool get _canSend =>
      _subjectController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      !_previewing &&
      !_sending;

  bool get _needsOrg => _targetType == 'ORGANIZATION';
  bool get _needsRole => _targetType == 'ROLE';
  bool get _needsUser => _targetType == 'INDIVIDUAL';

  Future<void> _preview() async {
    setState(() {
      _previewing = true;
      _previewError = null;
      _estimatedCount = null;
    });

    try {
      final result = await ref.read(adminApiClientProvider).previewPlatformMail(
            subject: _subjectController.text.trim(),
            body: _bodyController.text.trim(),
            targetType: _targetType,
            targetRole: _needsRole ? _targetRole : null,
            targetUserId: _needsUser && _userIdController.text.isNotEmpty
                ? _userIdController.text.trim()
                : null,
            orgId: _needsOrg && _orgIdController.text.isNotEmpty
                ? _orgIdController.text.trim()
                : null,
          );
      if (!mounted) return;
      setState(() => _estimatedCount = result.count);
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewError = e.toString());
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _send() async {
    final count = _estimatedCount;
    if (count == null) {
      await _preview();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surfaceContainerHigh,
        title: Text(
          'Send to $count recipient${count == 1 ? '' : 's'}?',
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        content: Text(
          '"${_subjectController.text.trim()}" will be delivered to $count '
          'user${count == 1 ? '' : 's'} through the configured email provider. '
          'This action is audited.',
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
              backgroundColor: AdminColors.primary,
              foregroundColor: AdminColors.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _sendError = null;
      _result = null;
    });

    try {
      final result = await ref.read(adminApiClientProvider).sendPlatformMail(
            subject: _subjectController.text.trim(),
            body: _bodyController.text.trim(),
            targetType: _targetType,
            targetRole: _needsRole ? _targetRole : null,
            targetUserId: _needsUser && _userIdController.text.isNotEmpty
                ? _userIdController.text.trim()
                : null,
            orgId: _needsOrg && _orgIdController.text.isNotEmpty
                ? _orgIdController.text.trim()
                : null,
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Compose Email'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AdminSpacing.md),
          children: [
            _buildAudienceSection(),
            const SizedBox(height: AdminSpacing.md),
            _buildMessageSection(),
            const SizedBox(height: AdminSpacing.md),
            if (_previewError != null)
              _buildNotice(
                _previewError!,
                AdminColors.danger,
                Icons.error_outline,
              ),
            if (_sendError != null) ...[
              _buildNotice(
                _sendError!,
                AdminColors.danger,
                Icons.error_outline,
              ),
              const SizedBox(height: AdminSpacing.md),
            ],
            if (_result != null) ...[
              _buildResult(_result!),
              const SizedBox(height: AdminSpacing.md),
            ],
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceSection() {
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
          Text(
            'Audience',
            style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
          ),
          const SizedBox(height: AdminSpacing.sm),
          Wrap(
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            children: _targetTypes
                .map(
                  (t) => ChoiceChip(
                    label: Text(_audienceLabel(t)),
                    selected: _targetType == t,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _targetType = t;
                        _estimatedCount = null;
                        _previewError = null;
                      });
                    },
                    selectedColor: AdminColors.primary.withValues(alpha: 0.25),
                    backgroundColor: AdminColors.surfaceContainerHigh,
                    labelStyle: AdminTypography.labelSm.copyWith(
                      color: _targetType == t
                          ? AdminColors.primary
                          : AdminColors.onSurfaceVariant,
                    ),
                  ),
                )
                .toList(),
          ),
          if (_needsRole) ...[
            const SizedBox(height: AdminSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _targetRole,
              hint: const Text('Target role'),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() {
                _targetRole = v;
                _estimatedCount = null;
              }),
              decoration: const InputDecoration(
                labelText: 'Target role',
              ),
            ),
          ],
          if (_needsOrg) ...[
            const SizedBox(height: AdminSpacing.sm),
            TextField(
              controller: _orgIdController,
              onChanged: (_) => setState(() => _estimatedCount = null),
              decoration: const InputDecoration(
                labelText: 'Organization ID (internal UUID)',
                helperText: 'Find it via Companies → company detail.',
              ),
            ),
          ],
          if (_needsUser) ...[
            const SizedBox(height: AdminSpacing.sm),
            TextField(
              controller: _userIdController,
              onChanged: (_) => setState(() => _estimatedCount = null),
              decoration: const InputDecoration(
                labelText: 'User ID (internal UUID)',
                helperText: 'Find it via Users → user detail.',
              ),
            ),
          ],
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _canPreview ? _preview : null,
                icon: _previewing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_outlined, size: 18),
                label: Text(_previewing ? 'Checking…' : 'Estimate recipients'),
              ),
              const SizedBox(width: AdminSpacing.sm),
              if (_estimatedCount != null)
                Expanded(
                  child: Text(
                    '$_estimatedCount recipient${_estimatedCount == 1 ? '' : 's'} will receive this email',
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
    );
  }

  Widget _buildMessageSection() {
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
          Text(
            'Message',
            style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
          ),
          const SizedBox(height: AdminSpacing.sm),
          TextField(
            controller: _subjectController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Subject',
            ),
          ),
          const SizedBox(height: AdminSpacing.sm),
          TextField(
            controller: _bodyController,
            onChanged: (_) => setState(() {}),
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(AdminMailSendResult r) {
    final outcomeColor = switch (r.outcome) {
      'SENT' => AdminColors.success,
      'PARTIAL' => AdminColors.warning,
      'FAILED' => AdminColors.danger,
      'DUPLICATE' => AdminColors.info,
      _ => AdminColors.neutral,
    };
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: outcomeColor.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(color: outcomeColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.outcome == 'SENT'
                    ? Icons.check_circle_outline
                    : r.outcome == 'FAILED'
                        ? Icons.error_outline
                        : Icons.info_outline,
                color: outcomeColor,
                size: 20,
              ),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                'Result: ${r.outcome}',
                style: AdminTypography.titleMd.copyWith(color: outcomeColor),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            '${r.sent} delivered • ${r.failed} failed • ${r.blocked} blocked'
            '${r.duplicate == true ? ' • duplicate request (original result returned)' : ''}',
            style: AdminTypography.bodyMd
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
          if (r.errors.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.sm),
            ...r.errors.take(5).map(
                  (e) => Text(
                    '${e['email']}: ${e['error']}',
                    style:
                        AdminTypography.bodySm.copyWith(color: AdminColors.danger),
                  ),
                ),
          ],
          const SizedBox(height: AdminSpacing.md),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Back to Mail Supply'),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final canSend = _canSend && _estimatedCount != null && _result == null;
    return FilledButton.icon(
      onPressed: canSend ? _send : null,
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.primary,
        foregroundColor: AdminColors.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: AdminSpacing.md),
      ),
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined, size: 18),
      label: Text(
        _sending
            ? 'Sending…'
            : _estimatedCount == null
                ? 'Estimate recipients first'
                : 'Send to $_estimatedCount recipient${_estimatedCount == 1 ? '' : 's'}',
      ),
    );
  }

  Widget _buildNotice(String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AdminSpacing.md),
      padding: const EdgeInsets.all(AdminSpacing.compact),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AdminRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AdminTypography.bodySm.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _audienceLabel(String t) => switch (t) {
        'ALL' => 'All users',
        'ROLE' => 'By role',
        'ORGANIZATION' => 'A company',
        _ => 'Individual',
      };
}
