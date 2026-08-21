import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/admin_tokens.dart';
import '../../../../components/foundation/pm_text_input.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminSitesScreen extends ConsumerStatefulWidget {
  const AdminSitesScreen({super.key});

  @override
  ConsumerState<AdminSitesScreen> createState() => _AdminSitesScreenState();
}

class _AdminSitesScreenState extends ConsumerState<AdminSitesScreen> {
  final _searchController = TextEditingController();
  List<AdminSite> _sites = [];
  bool _isLoading = true;
  String? _error;
  int _totalSites = 0;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchSites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSites() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(adminApiClientProvider)
          .getSites(search: _searchController.text.trim());
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _sites = res['sites'] as List<AdminSite>;
        _totalSites = res['total'] as int;
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
          'Sites & Locations ($_totalSites)',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchSites),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            color: surfaceColor,
            child: PMTextInput(
              labelText: 'Search site name, address or Public ID',
              controller: _searchController,
              onChanged: (val) => _fetchSites(),
              suffixIcon: const Icon(Icons.search),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AdminLoadingState()
                : _error != null
                ? AdminErrorState(error: _error!, onRetry: _fetchSites)
                : _sites.isEmpty
                ? const AdminEmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'No Sites Found',
                    message: 'No construction/operational sites found.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    itemCount: _sites.length,
                    itemBuilder: (context, index) {
                      final s = _sites[index];
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
                            radius: 24,
                            backgroundColor: AdminColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            child: const Icon(
                              Icons.location_city_outlined,
                              color: AdminColors.primary,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: AdminTypography.titleSm.copyWith(
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AdminBadge.status(s.status),
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
                                      s.publicId,
                                      style: AdminTypography.labelMono,
                                    ),
                                  ),
                                  if (s.companyName != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Company: ${s.companyName}',
                                        style: AdminTypography.bodySm.copyWith(
                                          color: AdminColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (s.address != null &&
                                  s.address!.isNotEmpty) ...[
                                const SizedBox(height: AdminSpacing.xs),
                                Text(
                                  'Address: ${s.address}',
                                  style: AdminTypography.bodySm.copyWith(
                                    color: AdminColors.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: AdminSpacing.xs),
                              Text(
                                'Assigned Workers: ${s.assignmentCount} • Attendance Logs: ${s.attendanceCount}',
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
          ),
        ],
      ),
    );
  }
}
