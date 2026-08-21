import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminOwnerRequestsScreen extends ConsumerStatefulWidget {
  const AdminOwnerRequestsScreen({super.key});

  @override
  ConsumerState<AdminOwnerRequestsScreen> createState() =>
      _AdminOwnerRequestsScreenState();
}

class _AdminOwnerRequestsScreenState
    extends ConsumerState<AdminOwnerRequestsScreen> {
  List<AdminOwnerRequest> _requests = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'PENDING';
  bool _isProcessing = false;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reqs = await ref
          .read(adminApiClientProvider)
          .getOwnerRequests(status: _selectedStatus);
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _requests = reqs;
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

  Future<void> _approveRequest(AdminOwnerRequest r) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final result = await ref
          .read(adminApiClientProvider)
          .approveOwnerRequest(r.id);
      final org = result['organization'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        await _fetchRequests();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AdminColors.success),
                SizedBox(width: AdminSpacing.sm),
                Text('Owner Approved!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company "${r.companyName}" was successfully created and user upgraded to OWNER.',
                ),
                const SizedBox(height: AdminSpacing.compact),
                Container(
                  padding: const EdgeInsets.all(AdminSpacing.compact),
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withValues(alpha: 0.1),
                    borderRadius: AdminRadius.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Public ID: ${org['publicId'] ?? 'Unavailable'}',
                        style: AdminTypography.labelMono,
                      ),
                      const SizedBox(height: AdminSpacing.xs),
                      Text(
                        'Join Code: ${org['joinCode'] ?? 'Unavailable'}',
                        style: AdminTypography.titleSm.copyWith(
                          color: AdminColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approval failed: $e'),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRequest(AdminOwnerRequest r) async {
    if (_isProcessing) return;
    final reasonController = TextEditingController();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject Owner Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reject the ownership request for "${r.companyName}"?',
              ),
              const SizedBox(height: AdminSpacing.compact),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Rejection (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
              onPressed: () =>
                  Navigator.pop(dialogContext, reasonController.text.trim()),
              child: const Text('Confirm Reject'),
            ),
          ],
        ),
      );

      if (!mounted || reason == null) return;
      setState(() => _isProcessing = true);
      final messenger = ScaffoldMessenger.of(context);

      try {
        await ref
            .read(adminApiClientProvider)
            .rejectOwnerRequest(r.id, reason: reason);
        if (!mounted) return;

        await _fetchRequests();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Request rejected successfully'),
            backgroundColor: AdminColors.warning,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Rejection failed: $e'),
            backgroundColor: AdminColors.danger,
          ),
        );
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } finally {
      reasonController.dispose();
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
          'Owner Promotion Requests',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.md,
              vertical: AdminSpacing.sm,
            ),
            color: surfaceColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusTab('PENDING', 'Pending'),
                  const SizedBox(width: AdminSpacing.sm),
                  _buildStatusTab('APPROVED', 'Approved'),
                  const SizedBox(width: AdminSpacing.sm),
                  _buildStatusTab('REJECTED', 'Rejected'),
                  const SizedBox(width: AdminSpacing.sm),
                  _buildStatusTab('ALL', 'All'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading || _isProcessing
                ? const AdminLoadingState()
                : _error != null
                ? AdminErrorState(error: _error!, onRetry: _fetchRequests)
                : _requests.isEmpty
                ? AdminEmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No Requests Found',
                    message:
                        'No owner promotion requests in status "$_selectedStatus".',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final r = _requests[index];
                      return _buildRequestCard(context, r);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String status, String label) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(
        label,
        style: AdminTypography.labelSm.copyWith(
          color: isSelected ? AdminColors.onPrimary : AdminColors.primary,
        ),
      ),
      selected: isSelected,
      selectedColor: AdminColors.primary,
      backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
      checkmarkColor: AdminColors.onPrimary,
      onSelected: (_) {
        setState(() => _selectedStatus = status);
        _fetchRequests();
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, AdminOwnerRequest r) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.md),
      color: AdminColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: AdminRadius.md,
        side: BorderSide(color: AdminColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    r.companyName,
                    style: AdminTypography.headlineSm.copyWith(
                      color: AdminColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                AdminBadge.status(r.status),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.sm,
                    vertical: AdminSpacing.xs,
                  ),
                  decoration: const BoxDecoration(
                    color: AdminColors.surfaceContainerHigh,
                    borderRadius: AdminRadius.sm,
                  ),
                  child: Text(
                    'Req ID: ${r.publicId}',
                    style: AdminTypography.labelMono,
                  ),
                ),
                if (r.gstin != null && r.gstin!.isNotEmpty) ...[
                  const SizedBox(width: AdminSpacing.sm),
                  Flexible(
                    child: Text(
                      'GSTIN: ${r.gstin}',
                      style: AdminTypography.labelMono.copyWith(
                        color: AdminColors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: AdminSpacing.lg),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    r.userName.trim().isNotEmpty
                        ? r.userName.trim()[0].toUpperCase()
                        : 'A',
                    style: AdminTypography.titleSm.copyWith(
                      color: AdminColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.userName,
                        style: AdminTypography.titleSm.copyWith(
                          color: AdminColors.onSurface,
                        ),
                      ),
                      Text(
                        '${r.userEmail} • ${r.userPublicId}',
                        style: AdminTypography.bodySm.copyWith(
                          color: AdminColors.onSurfaceMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline, size: 20),
                  tooltip: 'View User Profile',
                  onPressed: () => context.push('/admin/users/${r.userId}'),
                ),
              ],
            ),
            if (r.companyAddress != null && r.companyAddress!.isNotEmpty) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                'Address: ${r.companyAddress}',
                style: AdminTypography.bodyMd.copyWith(
                  color: AdminColors.onSurfaceVariant,
                ),
              ),
            ],
            if (r.deleteReason != null && r.deleteReason!.isNotEmpty) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                'Rejection Reason: ${r.deleteReason}',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.danger,
                ),
              ),
            ],
            if (r.status == 'PENDING') ...[
              const SizedBox(height: AdminSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final approveButton = ElevatedButton.icon(
                    onPressed: () => _approveRequest(r),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve & Create Company'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.success,
                      foregroundColor: AdminColors.onError,
                    ),
                  );
                  final rejectButton = OutlinedButton.icon(
                    onPressed: () => _rejectRequest(r),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject Request'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.danger,
                      side: const BorderSide(color: AdminColors.danger),
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        approveButton,
                        const SizedBox(height: AdminSpacing.sm),
                        rejectButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: approveButton),
                      const SizedBox(width: AdminSpacing.compact),
                      Expanded(child: rejectButton),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
