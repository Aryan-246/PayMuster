import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  List<AdminAttendanceRecord> _records = [];
  bool _isLoading = true;
  String? _error;
  int _totalRecords = 0;
  String _selectedStatus = 'ALL';
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(adminApiClientProvider)
          .getAttendanceRecords(status: _selectedStatus);
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _records = res['records'] as List<AdminAttendanceRecord>;
        _totalRecords = res['total'] as int;
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
          'System Attendance ($_totalRecords)',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRecords),
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
                  _buildChip('PRESENT'),
                  _buildChip('ABSENT'),
                  _buildChip('HALF_DAY'),
                  _buildChip('LEAVE'),
                  _buildChip('OVERTIME'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AdminLoadingState()
                : _error != null
                ? AdminErrorState(error: _error!, onRetry: _fetchRecords)
                : _records.isEmpty
                ? const AdminEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No Attendance Records',
                    message: 'No attendance records logged yet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final r = _records[index];
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
                            backgroundColor: AdminColors.success.withValues(
                              alpha: 0.12,
                            ),
                            child: const Icon(
                              Icons.fact_check_outlined,
                              color: AdminColors.success,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  r.staffName,
                                  style: AdminTypography.titleSm.copyWith(
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AdminBadge.status(r.status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AdminSpacing.xs),
                              Text(
                                '${r.companyName} • ${r.siteName}',
                                style: AdminTypography.bodySm.copyWith(
                                  color: AdminColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${r.publicId} • Date: ${r.date.length >= 10 ? r.date.substring(0, 10) : r.date}',
                                style: AdminTypography.labelMono.copyWith(
                                  color: AdminColors.onSurfaceMuted,
                                ),
                              ),
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

  Widget _buildChip(String status) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: AdminSpacing.sm),
      child: FilterChip(
        label: Text(
          status,
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
          _fetchRecords();
        },
      ),
    );
  }
}
