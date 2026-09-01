import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Announcements admin — the SINGLE authoritative compose workflow
/// (latest directive #4/#6): compose → audience → preview recipients →
/// dispatch → result, plus platform campaign history with delivery and
/// acknowledgement counts. The notifications screen is inbox/history only
/// and intentionally contains no composer.
class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends ConsumerState<AdminAnnouncementsScreen> {
  final _searchController = TextEditingController();
  List<AdminAnnouncementCampaign> _campaigns = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
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
        _campaigns = [];
      }
    });

    try {
      final result = await ref.read(adminApiClientProvider).getAnnouncementsAdmin(
            search: _search.isNotEmpty ? _search : null,
            page: reset ? 1 : _page,
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final rows = result['announcements'] as List<AdminAnnouncementCampaign>;
        _campaigns = reset ? rows : [..._campaigns, ...rows];
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

  Future<void> _openComposer() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const AdminAnnouncementComposerScreen(),
      ),
    );
    if (mounted) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading && _campaigns.isEmpty
        ? const AdminLoadingState()
        : _error != null && _campaigns.isEmpty
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
                        hintText: 'Search title, body or company…',
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
                    const SizedBox(height: AdminSpacing.md),
                    if (_campaigns.isEmpty && !_isLoading)
                      const AdminEmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'No announcements yet',
                        message:
                            'Use the compose button to dispatch platform-wide or '
                            'company-targeted announcements. Dispatched campaigns '
                            'appear here with recipient and acknowledgement counts.',
                      )
                    else
                      ..._campaigns.map(_buildCampaignCard),
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
                    if (_error != null && _campaigns.isNotEmpty)
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
        title: const Text('Announcements'),
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('compose-announcement-button'),
        onPressed: _openComposer,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Compose'),
        backgroundColor: AdminColors.primary,
        foregroundColor: AdminColors.onPrimary,
      ),
      body: body,
    );
  }

  Widget _buildCampaignCard(AdminAnnouncementCampaign c) {
    final ack = c.acknowledgementCount ?? 0;
    final ackRatio = c.recipientCount > 0 ? ack / c.recipientCount : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Container(
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
                const Icon(Icons.campaign_outlined,
                    color: AdminColors.primary, size: 20),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    c.title,
                    style: AdminTypography.titleMd
                        .copyWith(color: AdminColors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AdminBadge(
                  label: c.type,
                  color: AdminColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              c.body,
              style: AdminTypography.bodySm
                  .copyWith(color: AdminColors.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              'Audience: ${c.audience} • ${c.recipientCount} recipient'
              '${c.recipientCount == 1 ? '' : 's'}'
              '${c.orgName != null ? ' • ${c.orgName}' : ' • Platform'}'
              '${c.actorName != null ? ' • by ${c.actorName}' : ''}',
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmt(c.createdAt),
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceMuted,
              ),
            ),
            if (c.recipientCount > 0) ...[
              const SizedBox(height: AdminSpacing.sm),
              ClipRRect(
                borderRadius: AdminRadius.full,
                child: LinearProgressIndicator(
                  value: ackRatio,
                  minHeight: 4,
                  backgroundColor: AdminColors.surfaceContainerHigh,
                  valueColor:
                      const AlwaysStoppedAnimation(AdminColors.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$ack of ${c.recipientCount} acknowledged'
                '${ackRatio >= 1.0 ? ' — fully acknowledged' : ''}',
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer — the single authoritative announcement workflow.
// ---------------------------------------------------------------------------

class AdminAnnouncementComposerScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementComposerScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementComposerScreen> createState() =>
      _AdminAnnouncementComposerScreenState();
}

class _AdminAnnouncementComposerScreenState
    extends ConsumerState<AdminAnnouncementComposerScreen> {
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _orgIdController = TextEditingController();
  final _audienceUserIdController = TextEditingController();
  final _deepLinkController = TextEditingController();

  String _audience = 'SYSTEM';
  String _announcementType = 'INFORMATION';
  String _audienceRole = 'STAFF';
  AnnouncementPreview? _preview;
  bool _isPreviewing = false;
  bool _isDispatching = false;
  String? _error;
  AnnouncementDispatchResult? _result;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _orgIdController.dispose();
    _audienceUserIdController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  AnnouncementDispatchRequest get _request => AnnouncementDispatchRequest(
        title: _titleController.text,
        body: _bodyController.text,
        type: _announcementType,
        audience: _audience,
        orgId: _audience == 'ORGANIZATION' || _audience == 'ROLE'
            ? _orgIdController.text
            : null,
        audienceRole: _audience == 'ROLE' ? _audienceRole : null,
        audienceUserId:
            _audience == 'USER' ? _audienceUserIdController.text : null,
        deepLink: _deepLinkController.text,
      );

  bool get _formValid {
    if (_titleController.text.trim().length < 2 ||
        _bodyController.text.trim().length < 2) {
      return false;
    }
    if ((_audience == 'ORGANIZATION' || _audience == 'ROLE') &&
        !_uuidPattern.hasMatch(_orgIdController.text.trim())) {
      return false;
    }
    if (_audience == 'USER' &&
        !_uuidPattern.hasMatch(_audienceUserIdController.text.trim())) {
      return false;
    }
    final link = _deepLinkController.text.trim();
    if (link.isNotEmpty &&
        (!link.startsWith('/app/') || link.startsWith('//'))) {
      return false;
    }
    return true;
  }

  Future<void> _previewRecipients() async {
    if (_isPreviewing || !_formValid) return;
    setState(() {
      _isPreviewing = true;
      _error = null;
      _result = null;
    });
    try {
      final preview =
          await ref.read(adminApiClientProvider).previewAnnouncement(_request);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _isPreviewing = false);
    }
  }

  Future<void> _dispatch() async {
    if (_isDispatching) return;
    final preview = _preview;
    if (preview == null) {
      // Require a fresh server-side preview before dispatch so the admin
      // always confirms against the real recipient count.
      await _previewRecipients();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surfaceContainerHigh,
        title: Text('Dispatch announcement?',
            style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface)),
        content: Text(
          'This will notify ${preview.recipientCount} '
          '${preview.recipientCount == 1 ? 'recipient' : 'recipients'} '
          'immediately. The dispatch is audited and each recipient is notified '
          'in-app.',
          style: AdminTypography.bodyMd
              .copyWith(color: AdminColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dispatch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isDispatching = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(adminApiClientProvider).dispatchAnnouncement(_request);
      if (!mounted) return;
      setState(() => _result = result);
      _titleController.clear();
      _bodyController.clear();
      _deepLinkController.clear();
      _orgIdController.clear();
      _audienceUserIdController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Compose announcement'),
        backgroundColor: AdminColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(AdminSpacing.md),
              children: [
                if (_result != null) ...[
                  _buildResultCard(_result!),
                  const SizedBox(height: AdminSpacing.md),
                ],
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const Key('announcement-title-field'),
                        controller: _titleController,
                        enabled: !_isDispatching,
                        maxLength: 120,
                        inputFormatters: [LengthLimitingTextInputFormatter(120)],
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Announcement title',
                        ),
                        validator: (value) => _boundedRequired(
                          value,
                          field: 'Title',
                          minimum: 2,
                          maximum: 120,
                        ),
                        onChanged: (_) => _invalidateDerived(),
                      ),
                      const SizedBox(height: AdminSpacing.sm),
                      TextFormField(
                        key: const Key('announcement-body-field'),
                        controller: _bodyController,
                        enabled: !_isDispatching,
                        maxLength: 2000,
                        maxLines: 6,
                        minLines: 3,
                        inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => _boundedRequired(
                          value,
                          field: 'Message',
                          minimum: 2,
                          maximum: 2000,
                        ),
                        onChanged: (_) => _invalidateDerived(),
                      ),
                      const SizedBox(height: AdminSpacing.sm),
                      Text(
                        'Announcement type',
                        style: AdminTypography.labelSm.copyWith(
                          color: AdminColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.sm),
                      DropdownButtonFormField<String>(
                        key: const Key('announcement-type-control'),
                        initialValue: _announcementType,
                        items: const [
                          DropdownMenuItem(
                              value: 'INFORMATION', child: Text('Information')),
                          DropdownMenuItem(
                              value: 'WARNING', child: Text('Warning')),
                          DropdownMenuItem(
                              value: 'EMERGENCY', child: Text('Emergency')),
                          DropdownMenuItem(value: 'MEETING', child: Text('Meeting')),
                          DropdownMenuItem(value: 'HOLIDAY', child: Text('Holiday')),
                        ],
                        onChanged: _isDispatching
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _announcementType = value);
                                }
                              },
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      Text(
                        'Audience',
                        style: AdminTypography.labelSm.copyWith(
                          color: AdminColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.sm),
                      SegmentedButton<String>(
                        key: const Key('announcement-audience-control'),
                        segments: const [
                          ButtonSegment(
                            value: 'SYSTEM',
                            label: Text('System'),
                            icon: Icon(Icons.public),
                          ),
                          ButtonSegment(
                            value: 'ORGANIZATION',
                            label: Text('Organization'),
                            icon: Icon(Icons.business_outlined),
                          ),
                          ButtonSegment(
                            value: 'ROLE',
                            label: Text('Role'),
                            icon: Icon(Icons.badge_outlined),
                          ),
                          ButtonSegment(
                            value: 'USER',
                            label: Text('User'),
                            icon: Icon(Icons.person_outline),
                          ),
                        ],
                        selected: {_audience},
                        onSelectionChanged: _isDispatching
                            ? null
                            : (selection) {
                                setState(() {
                                  _audience = selection.single;
                                  if (_audience == 'SYSTEM' ||
                                      _audience == 'USER') {
                                    _orgIdController.clear();
                                  }
                                  if (_audience != 'USER') {
                                    _audienceUserIdController.clear();
                                  }
                                  // Audience change invalidates any preview.
                                  _preview = null;
                                });
                              },
                      ),
                      if (_audience == 'ORGANIZATION' || _audience == 'ROLE') ...[
                        const SizedBox(height: AdminSpacing.md),
                        TextFormField(
                          key: const Key('announcement-org-id-field'),
                          controller: _orgIdController,
                          enabled: !_isDispatching,
                          decoration: const InputDecoration(
                            labelText: 'Organization ID',
                            hintText: '00000000-0000-0000-0000-000000000000',
                          ),
                          validator: (value) {
                            final normalized = value?.trim() ?? '';
                            if (normalized.isEmpty) {
                              return 'Organization ID is required.';
                            }
                            if (!_uuidPattern.hasMatch(normalized)) {
                              return 'Enter a valid organization UUID.';
                            }
                            return null;
                          },
                          onChanged: (_) => _invalidateDerived(),
                        ),
                      ],
                      if (_audience == 'ROLE') ...[
                        const SizedBox(height: AdminSpacing.md),
                        DropdownButtonFormField<String>(
                          key: const Key('announcement-role-control'),
                          initialValue: _audienceRole,
                          items: const [
                            DropdownMenuItem(value: 'OWNER', child: Text('Owner')),
                            DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                            DropdownMenuItem(
                              value: 'SUPERVISOR',
                              child: Text('Supervisor'),
                            ),
                            DropdownMenuItem(
                              value: 'ACCOUNTANT',
                              child: Text('Accountant'),
                            ),
                            DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                            DropdownMenuItem(
                                value: 'VIEWER', child: Text('Viewer')),
                          ],
                          onChanged: _isDispatching
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _audienceRole = value);
                                  }
                                },
                        ),
                      ],
                      if (_audience == 'USER') ...[
                        const SizedBox(height: AdminSpacing.md),
                        TextFormField(
                          key: const Key('announcement-user-id-field'),
                          controller: _audienceUserIdController,
                          enabled: !_isDispatching,
                          decoration: const InputDecoration(
                            labelText: 'Target user ID',
                            hintText: '00000000-0000-0000-0000-000000000000',
                          ),
                          validator: (value) {
                            if (_audience != 'USER') return null;
                            final normalized = value?.trim() ?? '';
                            if (!_uuidPattern.hasMatch(normalized)) {
                              return 'Enter a valid user UUID.';
                            }
                            return null;
                          },
                          onChanged: (_) => _invalidateDerived(),
                        ),
                      ],
                      const SizedBox(height: AdminSpacing.md),
                      TextFormField(
                        key: const Key('announcement-deep-link-field'),
                        controller: _deepLinkController,
                        enabled: !_isDispatching,
                        maxLength: 300,
                        inputFormatters: [LengthLimitingTextInputFormatter(300)],
                        decoration: const InputDecoration(
                          labelText: 'Internal link (optional)',
                          hintText: '/app/notices',
                        ),
                        validator: (value) {
                          final normalized = value?.trim() ?? '';
                          if (normalized.isEmpty) return null;
                          if (!normalized.startsWith('/app/') ||
                              normalized.startsWith('//')) {
                            return 'Enter an internal /app/ path.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AdminSpacing.md),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AdminSpacing.md),
                      decoration: BoxDecoration(
                        color: AdminColors.errorContainer.withValues(alpha: 0.6),
                        borderRadius: AdminRadius.md,
                        border: Border.all(color: AdminColors.danger),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AdminColors.danger, size: 20),
                          const SizedBox(width: AdminSpacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AdminTypography.bodySm
                                  .copyWith(color: AdminColors.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_preview != null) ...[
                  _buildPreviewCard(_preview!),
                  const SizedBox(height: AdminSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('preview-announcement-button'),
                        onPressed:
                            (_isPreviewing || _isDispatching || !_formValid)
                                ? null
                                : _previewRecipients,
                        icon: _isPreviewing
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.group_outlined),
                        label: Text(_isPreviewing
                            ? 'Previewing…'
                            : 'Preview recipients'),
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('dispatch-announcement-button'),
                        onPressed:
                            (_isDispatching || !_formValid) ? null : _dispatch,
                        icon: _isDispatching
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                            _isDispatching ? 'Dispatching…' : 'Dispatch'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.primary,
                          foregroundColor: AdminColors.onPrimary,
                        ),
                      ),
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

  /// Any edit to the audience/content invalidates a previously fetched
  /// preview (the count shown must always match what would be dispatched)
  /// and rebuilds the action buttons against the current form validity.
  void _invalidateDerived() {
    setState(() => _preview = null);
  }

  Widget _buildPreviewCard(AnnouncementPreview preview) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.secondary.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(
          color: AdminColors.secondary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined,
                  color: AdminColors.secondary, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: Text(
                  '${preview.recipientCount} '
                  '${preview.recipientCount == 1 ? 'recipient' : 'recipients'} '
                  'will be notified',
                  style: AdminTypography.titleMd
                      .copyWith(color: AdminColors.onSurface),
                ),
              ),
            ],
          ),
          if (preview.sampleRecipients.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.sm),
            Text(
              'Sample recipients (server-verified):',
              style: AdminTypography.labelSm
                  .copyWith(color: AdminColors.onSurfaceVariant),
            ),
            const SizedBox(height: AdminSpacing.xs),
            ...preview.sampleRecipients.take(5).map(
                  (r) => Text(
                    '• ${r.name}'
                    '${r.publicId != null ? ' (${r.publicId})' : ''}'
                    '${r.email != null && r.email!.isNotEmpty ? ' — ${r.email}' : ''}',
                    style: AdminTypography.bodySm
                        .copyWith(color: AdminColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            if (preview.sampleRecipients.length > 5)
              Text(
                '…and ${preview.sampleRecipients.length - 5} more sampled.',
                style: AdminTypography.bodySm
                    .copyWith(color: AdminColors.onSurfaceMuted),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(AnnouncementDispatchResult result) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.success.withValues(alpha: 0.08),
        borderRadius: AdminRadius.xl,
        border: Border.all(
          color: AdminColors.success.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AdminColors.success, size: 20),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: Text(
                  'Dispatched to ${result.recipientCount} '
                  '${result.recipientCount == 1 ? 'recipient' : 'recipients'}',
                  style: AdminTypography.titleMd
                      .copyWith(color: AdminColors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            'Campaign ${result.campaignId} • audience ${result.audience}'
            '${result.orgId != null ? ' • org ${result.orgId}' : ''}. '
            'Recipients are notified in-app; acknowledgements are tracked in '
            'the announcement history.',
            style: AdminTypography.bodySm
                .copyWith(color: AdminColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String? _boundedRequired(
    String? value, {
    required String field,
    required int minimum,
    required int maximum,
  }) {
    final length = value?.trim().length ?? 0;
    if (length < minimum) return '$field must be at least $minimum characters.';
    if (length > maximum) return '$field must be at most $maximum characters.';
    return null;
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
