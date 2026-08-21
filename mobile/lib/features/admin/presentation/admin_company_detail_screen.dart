import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminCompanyDetailScreen extends ConsumerStatefulWidget {
  final String orgId;
  const AdminCompanyDetailScreen({super.key, required this.orgId});

  @override
  ConsumerState<AdminCompanyDetailScreen> createState() =>
      _AdminCompanyDetailScreenState();
}

class _AdminCompanyDetailScreenState
    extends ConsumerState<AdminCompanyDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(adminApiClientProvider)
          .getCompanyDetail(widget.orgId);
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _data = res;
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

    final company = _data?['company'] as Map<String, dynamic>?;
    final counts = company?['_count'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
          company?['name'] ?? 'Company Detail',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetail),
        ],
      ),
      body: _isLoading
          ? const AdminLoadingState()
          : _error != null
          ? AdminErrorState(error: _error!, onRetry: _fetchDetail)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AdminSpacing.lg),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: AdminRadius.md,
                      border: Border.all(color: AdminColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: AdminColors.secondaryContainer,
                          child: Icon(
                            Icons.business_outlined,
                            color: AdminColors.info,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: AdminSpacing.md),
                        Text(
                          company?['name'] ?? 'Company',
                          style: AdminTypography.headlineSm.copyWith(
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AdminSpacing.xs),
                        SelectableText(
                          'Public ID: ${company?['publicId'] ?? 'Unavailable'}',
                          style: AdminTypography.labelMono.copyWith(
                            color: AdminColors.primary,
                          ),
                        ),
                        const SizedBox(height: AdminSpacing.compact),
                        AdminBadge.status(
                          company?['status'] as String? ?? 'ACTIVE',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 560 ? 1 : 3;
                      final itemWidth =
                          (constraints.maxWidth -
                              (AdminSpacing.compact * (columns - 1))) /
                          columns;
                      return Wrap(
                        spacing: AdminSpacing.compact,
                        runSpacing: AdminSpacing.compact,
                        children: [
                          _buildMetricTile(
                            'Users',
                            '${counts['users'] ?? 0}',
                            Icons.people_outline,
                            AdminColors.info,
                            itemWidth,
                          ),
                          _buildMetricTile(
                            'Sites',
                            '${counts['sites'] ?? 0}',
                            Icons.location_city_outlined,
                            AdminColors.primary,
                            itemWidth,
                          ),
                          _buildMetricTile(
                            'Staff',
                            '${counts['staff'] ?? 0}',
                            Icons.badge_outlined,
                            AdminColors.warning,
                            itemWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AdminSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: AdminRadius.md,
                      border: Border.all(color: AdminColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminSectionHeader(
                          title: 'Company Credentials & Metadata',
                        ),
                        const SizedBox(height: AdminSpacing.md),
                        _buildRow(
                          'Join Code',
                          company?['joinCode'] ?? 'N/A',
                          textColor,
                        ),
                        _buildRow(
                          'GSTIN',
                          company?['gstin'] ?? 'Not registered',
                          textColor,
                        ),
                        _buildRow(
                          'Database ID',
                          company?['id'] ?? '',
                          textColor,
                        ),
                        _buildRow(
                          'Created Date',
                          company?['createdAt'] != null &&
                                  company!['createdAt'].length >= 10
                              ? company['createdAt'].substring(0, 10)
                              : 'Unknown',
                          textColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String val,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.md),
        decoration: BoxDecoration(
          color: AdminColors.surfaceContainer,
          borderRadius: AdminRadius.md,
          border: Border.all(color: AdminColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              val,
              style: AdminTypography.statValue.copyWith(
                color: AdminColors.onSurface,
              ),
            ),
            Text(
              title,
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.compact),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AdminTypography.bodySm.copyWith(
              color: AdminColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Flexible(
            child: SelectableText(
              val,
              textAlign: TextAlign.end,
              style: AdminTypography.labelMono.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
