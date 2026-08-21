import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final _dispatchFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _orgIdController = TextEditingController();
  final _audienceUserIdController = TextEditingController();
  final _deepLinkController = TextEditingController();

  List<AdminNotification> _notifications = [];
  bool _isLoading = true;
  bool _isDispatching = false;
  int _fetchGeneration = 0;
  String _audience = 'SYSTEM';
  String _announcementType = 'INFORMATION';
  String _audienceRole = 'STAFF';
  String? _error;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _orgIdController.dispose();
    _audienceUserIdController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    final generation = ++_fetchGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref.read(adminApiClientProvider).getNotifications();
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _notifications = res['notifications'] as List<AdminNotification>;
        _total = res['total'] as int;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _error = _errorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _dispatchAnnouncement() async {
    if (_isDispatching || !_dispatchFormKey.currentState!.validate()) return;

    setState(() => _isDispatching = true);
    try {
      final result = await ref
          .read(adminApiClientProvider)
          .dispatchAnnouncement(
            AnnouncementDispatchRequest(
              title: _titleController.text,
              body: _bodyController.text,
              type: _announcementType,
              audience: _audience,
              orgId: _audience == 'ORGANIZATION' || _audience == 'ROLE'
                  ? _orgIdController.text
                  : null,
              audienceRole: _audience == 'ROLE' ? _audienceRole : null,
              audienceUserId: _audience == 'USER'
                  ? _audienceUserIdController.text
                  : null,
              deepLink: _deepLinkController.text,
            ),
          );
      if (!mounted) return;

      _titleController.clear();
      _bodyController.clear();
      _deepLinkController.clear();
      _orgIdController.clear();
      _audienceUserIdController.clear();
      setState(() {
        _audience = 'SYSTEM';
        _announcementType = 'INFORMATION';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Announcement dispatched to ${result.recipientCount} '
            '${result.recipientCount == 1 ? 'recipient' : 'recipients'}. '
            'Campaign ${result.campaignId}.',
          ),
        ),
      );
      await _fetchNotifications();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
          'Announcements ($_total)',
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        backgroundColor: AdminColors.surfaceContainer,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh notification log',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchNotifications,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildDispatchPanel()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.md,
                0,
                AdminSpacing.md,
                AdminSpacing.sm,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: const AdminSectionHeader(title: 'Notification log'),
              ),
            ),
          ),
          ..._buildLogSlivers(),
        ],
      ),
    );
  }

  Widget _buildDispatchPanel() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminColors.surfaceContainerLow,
              borderRadius: AdminRadius.md,
              border: Border.all(color: AdminColors.glassBorder),
            ),
            child: Form(
              key: _dispatchFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        size: 20,
                        color: AdminColors.primary,
                      ),
                      const SizedBox(width: AdminSpacing.sm),
                      Expanded(
                        child: Text(
                          'Dispatch announcement',
                          style: AdminTypography.titleMd.copyWith(
                            color: AdminColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.md),
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
                        value: 'INFORMATION',
                        child: Text('Information'),
                      ),
                      DropdownMenuItem(
                        value: 'WARNING',
                        child: Text('Warning'),
                      ),
                      DropdownMenuItem(
                        value: 'EMERGENCY',
                        child: Text('Emergency'),
                      ),
                      DropdownMenuItem(
                        value: 'MEETING',
                        child: Text('Meeting'),
                      ),
                      DropdownMenuItem(
                        value: 'HOLIDAY',
                        child: Text('Holiday'),
                      ),
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
                          value: 'VIEWER',
                          child: Text('Viewer'),
                        ),
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
                  const SizedBox(height: AdminSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      key: const Key('dispatch-announcement-button'),
                      onPressed: _isDispatching ? null : _dispatchAnnouncement,
                      icon: _isDispatching
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_isDispatching ? 'Dispatching' : 'Dispatch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: AdminColors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLogSlivers() {
    if (_isLoading) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: AdminLoadingState()),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AdminErrorState(error: _error!, onRetry: _fetchNotifications),
        ),
      ];
    }
    if (_notifications.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AdminEmptyState(
            icon: Icons.notifications_none_outlined,
            title: 'No notifications',
            message: 'No system notifications have been dispatched.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AdminSpacing.md,
          0,
          AdminSpacing.md,
          AdminSpacing.xl,
        ),
        sliver: SliverList.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _NotificationLogCard(
                  notification: _notifications[index],
                ),
              ),
            );
          },
        ),
      ),
    ];
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

class _NotificationLogCard extends StatelessWidget {
  const _NotificationLogCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      color: AdminColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: AdminRadius.md,
        side: BorderSide(color: AdminColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AdminSpacing.md),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AdminColors.info.withValues(alpha: 0.12),
          child: const Icon(
            Icons.notifications_active_outlined,
            color: AdminColors.info,
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: AdminTypography.titleSm.copyWith(
                  color: AdminColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            Text(
              notification.createdAt.length >= 10
                  ? notification.createdAt.substring(0, 10)
                  : notification.createdAt,
              style: AdminTypography.labelMono.copyWith(
                color: AdminColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AdminSpacing.xs),
            Text(
              notification.body,
              style: AdminTypography.bodySm.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              'Recipient: ${notification.userName ?? 'All'} '
              '${notification.companyName != null ? '(${notification.companyName})' : ''} '
              '• Type: ${notification.type}',
              style: AdminTypography.bodySm.copyWith(color: AdminColors.info),
            ),
          ],
        ),
      ),
    );
  }
}
