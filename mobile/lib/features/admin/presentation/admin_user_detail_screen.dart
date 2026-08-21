import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'admin_users_refresh_provider.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  AdminUserDetail? _detail;
  bool _isLoading = true;
  String? _error;
  bool _isActionRunning = false;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserDetail();
  }

  Future<void> _fetchUserDetail() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await ref
          .read(adminApiClientProvider)
          .getUserById(widget.userId);
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _detail = detail;
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

  Future<bool> _performAction(
    String action, {
    String? role,
    String? reason,
    bool refreshAfterSuccess = true,
  }) async {
    if (_isActionRunning) return false;
    setState(() => _isActionRunning = true);
    try {
      await ref
          .read(adminApiClientProvider)
          .executeUserAction(widget.userId, action, role: role, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User action $action executed successfully!'),
            backgroundColor: AdminColors.success,
          ),
        );
        if (refreshAfterSuccess) {
          await _fetchUserDetail();
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    try {
      final tempPassword = await ref
          .read(adminApiClientProvider)
          .resetUserPassword(widget.userId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Password Reset Successful',
              style: AdminTypography.titleMd.copyWith(
                color: AdminColors.onSurface,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A new temporary password has been generated:',
                  style: AdminTypography.bodyMd.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AdminSpacing.compact),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AdminSpacing.compact),
                  decoration: BoxDecoration(
                    color: AdminColors.surfaceContainerHigh,
                    borderRadius: AdminRadius.sm,
                    border: Border.all(color: AdminColors.glassBorder),
                  ),
                  child: SelectableText(
                    tempPassword,
                    style: AdminTypography.labelMono.copyWith(
                      color: AdminColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset password failed: $e'),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  void _showRoleChangeModal() {
    final roles = [
      'OWNER',
      'ADMIN',
      'SUPERVISOR',
      'ACCOUNTANT',
      'STAFF',
      'VIEWER',
    ];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AdminSpacing.md),
                child: Text(
                  'Select New Role',
                  style: AdminTypography.titleMd.copyWith(
                    color: AdminColors.onSurface,
                  ),
                ),
              ),
              const Divider(height: 1, color: AdminColors.glassBorder),
              ...roles.map(
                (r) => ListTile(
                  title: Text(
                    r,
                    style: AdminTypography.bodyMd.copyWith(
                      color: AdminColors.onSurface,
                    ),
                  ),
                  trailing: _detail?.user.role == r
                      ? const Icon(Icons.check, color: AdminColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _performAction('CHANGE_ROLE', role: r);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    var deletionReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final canDelete = deletionReason.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              'Delete User Account?',
              style: AdminTypography.titleMd.copyWith(
                color: AdminColors.onSurface,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The user will lose access immediately. Their organization, sites, attendance, payroll, and audit history will be preserved.',
                    style: AdminTypography.bodyMd.copyWith(
                      color: AdminColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  TextField(
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    onChanged: (value) {
                      deletionReason = value;
                      setDialogState(() {});
                    },
                    decoration: const InputDecoration(
                      labelText: 'Deletion reason',
                      hintText: 'Explain why this account must be deleted',
                      helperText:
                          'Required. This reason is retained in the audit trail.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.danger,
                  foregroundColor: AdminColors.onError,
                ),
                onPressed: canDelete
                    ? () => Navigator.pop(dialogContext, deletionReason.trim())
                    : null,
                child: const Text('Delete Account'),
              ),
            ],
          );
        },
      ),
    );

    if (reason == null || !mounted) return;
    final deleted = await _performAction(
      'DELETE',
      reason: reason,
      refreshAfterSuccess: false,
    );
    if (deleted && mounted) {
      ref.read(adminUsersRefreshProvider.notifier).requestRefresh();
      context.go('/admin/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        backgroundColor: AdminColors.surfaceContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh user profile',
            onPressed: _fetchUserDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const AdminLoadingState()
          : _error != null
          ? AdminErrorState(error: _error!, onRetry: _fetchUserDetail)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(_detail!.user),
                  const SizedBox(height: AdminSpacing.md),
                  _buildActionButtons(_detail!.user),
                  const SizedBox(height: AdminSpacing.lg),
                  _buildDetailsCard(_detail!.user),
                  const SizedBox(height: AdminSpacing.lg),
                  _buildOwnerRequestsSection(_detail!.ownerRequests),
                  const SizedBox(height: AdminSpacing.lg),
                  _buildAuditLogsSection(_detail!.auditLogs),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(AdminUser u) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainer,
        borderRadius: AdminRadius.md,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AdminColors.primary,
            child: Text(
              u.name.trim().isNotEmpty ? u.name.trim()[0].toUpperCase() : 'A',
              style: AdminTypography.headlineLg.copyWith(
                color: AdminColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: AdminSpacing.md),
          Text(
            u.name,
            style: AdminTypography.headlineSm.copyWith(
              color: AdminColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AdminSpacing.xs),
          SelectableText(
            u.email,
            style: AdminTypography.bodyMd.copyWith(
              color: AdminColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AdminSpacing.compact),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            children: [
              AdminBadge.role(u.role),
              AdminBadge.status(u.status, isDisabled: u.isDisabled),
            ],
          ),
          const SizedBox(height: AdminSpacing.compact),
          SelectableText(
            'Public ID: ${u.publicId}',
            style: AdminTypography.labelMono.copyWith(
              color: AdminColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AdminUser u) {
    if (_isActionRunning) {
      return const Center(child: CircularProgressIndicator());
    }

    final roleButton = ElevatedButton.icon(
      onPressed: _showRoleChangeModal,
      icon: const Icon(Icons.manage_accounts_outlined),
      label: const Text('Change Role'),
    );
    final passwordButton = ElevatedButton.icon(
      onPressed: _resetPassword,
      icon: const Icon(Icons.lock_reset_outlined),
      label: const Text('Reset Password'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.info,
        foregroundColor: AdminColors.onSecondary,
      ),
    );
    final blockColor = u.isDisabled ? AdminColors.success : AdminColors.warning;
    final blockButton = OutlinedButton.icon(
      onPressed: () => _performAction(u.isDisabled ? 'UNBLOCK' : 'BLOCK'),
      icon: Icon(
        u.isDisabled ? Icons.check_circle_outline : Icons.block_outlined,
      ),
      label: Text(u.isDisabled ? 'Unblock User' : 'Block User'),
      style: OutlinedButton.styleFrom(
        foregroundColor: blockColor,
        side: BorderSide(color: blockColor),
      ),
    );
    final deleteButton = OutlinedButton.icon(
      onPressed: _confirmDelete,
      icon: const Icon(Icons.delete_forever_outlined),
      label: const Text('Delete Account'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.danger,
        side: const BorderSide(color: AdminColors.danger),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final width = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - AdminSpacing.compact) / 2;
        return Wrap(
          spacing: AdminSpacing.compact,
          runSpacing: AdminSpacing.compact,
          children: [
            SizedBox(width: width, child: roleButton),
            SizedBox(width: width, child: passwordButton),
            SizedBox(width: width, child: blockButton),
            SizedBox(width: width, child: deleteButton),
          ],
        );
      },
    );
  }

  Widget _buildDetailsCard(AdminUser u) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainer,
        borderRadius: AdminRadius.md,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Account Information'),
          const SizedBox(height: AdminSpacing.md),
          _buildInfoRow('Database ID', u.id),
          _buildInfoRow('Phone', u.phone ?? 'Not provided'),
          _buildInfoRow('Email Verified', u.emailVerified ? 'Yes' : 'No'),
          _buildInfoRow('Company', u.companyName ?? 'None'),
          _buildInfoRow('Company Public ID', u.companyPublicId ?? 'N/A'),
          _buildInfoRow(
            'Created At',
            u.createdAt != null && u.createdAt!.length >= 10
                ? u.createdAt!.substring(0, 10)
                : 'Unknown',
          ),
          _buildInfoRow(
            'Last Login',
            u.lastLoginAt != null && u.lastLoginAt!.length >= 10
                ? u.lastLoginAt!.substring(0, 10)
                : 'Never',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AdminTypography.bodySm.copyWith(
              color: AdminColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: AdminTypography.labelMono.copyWith(
                color: AdminColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerRequestsSection(List<AdminOwnerRequest> reqs) {
    if (reqs.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(title: 'Owner Requests History'),
        const SizedBox(height: AdminSpacing.compact),
        ...reqs.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AdminSpacing.md),
              decoration: BoxDecoration(
                color: AdminColors.surfaceContainer,
                borderRadius: AdminRadius.md,
                border: Border.all(color: AdminColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AdminSpacing.sm,
                    runSpacing: AdminSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        r.companyName,
                        style: AdminTypography.titleSm.copyWith(
                          color: AdminColors.onSurface,
                        ),
                      ),
                      AdminBadge.status(r.status),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.sm),
                  SelectableText(
                    'ID: ${r.publicId} / GSTIN: ${r.gstin ?? 'N/A'}',
                    style: AdminTypography.labelMono.copyWith(
                      color: AdminColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogsSection(List<AdminAuditLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(title: 'Audit Log Trail'),
        const SizedBox(height: AdminSpacing.compact),
        if (logs.isEmpty)
          Text(
            'No audit logs recorded for this user.',
            style: AdminTypography.bodyMd.copyWith(
              color: AdminColors.onSurfaceVariant,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AdminColors.surfaceContainer,
              borderRadius: AdminRadius.md,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AdminColors.glassBorder),
              itemBuilder: (context, index) {
                final log = logs[index];
                final eventColor = log.action == 'APPROVE'
                    ? AdminColors.success
                    : log.action == 'DELETE' || log.action == 'REJECT'
                    ? AdminColors.danger
                    : AdminColors.info;
                final date = log.createdAt.length >= 10
                    ? log.createdAt.substring(0, 10)
                    : log.createdAt;
                return ListTile(
                  leading: Icon(
                    Icons.history_outlined,
                    color: eventColor,
                    size: 20,
                  ),
                  title: Text(
                    '${log.action} / ${log.entityType}',
                    style: AdminTypography.titleSm.copyWith(color: eventColor),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AdminSpacing.xs),
                    child: SelectableText(
                      'By: ${log.userName ?? 'System'} / $date',
                      style: AdminTypography.labelMono.copyWith(
                        color: AdminColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
