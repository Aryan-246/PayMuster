import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() =>
      _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  List<AdminAuditLog> _logs = [];
  bool _isLoading = true;
  String? _error;
  int _totalLogs = 0;
  String _selectedAction = 'ALL';
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(adminApiClientProvider)
          .getAuditLogs(action: _selectedAction);
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _logs = res['auditLogs'] as List<AdminAuditLog>;
        _totalLogs = res['total'] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = AdminColors.onSurface;
    const surfaceColor = AdminColors.surfaceContainer;

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
          'System Audit Trail ($_totalLogs)',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.md,
              vertical: AdminSpacing.sm,
            ),
            color: surfaceColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('ALL'),
                  _buildChip('CREATE'),
                  _buildChip('UPDATE'),
                  _buildChip('DELETE'),
                  _buildChip('APPROVE'),
                  _buildChip('REJECT'),
                  _buildChip('SUSPEND'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AdminLoadingState()
                : _error != null
                ? AdminErrorState(error: _error!, onRetry: _fetchLogs)
                : _logs.isEmpty
                ? const AdminEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Audit Logs',
                    message: 'No administrative audit events recorded yet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final l = _logs[index];
                      final eventColor = l.action == 'APPROVE'
                          ? AdminColors.success
                          : l.action == 'DELETE' || l.action == 'REJECT'
                          ? AdminColors.danger
                          : AdminColors.info;
                      return Card(
                        margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
                        color: surfaceColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AdminRadius.md,
                          side: BorderSide(color: AdminColors.glassBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(AdminSpacing.md),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: eventColor.withValues(alpha: 0.12),
                            child: Icon(
                              l.action == 'APPROVE'
                                  ? Icons.check_circle_outline
                                  : l.action == 'DELETE'
                                  ? Icons.delete_outline
                                  : Icons.history,
                              size: 18,
                              color: eventColor,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${l.action} • ${l.entityType}',
                                  style: AdminTypography.titleSm.copyWith(
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                l.createdAt.length >= 10
                                    ? l.createdAt.substring(0, 10)
                                    : l.createdAt,
                                style: AdminTypography.labelMono.copyWith(
                                  color: AdminColors.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AdminSpacing.xs),
                              Text(
                                'Actor: ${l.userName ?? l.userEmail ?? 'System'} ${l.companyName != null ? '(${l.companyName})' : ''}',
                                style: AdminTypography.bodySm.copyWith(
                                  color: AdminColors.onSurfaceVariant,
                                ),
                              ),
                              if (l.changes != null &&
                                  l.changes!.isNotEmpty) ...[
                                const SizedBox(height: AdminSpacing.xs),
                                Text(
                                  'Changes: ${l.changes.toString()}',
                                  style: AdminTypography.labelMono.copyWith(
                                    color: AdminColors.primary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String action) {
    final isSelected = _selectedAction == action;
    return Padding(
      padding: const EdgeInsets.only(right: AdminSpacing.sm),
      child: FilterChip(
        label: Text(
          action,
          style: AdminTypography.labelSm.copyWith(
            color: isSelected ? AdminColors.onPrimary : AdminColors.primary,
          ),
        ),
        selected: isSelected,
        selectedColor: AdminColors.primary,
        backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
        checkmarkColor: AdminColors.onPrimary,
        onSelected: (_) {
          setState(() => _selectedAction = action);
          _fetchLogs();
        },
      ),
    );
  }
}
