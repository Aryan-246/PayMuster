import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../core/network/tenant_api_client.dart';
import '../data/foundation_ai_api.dart';

/// Owner AI assistant (owner.txt AI section): a bounded, backend-mediated
/// query surface. Every answer comes from POST /ai/:operation — the app never
/// invents one, and provider outages surface as the server's own honest error.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _promptController = TextEditingController();
  String _operation = 'query';
  bool _isSubmitting = false;
  AiAnalysisResult? _result;
  String? _error;

  static const _operations = {
    'query': 'Ask a question',
    'analyze': 'Analyze',
    'summary': 'Summarize',
    'insights': 'Insights',
  };

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ref
          .read(foundationAiApiProvider)
          .submit(_operation, prompt);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = error is TenantApiException
            ? error.message
            : 'The AI request could not be completed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary =
        isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('AI Assistant', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PMSpacing.s5),
          children: [
            PMCard.standard(
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: PMColors.brandPrimaryLight),
                  const SizedBox(width: PMSpacing.s3),
                  Expanded(
                    child: Text(
                      'Answers are generated from your company data by the PayMuster '
                      'backend with strict safety rules. The assistant cannot modify '
                      'payroll, staff, or money records.',
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PMSpacing.s5),
            SegmentedButton<String>(
              key: const Key('ai-operation-segment'),
              segments: _operations.entries
                  .map((entry) => ButtonSegment(value: entry.key, label: Text(entry.value)))
                  .toList(),
              selected: {_operation},
              onSelectionChanged: (selection) =>
                  setState(() => _operation = selection.first),
            ),
            const SizedBox(height: PMSpacing.s5),
            TextField(
              key: const Key('ai-prompt-field'),
              controller: _promptController,
              maxLines: 4,
              minLines: 2,
              maxLength: 2000,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Your question',
                hintText: 'e.g. Summarize attendance issues this week',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: PMSpacing.s4),
            PMButton.primary(
              key: const Key('ai-submit-button'),
              label: 'Ask PayMuster AI',
              icon: Icons.auto_awesome,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting || _promptController.text.trim().isEmpty
                  ? null
                  : _submit,
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: PMSpacing.s5),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: PMSpacing.s2),
              Center(
                child: Text(
                  'The backend is composing an answer from live company data…',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: PMSpacing.s5),
              PMCard.stat(
                accentColor: PMColors.statusDangerLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            color: PMColors.statusDangerLight),
                        const SizedBox(width: PMSpacing.s3),
                        Text('Unavailable',
                            style: PMTypography.headline.copyWith(color: textColor)),
                      ],
                    ),
                    const SizedBox(height: PMSpacing.s3),
                    Text(
                      _error!,
                      style: PMTypography.body.copyWith(color: textColor),
                    ),
                    const SizedBox(height: PMSpacing.s3),
                    Text(
                      'This may mean the AI provider is not configured for this '
                      'environment. Nothing is faked — retry when it is available.',
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: PMSpacing.s5),
              PMCard.standard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Answer', style: PMTypography.headline.copyWith(color: textColor)),
                    const SizedBox(height: PMSpacing.s3),
                    SelectableText(
                      _result!.analysis,
                      style: PMTypography.body.copyWith(color: textColor, height: 1.4),
                    ),
                    const SizedBox(height: PMSpacing.s4),
                    Text(
                      'Provider: ${_result!.provider}'
                      '${_result!.model.isNotEmpty ? ' · ${_result!.model}' : ''}'
                      ' · ${_result!.operation.toLowerCase()}'
                      ' · read-only',
                      style: PMTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
