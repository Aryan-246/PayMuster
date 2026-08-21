import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/admin_tokens.dart';
import '../../../../components/foundation/pm_text_input.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminCompaniesScreen extends ConsumerStatefulWidget {
  const AdminCompaniesScreen({super.key});

  @override
  ConsumerState<AdminCompaniesScreen> createState() =>
      _AdminCompaniesScreenState();
}

class _AdminCompaniesScreenState extends ConsumerState<AdminCompaniesScreen> {
  final _searchController = TextEditingController();
  List<AdminCompany> _companies = [];
  bool _isLoading = true;
  String? _error;
  int _totalCompanies = 0;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(adminApiClientProvider)
          .getCompanies(search: _searchController.text.trim());
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _companies = res['companies'] as List<AdminCompany>;
        _totalCompanies = res['total'] as int;
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
    final textColor = AdminColors.onSurface;
    final bgColor = AdminColors.background;
    final surfaceColor = AdminColors.surfaceContainer;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Companies ($_totalCompanies)',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCompanies,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            color: surfaceColor,
            child: PMTextInput(
              labelText: 'Search company name, Public ID or Join Code',
              controller: _searchController,
              onChanged: (val) => _fetchCompanies(),
              suffixIcon: const Icon(Icons.search),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AdminLoadingState()
                : _error != null
                ? AdminErrorState(error: _error!, onRetry: _fetchCompanies)
                : _companies.isEmpty
                ? const AdminEmptyState(
                    icon: Icons.business_center_outlined,
                    title: 'No Companies Found',
                    message: 'No registered organizations found.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    itemCount: _companies.length,
                    itemBuilder: (context, index) {
                      final c = _companies[index];
                      return _buildCompanyCard(
                        context,
                        c,
                        textColor,
                        surfaceColor,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    AdminCompany c,
    Color textColor,
    Color surfaceColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: AdminRadius.xl,
        side: const BorderSide(color: AdminColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AdminSpacing.md),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AdminColors.secondary.withValues(alpha: 0.1),
          child: const Icon(Icons.business, color: AdminColors.secondary),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                c.name,
                style: AdminTypography.titleMd.copyWith(color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AdminBadge.status(c.status),
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
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AdminColors.surfaceContainerHigh,
                    borderRadius: AdminRadius.sm,
                  ),
                  child: Text(
                    c.publicId,
                    style: AdminTypography.labelMono.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (c.joinCode != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.primary.withValues(alpha: 0.1),
                      borderRadius: AdminRadius.sm,
                    ),
                    child: Text(
                      'Code: ${c.joinCode}',
                      style: AdminTypography.labelMono.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AdminColors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Owner: ${c.ownerName ?? c.ownerEmail ?? 'Unassigned'} • Users: ${c.userCount} • Sites: ${c.siteCount} • Staff: ${c.staffCount}',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/companies/${c.id}'),
      ),
    );
  }
}
