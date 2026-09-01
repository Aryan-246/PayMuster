import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_api_client.dart';
import '../data/admin_models.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

/// Notifications — inbox/history ONLY. The single authoritative announcement
/// compose workflow lives on the Announcements screen (compose → preview →
/// dispatch). This screen shows the notification log: what was dispatched,
/// to whom, and when. No duplicated composer, no duplicated business logic.
class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  List<AdminNotification> _notifications = [];
  bool _isLoading = true;
  int _fetchGeneration = 0;
  String? _error;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(
          'Notifications ($_total)',
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.md,
                AdminSpacing.md,
                AdminSpacing.md,
                AdminSpacing.sm,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Text(
                  'Inbox and dispatch history. To send a new announcement, use '
                  'Compose on the Announcements screen.',
                  style: AdminTypography.bodySm
                      .copyWith(color: AdminColors.onSurfaceVariant),
                ),
              ),
            ),
          ),
          ..._buildLogSlivers(),
        ],
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
            message: 'No system notifications have been dispatched yet. '
                'Announcements you compose appear here in the log.',
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
