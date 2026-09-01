import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/notification_api.dart';

/// The recipient's notification center — GET /api/v1/notifications scoped to
/// the signed-in user inside their current company. Tapping a notification
/// marks it read and follows its deep link when it has one.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final _items = <AppNotification>[];
  int _unread = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  final _markingRead = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(notificationCenterApiProvider)
          .list(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _unread = page.unread;
        _page = page.page;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(notificationCenterApiProvider)
          .list(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _unread = page.unread;
        _page = page.page;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (_markingRead.add(notification.id)) {
      setState(() {});
      try {
        await ref
            .read(notificationCenterApiProvider)
            .markRead(notification.id);
        final index = _items.indexWhere((item) => item.id == notification.id);
        if (index >= 0) {
          final updated = _items[index];
          _items[index] = AppNotification(
            id: updated.id,
            title: updated.title,
            body: updated.body,
            type: updated.type,
            deepLink: updated.deepLink,
            readAt: DateTime.now(),
            createdAt: updated.createdAt,
          );
          _unread = (_unread - 1).clamp(0, _unread);
        }
        ref.invalidate(unreadNotificationCountProvider);
      } catch (_) {
        // Read state stays as-is on the server; the row still opens.
      } finally {
        _markingRead.remove(notification.id);
        if (mounted) setState(() {});
      }
    }
    final link = notification.deepLink;
    if (link != null && link.startsWith('/app/') && mounted) {
      context.push(link);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationCenterApiProvider).markAllRead();
      await _load();
      ref.invalidate(unreadNotificationCountProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message(error, action: true))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_unread > 0)
            TextButton(
              key: const Key('notifications-mark-all-read'),
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const PMListSkeleton(itemCount: 5)
          : _error != null
              ? _NotificationsErrorState(
                  message: _error!,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            _NotificationsEmptyState(),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            PMSpacing.s5,
                            PMSpacing.s5,
                            PMSpacing.s5,
                            PMSpacing.s8,
                          ),
                          itemCount:
                              _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: PMSpacing.s3),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return Padding(
                                padding: const EdgeInsets.all(PMSpacing.s4),
                                child: PMButton.secondary(
                                  label: 'Load more',
                                  icon: Icons.expand_more,
                                  isLoading: _isLoadingMore,
                                  onPressed: _loadMore,
                                ),
                              );
                            }
                            return _NotificationCard(
                              notification: _items[index],
                              onTap: () => _open(_items[index]),
                            );
                          },
                        ),
                ),
    );
  }

  String _message(Object error, {bool action = false}) {
    return action
        ? 'The notifications could not be updated. Please try again.'
        : 'Notifications could not be loaded. Please try again.';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent =
        isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;

    return PMCard.standard(
      child: InkWell(
        borderRadius: PMRadius.md,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: notification.isRead
                    ? Colors.transparent
                    : accent.withValues(alpha: 0.12),
                border: Border.all(
                  color: isDark
                      ? PMColors.borderDefaultDark
                      : PMColors.borderDefaultLight,
                ),
                borderRadius: PMRadius.sm,
              ),
              child: Icon(
                notification.deepLink == null
                    ? Icons.notifications_none_outlined
                    : Icons.open_in_new_outlined,
                color: notification.isRead ? secondary : accent,
                size: 20,
              ),
            ),
            const SizedBox(width: PMSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: PMTypography.headline.copyWith(
                      color: textColor,
                      fontWeight: notification.isRead
                          ? null
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  Text(
                    notification.body,
                    style: PMTypography.body.copyWith(color: textColor),
                  ),
                  const SizedBox(height: PMSpacing.s2),
                  Text(
                    _formatDateTime(notification.createdAt),
                    style: PMTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: PMSpacing.s2),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 48,
              color: secondary,
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'No notifications',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'Company announcements and activity updates will appear here.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: PMColors.statusDangerLight,
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s4),
            PMButton.secondary(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $period';
}
