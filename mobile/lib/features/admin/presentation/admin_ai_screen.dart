import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminAiScreen extends ConsumerStatefulWidget {
  const AdminAiScreen({super.key});

  @override
  ConsumerState<AdminAiScreen> createState() => _AdminAiScreenState();
}

class _AdminAiScreenState extends ConsumerState<AdminAiScreen> {
  final _promptController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _isLoading = false;
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

  String _value(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'Unavailable' : text;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AdminColors.onSurface;
    final surfaceColor = AdminColors.surfaceContainer;
    final scope = _result?['scope'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
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
                    'Platform operations analysis',
                    style: AdminTypography.headlineSm.copyWith(
                      color: textColor,
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
                      hintText: 'Describe the situation you want reviewed',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.compact),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _sendPrompt,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Analyze prompt'),
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
            Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistant response',
                      style: AdminTypography.headlineSm.copyWith(
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.compact),
                    SelectableText(
                      _value(_result!['message']),
                      style: AdminTypography.bodyMd.copyWith(color: textColor),
                    ),
                    if (scope != null) ...[
                      const Divider(height: AdminSpacing.xl),
                      Text(
                        'Operational scope',
                        style: AdminTypography.titleSm.copyWith(
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.compact),
                      _buildValueRow('Users', scope['users'], textColor),
                      _buildValueRow(
                        'Companies',
                        scope['companies'],
                        textColor,
                      ),
                      _buildValueRow('Sites', scope['sites'], textColor),
                      _buildValueRow(
                        'Attendance records',
                        scope['attendance'],
                        textColor,
                      ),
                      _buildValueRow(
                        'Payroll runs',
                        scope['payroll'],
                        textColor,
                      ),
                      _buildValueRow(
                        'Pending owner requests',
                        scope['pendingOwnerRequests'],
                        textColor,
                      ),
                      _buildValueRow(
                        'Blocked users',
                        scope['blockedUsers'],
                        textColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValueRow(String label, dynamic value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              _value(value),
              style: AdminTypography.labelMono.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
