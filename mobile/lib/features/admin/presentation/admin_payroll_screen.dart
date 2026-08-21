import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminPayrollScreen extends ConsumerStatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  ConsumerState<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends ConsumerState<AdminPayrollScreen> {
  List<AdminPayrollRecord> _payRuns = [];
  bool _isLoading = true;
  String? _error;
  int _totalPayroll = 0;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchPayroll();
  }

  Future<void> _fetchPayroll() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref.read(adminApiClientProvider).getPayrollRecords();
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _payRuns = res['payRuns'] as List<AdminPayrollRecord>;
        _totalPayroll = res['total'] as int;
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
          'System Pay Runs ($_totalPayroll)',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPayroll),
        ],
      ),
      body: _isLoading
          ? const AdminLoadingState()
          : _error != null
          ? AdminErrorState(error: _error!, onRetry: _fetchPayroll)
          : _payRuns.isEmpty
          ? const AdminEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No Pay Runs Found',
              message: 'No calculated or disbursed pay runs in system.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AdminSpacing.md),
              itemCount: _payRuns.length,
              itemBuilder: (context, index) {
                final pr = _payRuns[index];
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
                      radius: 20,
                      backgroundColor: AdminColors.warning.withValues(
                        alpha: 0.12,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AdminColors.warning,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pr.companyName,
                            style: AdminTypography.titleSm.copyWith(
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AdminBadge.status(pr.status),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
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
                                pr.publicId,
                                style: AdminTypography.labelMono,
                              ),
                            ),
                            const SizedBox(width: AdminSpacing.sm),
                            Text(
                              '₹${pr.totalAmount.toStringAsFixed(2)}',
                              style: AdminTypography.titleSm.copyWith(
                                color: AdminColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AdminSpacing.xs),
                        Text(
                          'Items: ${pr.itemCount} • Period: ${pr.startDate != null && pr.startDate!.length >= 10 ? pr.startDate!.substring(0, 10) : 'N/A'} to ${pr.endDate != null && pr.endDate!.length >= 10 ? pr.endDate!.substring(0, 10) : 'N/A'}',
                          style: AdminTypography.bodySm.copyWith(
                            color: AdminColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
