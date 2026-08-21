import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/announcements/data/announcement_api.dart';

class AnnouncementCoordinator extends ConsumerStatefulWidget {
  const AnnouncementCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnnouncementCoordinator> createState() =>
      _AnnouncementCoordinatorState();
}

class _AnnouncementCoordinatorState
    extends ConsumerState<AnnouncementCoordinator>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(minutes: 1);
  static const _reconnectDelay = Duration(seconds: 10);

  StreamSubscription<AnnouncementInvalidation>? _subscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  final _shownThisSession = <String>{};
  bool _loading = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshAndPresent());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectInvalidations();
      _refreshAndPresent();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectInvalidations();
      _refreshAndPresent();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _connectInvalidations() {
    if (!mounted || _subscription != null) return;
    _reconnectTimer?.cancel();
    _subscription = ref
        .read(announcementApiProvider)
        .watchInvalidations()
        .listen(
          (_) => _refreshAndPresent(),
          onError: (_) => _scheduleReconnect(),
          onDone: _scheduleReconnect,
        );
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    if (!mounted || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(_reconnectDelay, _connectInvalidations);
  }

  Future<void> _refreshAndPresent() async {
    if (_loading || !mounted) return;
    _loading = true;
    try {
      final page = await ref
          .read(announcementApiProvider)
          .listAnnouncements(limit: 100);
      if (!mounted || _dialogVisible) return;
      final unread = page.announcements.where(
        (announcement) =>
            !announcement.isAcknowledged &&
            !_shownThisSession.contains(announcement.id),
      );
      if (unread.isEmpty) return;
      _shownThisSession.add(unread.first.id);
      await _showPopup(unread.first);
    } catch (_) {
      // NoticesScreen remains the durable error/retry surface. Popup delivery
      // retries on the next SSE invalidation, poll, or app resume.
    } finally {
      _loading = false;
    }
  }

  Future<void> _showPopup(Announcement announcement) async {
    if (!mounted || _dialogVisible) return;
    _dialogVisible = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var acknowledging = false;
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Row(
                children: [
                  Icon(_iconForType(announcement.type)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(announcement.title)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.type,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(announcement.body),
                  ],
                ),
              ),
              actions: [
                if (announcement.deepLink != null)
                  TextButton(
                    onPressed: acknowledging
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            context.push(announcement.deepLink!);
                          },
                    child: const Text('Open'),
                  ),
                FilledButton(
                  onPressed: acknowledging
                      ? null
                      : () async {
                          setState(() => acknowledging = true);
                          try {
                            final result = await ref
                                .read(announcementApiProvider)
                                .acknowledge(announcement.id);
                            if (!result.changed && !mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (error) {
                            if (context.mounted) {
                              setState(() => acknowledging = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error is AnnouncementApiException
                                        ? error.message
                                        : 'The notice could not be acknowledged. Please try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: acknowledging
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Acknowledge'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogVisible = false;
    }
  }

  IconData _iconForType(String type) {
    return switch (type.toUpperCase()) {
      'EMERGENCY' => Icons.warning_amber_rounded,
      'WARNING' => Icons.warning_outlined,
      'MEETING' => Icons.groups_outlined,
      'HOLIDAY' => Icons.celebration_outlined,
      _ => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
