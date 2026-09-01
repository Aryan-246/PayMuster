import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_api_client.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Site detail (latest directive #8): name, org, address, status, coordinates,
/// assigned workers, attendance count, creation/update info and metadata.
/// Real rows from GET /admin/sites/:id; workers link to their user detail.
class AdminSiteDetailScreen extends ConsumerStatefulWidget {
  const AdminSiteDetailScreen({super.key, required this.siteId});

  final String siteId;

  @override
  ConsumerState<AdminSiteDetailScreen> createState() =>
      _AdminSiteDetailScreenState();
}

class _AdminSiteDetailScreenState extends ConsumerState<AdminSiteDetailScreen> {
  Map<String, dynamic>? _site;
  bool _isLoading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() => _isLoading = _site == null);

    try {
      final site = await ref
          .read(adminApiClientProvider)
          .getSiteDetail(widget.siteId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _site = site;
        _isLoading = false;
        _error = null;
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
    final body = _isLoading
        ? const AdminLoadingState()
        : _error != null
            ? AdminErrorState(error: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AdminSpacing.md),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildInfoCard(),
                    const SizedBox(height: AdminSpacing.md),
                    _buildWorkersCard(),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Site detail'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildHeader() {
    final site = _site!;
    final org = site['org'] as Map<String, dynamic>? ?? const {};
    final counts = site['_count'] as Map<String, dynamic>? ?? const {};
    final attendance = (counts['attendanceRecords'] as num?)?.toInt() ?? 0;
    final assignments = (counts['siteAssignments'] as num?)?.toInt() ?? 0;
    final members = (counts['siteMembers'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainer,
        borderRadius: AdminRadius.xl,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  site['name'] as String? ?? 'Site',
                  style: AdminTypography.headlineSm
                      .copyWith(color: AdminColors.onSurface),
                ),
              ),
              AdminBadge.status((site['status'] as String? ?? '').toUpperCase()),
            ],
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            '${site['publicId'] as String? ?? '—'} • '
            '${org['name'] as String? ?? 'No company'}'
            '${org['publicId'] != null ? ' (${org['publicId']})' : ''}',
            style: AdminTypography.bodySm
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              Expanded(
                child: _statCell('Workers', assignments, AdminColors.primary),
              ),
              Expanded(child: _statCell('Members', members, AdminColors.secondary)),
              Expanded(child: _statCell('Attendance', attendance, AdminColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: AdminTypography.titleMd.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AdminTypography.bodySm
              .copyWith(color: AdminColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final site = _site!;
    final lat = (site['latitude'] as num?)?.toDouble();
    final lng = (site['longitude'] as num?)?.toDouble();
    final radius = (site['geoFenceRadius'] as num?)?.toInt();
    final start = site['startDate'] as String?;
    final end = site['expectedEndDate'] as String?;
    final createdAt = site['createdAt'] as String?;
    final updatedAt = site['updatedAt'] as String?;
    final clientId = site['clientId'] as String?;

    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainer,
        borderRadius: AdminRadius.xl,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Site information'),
          const SizedBox(height: AdminSpacing.sm),
          _infoRow(
            'Address',
            (site['address'] as String?)?.isNotEmpty == true
                ? site['address'] as String
                : 'No address recorded',
          ),
          _infoRow(
            'Coordinates',
            lat != null && lng != null
                ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                : 'Not recorded',
          ),
          if (radius != null) _infoRow('Geofence radius', '$radius m'),
          _infoRow('Client ID', clientId ?? '—'),
          _infoRow('Start date', start != null ? _fmt(start) : '—'),
          _infoRow(
            'Expected end',
            end != null ? _fmt(end) : 'Not scheduled',
          ),
          _infoRow('Created', createdAt != null ? _fmt(createdAt) : '—'),
          _infoRow('Last updated', updatedAt != null ? _fmt(updatedAt) : '—'),
        ],
      ),
    );
  }

  Widget _buildWorkersCard() {
    final site = _site!;
    final assignments =
        (site['siteAssignments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final members =
        (site['siteMembers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return Material(
      color: AdminColors.surfaceContainer,
      borderRadius: AdminRadius.xl,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSectionHeader(title: 'Assigned workers'),
          const SizedBox(height: AdminSpacing.sm),
          if (assignments.isEmpty)
            Text(
              'No workers are currently assigned to this site.',
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            )
          else
            ...assignments.map(
              (a) {
                final staff = a['staff'] as Map<String, dynamic>? ?? const {};
                final name =
                    '${staff['firstName'] as String? ?? ''} ${staff['lastName'] as String? ?? ''}'.trim();
                final assignedAt = a['assignedAt'] as String?;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AdminColors.primary.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.engineering_outlined,
                      size: 18,
                      color: AdminColors.primary,
                    ),
                  ),
                  title: Text(
                    name.isNotEmpty ? name : (staff['email'] as String? ?? '—'),
                    style: AdminTypography.titleSm
                        .copyWith(color: AdminColors.onSurface),
                  ),
                  subtitle: Text(
                    '${staff['publicId'] as String? ?? '—'}'
                    '${staff['phone'] != null ? ' • ${staff['phone']}' : ''}'
                    '${assignedAt != null ? ' • since ${_fmt(assignedAt)}' : ''}',
                    style: AdminTypography.bodySm
                        .copyWith(color: AdminColors.onSurfaceMuted),
                  ),
                  onTap: staff['id'] == null
                      ? null
                      : () => context.go('/admin/users/${staff['id']}'),
                );
              },
            ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.md),
            const AdminSectionHeader(title: 'Site members'),
            const SizedBox(height: AdminSpacing.sm),
            ...members.map(
              (m) {
                final user = m['user'] as Map<String, dynamic>? ?? const {};
                final name =
                    '${user['firstName'] as String? ?? ''} ${user['lastName'] as String? ?? ''}'.trim();
                final assignedAt = m['assignedAt'] as String?;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AdminColors.secondary,
                  ),
                  title: Text(
                    name.isNotEmpty ? name : (user['email'] as String? ?? '—'),
                    style: AdminTypography.titleSm
                        .copyWith(color: AdminColors.onSurface),
                  ),
                  subtitle: Text(
                    '${m['role'] as String? ?? '—'}'
                    '${user['publicId'] != null ? ' • ${user['publicId']}' : ''}'
                    '${assignedAt != null ? ' • since ${_fmt(assignedAt)}' : ''}',
                    style: AdminTypography.bodySm
                        .copyWith(color: AdminColors.onSurfaceMuted),
                  ),
                );
              },
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
