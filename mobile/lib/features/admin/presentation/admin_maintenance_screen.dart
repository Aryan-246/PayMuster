import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminMaintenanceScreen extends ConsumerStatefulWidget {
  const AdminMaintenanceScreen({super.key});

  @override
  ConsumerState<AdminMaintenanceScreen> createState() =>
      _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState
    extends ConsumerState<AdminMaintenanceScreen> {
  bool? _enabled;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final enabled = await ref
          .read(adminApiClientProvider)
          .getMaintenanceMode();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _enabled = enabled;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setStatus(bool enabled) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          enabled ? 'Enable maintenance mode?' : 'Disable maintenance mode?',
        ),
        content: Text(
          enabled
              ? 'Regular users will be blocked while maintenance mode is active. Super Admin access remains available.'
              : 'Regular users will be allowed to access the platform again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(enabled ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(adminApiClientProvider).setMaintenanceMode(enabled);
      await _loadStatus();
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Maintenance mode enabled'
                  : 'Maintenance mode disabled',
            ),
            backgroundColor: AdminColors.success,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maintenance update failed: $error'),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AdminColors.onSurface;
    final surfaceColor = AdminColors.surfaceContainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Mode'),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _isSaving ? null : _loadStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const AdminLoadingState()
          : _error != null
          ? AdminErrorState(error: _error!, onRetry: _loadStatus)
          : ListView(
              padding: const EdgeInsets.all(AdminSpacing.md),
              children: [
                Card(
                  color: surfaceColor,
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _enabled == true
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              color: _enabled == true
                                  ? AdminColors.warning
                                  : AdminColors.success,
                              size: 36,
                            ),
                            const SizedBox(width: AdminSpacing.compact),
                            Expanded(
                              child: Text(
                                _enabled == true ? 'Enabled' : 'Disabled',
                                style: AdminTypography.headlineSm.copyWith(
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AdminSpacing.md),
                        Text(
                          _enabled == true
                              ? 'The server is currently restricting regular user access.'
                              : 'The server is currently accepting regular user access.',
                          style: AdminTypography.bodyMd.copyWith(
                            color: AdminColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AdminSpacing.lg),
                        if (_isSaving)
                          const LinearProgressIndicator()
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _setStatus(_enabled != true),
                              icon: Icon(
                                _enabled == true
                                    ? Icons.lock_open_outlined
                                    : Icons.lock_outline,
                              ),
                              label: Text(
                                _enabled == true
                                    ? 'Disable Maintenance Mode'
                                    : 'Enable Maintenance Mode',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AdminSpacing.md),
                Text(
                  'Only the authenticated Super Admin role is permitted to change this setting. The displayed state comes from the backend system setting.',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
