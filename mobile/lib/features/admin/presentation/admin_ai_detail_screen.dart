import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// AI analysis detail (latest directive #2): everything about one assistant
/// interaction — original prompt, timestamp, answer, operational context,
/// metrics, tools used, entities (navigable), proposed/executed actions with
/// status, warnings, and provider/model info. Fully scrollable.
class AdminAiDetailScreen extends ConsumerStatefulWidget {
  const AdminAiDetailScreen({
    super.key,
    required this.prompt,
    required this.result,
  });

  final String prompt;
  final Map<String, dynamic> result;

  @override
  ConsumerState<AdminAiDetailScreen> createState() =>
      _AdminAiDetailScreenState();
}

class _AdminAiDetailScreenState extends ConsumerState<AdminAiDetailScreen> {
  late Map<String, dynamic> _result;
  bool _isConfirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  Map<String, dynamic>? get _confirmation =>
      _result['confirmation'] as Map<String, dynamic>?;

  /// Approving executes the confirmed action through the authorized service
  /// layer (single-use server token, SUPER_ADMIN re-checked, audited).
  Future<void> _approveAndExecute() async {
    final token = _confirmation?['token'] as String?;
    if (token == null || _isConfirming) return;
    setState(() {
      _isConfirming = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminApiClientProvider)
          .sendAiPrompt(widget.prompt, confirmationToken: token);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AdminColors.onSurface;
    final surfaceColor = AdminColors.surfaceContainer;
    final intent = (_result['intent'] as String? ?? '').toUpperCase();
    final degraded = _result['degraded'] == true;
    final toolCalls =
        (_result['toolCalls'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final entities =
        (_result['entities'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final metrics = _result['metrics'] as Map<String, dynamic>?;
    final contextUsed = _result['contextUsed'] as Map<String, dynamic>?;
    final executedAction = _result['executedAction'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('AI analysis detail'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminSpacing.md),
        children: [
          _buildIntentHeader(intent, degraded),
          const SizedBox(height: AdminSpacing.md),
          _buildPromptCard(),
          const SizedBox(height: AdminSpacing.md),
          _buildAnswerCard(),
          if (degraded) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildDegradedWarning(),
          ],
          if (_confirmation != null) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildConfirmationCard(_confirmation!),
          ],
          if (executedAction != null) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildExecutedActionCard(executedAction),
          ],
          if (contextUsed != null && contextUsed.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildMapCard('Operational context used', contextUsed, surfaceColor, textColor),
          ],
          if (metrics != null && metrics.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildMapCard('Relevant metrics', metrics, surfaceColor, textColor),
          ],
          if (toolCalls.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildToolCallsCard(toolCalls),
          ],
          if (entities.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildEntitiesCard(entities),
          ],
          const SizedBox(height: AdminSpacing.md),
          _buildMetaCard(),
          if (_error != null) ...[
            const SizedBox(height: AdminSpacing.md),
            AdminErrorState(error: _error!, onRetry: _approveAndExecute),
          ],
        ],
      ),
    );
  }

  Widget _buildIntentHeader(String intent, bool degraded) {
    final (color, icon, label) = switch (intent) {
      'ANSWER' => (
        AdminColors.success,
        Icons.check_circle_outline,
        'Answered with live data'
      ),
      'CONFIRMATION_REQUIRED' => (
        AdminColors.warning,
        Icons.gavel_outlined,
        'Action proposed — confirmation required'
      ),
      'ACTION_EXECUTED' => (
        AdminColors.info,
        Icons.task_alt_outlined,
        'Action executed through the authorized service layer'
      ),
      'DATA_FALLBACK' => (
        AdminColors.warning,
        Icons.warning_amber_outlined,
        'Degraded answer — live data retrieved, composition failed'
      ),
      'REFUSED' => (
        AdminColors.neutral,
        Icons.block_outlined,
        'Refused — outside the assistant\'s capabilities'
      ),
      _ => (AdminColors.neutral, Icons.help_outline, intent),
    };

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
            ),
          ),
          AdminBadge(label: intent, color: color),
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
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
          const AdminSectionHeader(title: 'Original prompt'),
          const SizedBox(height: AdminSpacing.sm),
          SelectableText(
            widget.prompt,
            style: AdminTypography.bodyMd
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard() {
    final message = (_result['message'] as String?) ?? '';
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
          const AdminSectionHeader(title: 'Assistant answer'),
          const SizedBox(height: AdminSpacing.sm),
          SelectableText(
            message.isNotEmpty ? message : 'No answer was produced.',
            style: AdminTypography.bodyMd.copyWith(color: AdminColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildDegradedWarning() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.warning.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(
          color: AdminColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AdminColors.warning, size: 20),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              'The AI model could not compose a final answer, so the live data '
              'retrieved from the tools below is shown instead. Nothing was '
              'fabricated.',
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationCard(Map<String, dynamic> confirmation) {
    final target = confirmation['target'] as Map<String, dynamic>? ?? const {};
    final currentState =
        confirmation['currentState'] as Map<String, dynamic>? ?? const {};
    final expiresAt = confirmation['expiresAt'] as String?;
    final expired = expiresAt != null &&
        (DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) ?? false);

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.warning.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(
          color: AdminColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Action proposed — awaiting your approval'),
          const SizedBox(height: AdminSpacing.sm),
          _labeledValue(
            'Operation',
            (confirmation['operation'] as String? ?? '—'),
          ),
          _labeledValue(
            'Target',
            '${target['name'] ?? '—'} (${target['type'] ?? '—'})'
            '${target['publicId'] != null ? ' • ${target['publicId']}' : ''}',
          ),
          if (currentState.isNotEmpty)
            _labeledValue(
              'Current state',
              currentState.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', '),
            ),
          _labeledValue(
            'Consequence',
            confirmation['consequences'] as String? ?? '—',
          ),
          _labeledValue(
            'Expires',
            expiresAt != null ? _fmt(expiresAt, withTime: true) : '—',
          ),
          const SizedBox(height: AdminSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('ai-approve-action-button'),
              onPressed: (_isConfirming || expired) ? null : _approveAndExecute,
              icon: _isConfirming
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: Text(expired
                  ? 'Confirmation expired — ask again'
                  : _isConfirming
                      ? 'Executing…'
                      : 'Approve and execute'),
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.warning,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutedActionCard(Map<String, dynamic> action) {
    final ok = (action['status'] as String? ?? '') == 'SUCCESS';
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: (ok ? AdminColors.success : AdminColors.danger).withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(
          color: (ok ? AdminColors.success : AdminColors.danger)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Action executed'),
          const SizedBox(height: AdminSpacing.sm),
          _labeledValue('Operation', action['operation'] as String? ?? '—'),
          _labeledValue('Target', action['targetName'] as String? ?? action['targetId'] as String? ?? '—'),
          _labeledValue(
            'Status',
            action['status'] as String? ?? '—',
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            'Executed through the existing authorized service layer with '
            'SUPER_ADMIN authorization re-enforced server-side. The transition '
            'is audited and the organization owners are notified.',
            style: AdminTypography.bodySm
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(
    String title,
    Map<String, dynamic> map,
    Color surfaceColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AdminRadius.xl,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(title: title),
          const SizedBox(height: AdminSpacing.sm),
          ...map.entries.map(
            (e) => _labeledValue(e.key, e.value?.toString() ?? '—'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCallsCard(List<Map<String, dynamic>> toolCalls) {
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
          const AdminSectionHeader(title: 'Tools used (live data sources)'),
          const SizedBox(height: AdminSpacing.sm),
          ...toolCalls.map(
            (t) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.build_circle_outlined,
                size: 18,
                color: AdminColors.primary,
              ),
              title: Text(
                t['name'] as String? ?? '—',
                style: AdminTypography.titleSm
                    .copyWith(color: AdminColors.onSurface),
              ),
              subtitle: Text(
                t['summary'] as String? ?? '',
                style: AdminTypography.bodySm
                    .copyWith(color: AdminColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntitiesCard(List<Map<String, dynamic>> entities) {
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
          const AdminSectionHeader(title: 'Entities identified'),
          const SizedBox(height: AdminSpacing.sm),
          ...entities.map(
            (e) {
              final route = e['route'] as String?;
              final navigable = route != null && route.isNotEmpty;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (e['type'] as String? ?? '') {
                    'org' => Icons.business_outlined,
                    'user' => Icons.person_outline,
                    'site' => Icons.location_city_outlined,
                    'subscription' => Icons.card_membership_outlined,
                    'review' => Icons.rate_review_outlined,
                    'announcement' => Icons.campaign_outlined,
                    _ => Icons.category_outlined,
                  },
                  size: 18,
                  color: AdminColors.secondary,
                ),
                title: Text(
                  e['name'] as String? ?? '—',
                  style: AdminTypography.titleSm
                      .copyWith(color: AdminColors.onSurface),
                ),
                subtitle: Text(
                  '${e['type'] ?? '—'}'
                  '${e['publicId'] != null ? ' • ${e['publicId']}' : ''}'
                  '${e['subtitle'] != null ? ' • ${e['subtitle']}' : ''}',
                  style: AdminTypography.bodySm
                      .copyWith(color: AdminColors.onSurfaceMuted),
                ),
                trailing: navigable
                    ? const Icon(Icons.chevron_right, size: 18)
                    : null,
                onTap: navigable ? () => context.go(route) : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard() {
    final generatedAt = _result['generatedAt'] as String?;
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
          const AdminSectionHeader(title: 'Provider & audit'),
          const SizedBox(height: AdminSpacing.sm),
          _labeledValue('Provider', _result['provider'] as String? ?? '—'),
          _labeledValue('Model', _result['model'] as String? ?? '—'),
          _labeledValue(
            'Generated at',
            generatedAt != null ? _fmt(generatedAt, withTime: true) : '—',
          ),
          _labeledValue(
            'Duration',
            '${(_result['durationMs'] as num?)?.toInt() ?? 0} ms',
          ),
          _labeledValue(
            'Audit',
            'Every AI interaction and action transition (proposed → executed/'
                'rejected) is recorded in the platform audit log.',
          ),
        ],
      ),
    );
  }

  Widget _labeledValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
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

String _fmt(String iso, {bool withTime = false}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final date =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  if (!withTime) return date;
  return '$date '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
