import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Owners directory (§ latest directive #8): every OWNER user with their
/// company association, account status and last login — navigating into the
/// full user detail (and from there the company) for verification state.
class AdminOwnersScreen extends ConsumerStatefulWidget {
  const AdminOwnersScreen({super.key});

  @override
  ConsumerState<AdminOwnersScreen> createState() =>
      _AdminOwnersScreenState();
}

class _AdminOwnersScreenState extends ConsumerState<AdminOwnersScreen> {
  final _searchController = TextEditingController();
  List<AdminUser> _owners = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _search = '';
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _owners = [];
      }
    });

    try {
      final result = await ref.read(adminApiClientProvider).getUsers(
            query: _search.isNotEmpty ? _search : null,
            role: 'OWNER',
            page: reset ? 1 : _page,
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final rows = result['users'] as List<AdminUser>;
        _owners = reset ? rows : [..._owners, ...rows];
        _total = (result['total'] as num?)?.toInt() ?? rows.length;
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 1;
        _page = (result['page'] as num?)?.toInt() ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading && _owners.isEmpty
        ? const AdminLoadingState()
        : _error != null && _owners.isEmpty
            ? AdminErrorState(error: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AdminSpacing.md),
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        _search = value.trim();
                        _load(reset: true);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search owner name, email or ID…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _search = '';
                                  _load(reset: true);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AdminColors.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: AdminRadius.md,
                          borderSide:
                              const BorderSide(color: AdminColors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AdminRadius.md,
                          borderSide:
                              const BorderSide(color: AdminColors.glassBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.sm),
                    Text(
                      '$_total owner${_total == 1 ? '' : 's'} on the platform',
                      style: AdminTypography.bodySm.copyWith(
                        color: AdminColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    if (_owners.isEmpty && !_isLoading)
                      const AdminEmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No owners found',
                        message:
                            'Owners appear here once their owner request is '
                            'approved and they create a company.',
                      )
                    else
                      ..._owners.map(_buildOwnerCard),
                    if (_page < _totalPages)
                      Padding(
                        padding: const EdgeInsets.only(top: AdminSpacing.md),
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _page += 1;
                                  _load(reset: false);
                                },
                          icon: const Icon(Icons.expand_more),
                          label: Text('Load more ($_page/$_totalPages)'),
                        ),
                      ),
                    if (_error != null && _owners.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AdminSpacing.md),
                        child: AdminErrorState(error: _error!, onRetry: _load),
                      ),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Owners'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildOwnerCard(AdminUser o) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AdminRadius.xl,
          onTap: () => context.push('/admin/users/${o.id}'),
          child: Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminColors.surfaceContainer,
              borderRadius: AdminRadius.xl,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AdminColors.primary,
                  child: Text(
                    o.name.isNotEmpty ? o.name.substring(0, 1).toUpperCase() : '?',
                    style: AdminTypography.titleSm,
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.name,
                        style: AdminTypography.titleMd
                            .copyWith(color: AdminColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        o.email,
                        style: AdminTypography.bodySm.copyWith(
                          color: AdminColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${o.publicId} • '
                        '${o.companyName ?? 'No company'}'
                        '${o.companyPublicId != null ? ' (${o.companyPublicId})' : ''}',
                        style: AdminTypography.bodySm.copyWith(
                          color: AdminColors.onSurfaceMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AdminBadge(
                      label: o.isDisabled ? 'DISABLED' : o.status,
                      color: o.isDisabled
                          ? AdminColors.danger
                          : o.status == 'ACTIVE'
                              ? AdminColors.success
                              : AdminColors.warning,
                    ),
                    if (o.companyId != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(top: AdminSpacing.xs),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AdminColors.primary,
                          textStyle: AdminTypography.labelSm,
                        ),
                        onPressed: () =>
                            context.push('/admin/subscriptions/${o.companyId}'),
                        child: const Text('Subscription'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
