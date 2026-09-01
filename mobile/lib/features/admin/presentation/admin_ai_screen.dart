import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import 'admin_ai_detail_screen.dart';
import 'widgets/admin_ui_helpers.dart';

/// AI Assistant (latest directive #1/#2): conversational, intent-driven
/// assistant backed by the SUPER_ADMIN-only tool-calling pipeline. Destructive
/// operations are proposed, never executed — the admin approves them
/// explicitly here; every answer opens a full detail screen.
class AdminAiScreen extends ConsumerStatefulWidget {
  const AdminAiScreen({super.key});

  @override
  ConsumerState<AdminAiScreen> createState() => _AdminAiScreenState();
}

class _AdminAiScreenState extends ConsumerState<AdminAiScreen> {
  final _promptController = TextEditingController();
  String? _prompt;
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  bool _isConfirming = false;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _prompt = prompt;
    });

    try {
      final result = await ref
          .read(adminApiClientProvider)
          .sendAiPrompt(prompt);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Approve a proposed destructive operation: executes through the authorized
  /// service layer with a single-use server token, then shows the outcome.
  Future<void> _approveConfirmation() async {
    final confirmation = _result?['confirmation'] as Map<String, dynamic>?;
    final token = confirmation?['token'] as String?;
    if (token == null || _isConfirming) return;
    setState(() {
      _isConfirming = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminApiClientProvider)
          .sendAiPrompt(_prompt ?? '', confirmationToken: token);
      if (mounted) {
        setState(() => _result = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _openDetail() {
    final result = _result;
    if (result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AdminAiDetailScreen(
          prompt: _prompt ?? '',
          result: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AdminColors.onSurface;
    final surfaceColor = AdminColors.surfaceContainer;

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AdminSpacing.md),
        children: [
          Card(
            color: surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform operations assistant',
                    style: AdminTypography.headlineSm.copyWith(
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.xs),
                  Text(
                    'Ask about users, companies, sites, subscriptions, payments, '
                    'mail, reviews, announcements, providers or recent activity. '
                    'Answers use live platform data; destructive operations '
                    'require your explicit approval.',
                    style: AdminTypography.bodySm.copyWith(
                      color: AdminColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  TextField(
                    controller: _promptController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      hintText: 'e.g. How many users joined in the last 30 days?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.compact),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _sendPrompt,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Ask assistant'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: AdminSpacing.md),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: AdminSpacing.md),
            AdminErrorState(error: _error!, onRetry: _sendPrompt),
          ],
          if (_result != null) ...[
            const SizedBox(height: AdminSpacing.md),
            _buildResultSummary(),
            if ((_result!['confirmation'] as Map<String, dynamic>?) != null) ...[
              const SizedBox(height: AdminSpacing.md),
              _buildConfirmationCard(
                _result!['confirmation'] as Map<String, dynamic>,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildResultSummary() {
    final result = _result!;
    final intent = (result['intent'] as String? ?? '').toUpperCase();
    final message = result['message'] as String? ?? '';
    final degraded = result['degraded'] == true;

    return Card(
      color: AdminColors.surfaceContainer,
      child: InkWell(
        onTap: _openDetail,
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Assistant response',
                      style: AdminTypography.headlineSm.copyWith(
                        color: AdminColors.onSurface,
                      ),
                    ),
                  ),
                  AdminBadge(
                    label: intent,
                    color: switch (intent) {
                      'ANSWER' => AdminColors.success,
                      'CONFIRMATION_REQUIRED' => AdminColors.warning,
                      'ACTION_EXECUTED' => AdminColors.info,
                      'DATA_FALLBACK' => AdminColors.warning,
                      _ => AdminColors.neutral,
                    },
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  const Icon(Icons.chevron_right,
                      size: 20, color: AdminColors.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AdminSpacing.compact),
              SelectableText(
                message,
                style: AdminTypography.bodyMd.copyWith(
                  color: AdminColors.onSurface,
                ),
              ),
              if (degraded) ...[
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  'Degraded answer — live data was retrieved but the model could '
                  'not compose the final response.',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: AdminSpacing.xs),
              Text(
                'Tap for the full analysis: context, metrics, tools, entities '
                'and actions.',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationCard(Map<String, dynamic> confirmation) {
    final target = confirmation['target'] as Map<String, dynamic>? ?? const {};
    final expiresAt = confirmation['expiresAt'] as String?;
    final expired = expiresAt != null &&
        (DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) ?? false);

    return Card(
      color: AdminColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_outlined,
                    color: AdminColors.warning, size: 20),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    'Action proposed — approval required',
                    style: AdminTypography.titleMd
                        .copyWith(color: AdminColors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              '${confirmation['operation']} → ${target['name'] ?? '—'}'
              '${target['publicId'] != null ? ' (${target['publicId']})' : ''}',
              style: AdminTypography.titleSm.copyWith(
                color: AdminColors.onSurface,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              confirmation['consequences'] as String? ?? '',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('ai-approve-action-button'),
                onPressed: (_isConfirming || expired)
                    ? null
                    : _approveConfirmation,
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
      ),
    );
  }
}
