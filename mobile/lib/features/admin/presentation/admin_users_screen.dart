import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/admin_tokens.dart';
import '../../../../components/foundation/pm_text_input.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'admin_users_refresh_provider.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  final String? initialRole;
  final String? initialStatus;

  const AdminUsersScreen({super.key, this.initialRole, this.initialStatus});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  List<AdminUser> _users = [];
  bool _isLoading = true;
  String? _error;
  String _selectedRole = 'ALL';
  String _selectedStatus = 'ALL';
  int _page = 1;
  int _totalPages = 1;
  int _totalUsers = 0;
  int _fetchGeneration = 0;
  ProviderSubscription<int>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'ALL';
    _selectedStatus = widget.initialStatus ?? 'ALL';
    _refreshSubscription = ref.listenManual<int>(adminUsersRefreshProvider, (
      previous,
      next,
    ) {
      if (previous != next && mounted) _fetchUsers();
    });
    _fetchUsers();
  }

  @override
  void didUpdateWidget(covariant AdminUsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRole == oldWidget.initialRole &&
        widget.initialStatus == oldWidget.initialStatus) {
      return;
    }

    _selectedRole = widget.initialRole ?? 'ALL';
    _selectedStatus = widget.initialStatus ?? 'ALL';
    _page = 1;
    _fetchUsers();
  }

  @override
  void dispose() {
    _refreshSubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(adminApiClientProvider)
          .getUsers(
            query: _searchController.text.trim(),
            role: _selectedRole,
            status: _selectedStatus,
            page: _page,
          );

      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _users = res['users'] as List<AdminUser>;
        _totalUsers = res['total'] as int;
        _totalPages = res['totalPages'] as int;
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
          'User Management ($_totalUsers)',
          style: AdminTypography.titleMd.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AdminSpacing.md),
            color: surfaceColor,
            child: Column(
              children: [
                PMTextInput(
                  labelText: 'Search by name, email, phone or Public ID',
                  controller: _searchController,
                  onChanged: (val) {
                    _page = 1;
                    _fetchUsers();
                  },
                  suffixIcon: const Icon(Icons.search),
                ),
                const SizedBox(height: AdminSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Role: ALL', 'ALL', _selectedRole, (r) {
                        setState(() => _selectedRole = r);
                        _fetchUsers();
                      }),
                      _buildFilterChip('OWNER', 'OWNER', _selectedRole, (r) {
                        setState(() => _selectedRole = r);
                        _fetchUsers();
                      }),
                      _buildFilterChip('ADMIN', 'ADMIN', _selectedRole, (r) {
                        setState(() => _selectedRole = r);
                        _fetchUsers();
                      }),
                      _buildFilterChip(
                        'SUPERVISOR',
                        'SUPERVISOR',
                        _selectedRole,
                        (r) {
                          setState(() => _selectedRole = r);
                          _fetchUsers();
                        },
                      ),
                      _buildFilterChip(
                        'ACCOUNTANT',
                        'ACCOUNTANT',
                        _selectedRole,
                        (r) {
                          setState(() => _selectedRole = r);
                          _fetchUsers();
                        },
                      ),
                      _buildFilterChip('STAFF', 'STAFF', _selectedRole, (r) {
                        setState(() => _selectedRole = r);
                        _fetchUsers();
                      }),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 24,
                        color: AdminColors.glassBorder,
                      ),
                      const SizedBox(width: 12),
                      _buildFilterChip('Status: ALL', 'ALL', _selectedStatus, (
                        s,
                      ) {
                        setState(() => _selectedStatus = s);
                        _fetchUsers();
                      }),
                      _buildFilterChip('ACTIVE', 'ACTIVE', _selectedStatus, (
                        s,
                      ) {
                        setState(() => _selectedStatus = s);
                        _fetchUsers();
                      }),
                      _buildFilterChip('BLOCKED', 'BLOCKED', _selectedStatus, (
                        s,
                      ) {
                        setState(() => _selectedStatus = s);
                        _fetchUsers();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AdminLoadingState()
                : _error != null
                ? AdminErrorState(error: _error!, onRetry: _fetchUsers)
                : _users.isEmpty
                ? const AdminEmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'No Users Found',
                    message: 'No users matched your search criteria.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final u = _users[index];
                      return _buildUserCard(
                        context,
                        u,
                        textColor,
                        surfaceColor,
                      );
                    },
                  ),
          ),
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _fetchUsers();
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous'),
                  ),
                  Text(
                    'Page $_page of $_totalPages',
                    style: AdminTypography.bodySm.copyWith(color: textColor),
                  ),
                  TextButton.icon(
                    onPressed: _page < _totalPages
                        ? () {
                            setState(() => _page++);
                            _fetchUsers();
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentSelected,
    Function(String) onSelect,
  ) {
    final isSelected = currentSelected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? AdminColors.onPrimary : AdminColors.primary,
          ),
        ),
        selected: isSelected,
        selectedColor: AdminColors.primary,
        backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
        checkmarkColor: AdminColors.onPrimary,
        onSelected: (_) => onSelect(value),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    AdminUser u,
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
          backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
          child: Text(
            u.name.trim().isNotEmpty ? u.name.trim()[0].toUpperCase() : 'A',
            style: AdminTypography.headlineSm.copyWith(
              color: AdminColors.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                u.name,
                style: AdminTypography.titleMd.copyWith(color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            AdminBadge.role(u.role),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
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
                    u.publicId,
                    style: AdminTypography.labelMono.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    u.email,
                    style: AdminTypography.bodySm.copyWith(
                      color: AdminColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (u.companyName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.business,
                    size: 12,
                    color: AdminColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      u.companyName!,
                      style: AdminTypography.bodySm.copyWith(
                        color: AdminColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/users/${u.id}'),
      ),
    );
  }
}
