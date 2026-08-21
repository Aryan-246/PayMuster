import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/announcement_api.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(minutes: 1);
  static const _reconnectDelay = Duration(seconds: 10);

  final _acknowledgingIds = <String>{};
  StreamSubscription<AnnouncementInvalidation>? _invalidationSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh(silent: true));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _connectInvalidations(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(silent: true);
      _connectInvalidations();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _invalidationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    if (!silent) setState(() {});
    ref.invalidate(announcementsProvider);
    try {
      await ref.read(announcementsProvider.future);
    } catch (_) {
      // The provider retains the typed failure for the error state.
    } finally {
      _refreshing = false;
      if (!silent && mounted) setState(() {});
    }
  }

  void _connectInvalidations() {
    if (!mounted || _invalidationSubscription != null) return;
    _reconnectTimer?.cancel();
    _invalidationSubscription = ref
        .read(announcementApiProvider)
        .watchInvalidations()
        .listen(
          (_) => _refresh(silent: true),
          onError: (_) => _scheduleReconnect(),
          onDone: _scheduleReconnect,
        );
  }

  void _scheduleReconnect() {
    _invalidationSubscription?.cancel();
    _invalidationSubscription = null;
    if (!mounted || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(_reconnectDelay, _connectInvalidations);
  }

  Future<void> _acknowledge(Announcement announcement) async {
    if (announcement.isAcknowledged ||
        !_acknowledgingIds.add(announcement.id)) {
      return;
    }
    setState(() {});
    try {
      await ref.read(announcementApiProvider).acknowledge(announcement.id);
      await _refresh(silent: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error, acknowledgement: true))),
        );
      }
    } finally {
      _acknowledgingIds.remove(announcement.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? PMColors.bgPrimaryDark
        : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final notices = ref.watch(announcementsProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Notices',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh notices',
            onPressed: notices.isLoading || _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: notices.when(
        loading: () => const PMListSkeleton(itemCount: 4),
        error: (error, _) => _NoticesErrorState(
          message: _errorMessage(error),
          onRetry: _refresh,
        ),
        data: (page) => RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PMSpacing.s5,
                        PMSpacing.s5,
                        PMSpacing.s5,
                        PMSpacing.s3,
                      ),
                      child: _NoticeSummary(
                        total: page.total,
                        unread: page.unread,
                      ),
                    ),
                  ),
                ),
              ),
              if (page.announcements.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoticesEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    PMSpacing.s5,
                    0,
                    PMSpacing.s5,
                    PMSpacing.s8,
                  ),
                  sliver: SliverList.separated(
                    itemCount: page.announcements.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: PMSpacing.s3),
                    itemBuilder: (context, index) {
                      final announcement = page.announcements[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: _NoticeCard(
                            announcement: announcement,
                            acknowledging: _acknowledgingIds.contains(
                              announcement.id,
                            ),
                            onAcknowledge: () => _acknowledge(announcement),
                            onOpen: announcement.deepLink == null
                                ? null
                                : () => context.push(announcement.deepLink!),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error, {bool acknowledgement = false}) {
    if (error is AnnouncementApiException) return error.message;
    return acknowledgement
        ? 'The notice could not be acknowledged. Please try again.'
        : 'Notices could not be loaded. Please try again.';
  }
}

class _NoticeSummary extends StatelessWidget {
  const _NoticeSummary({required this.total, required this.unread});

  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent = isDark
        ? PMColors.brandPrimaryDark
        : PMColors.brandPrimaryLight;

    return PMCard.stat(
      accentColor: accent,
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: accent),
          const SizedBox(width: PMSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0 ? 'You are up to date' : '$unread unread',
                  style: PMTypography.headline.copyWith(color: textColor),
                ),
                Text(
                  '$total ${total == 1 ? 'notice' : 'notices'} available',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.announcement,
    required this.acknowledging,
    required this.onAcknowledge,
    this.onOpen,
  });

  final Announcement announcement;
  final bool acknowledging;
  final VoidCallback onAcknowledge;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent = isDark
        ? PMColors.brandPrimaryDark
        : PMColors.brandPrimaryLight;
    final border = isDark
        ? PMColors.borderDefaultDark
        : PMColors.borderDefaultLight;

    return Semantics(
      label: announcement.isAcknowledged
          ? 'Acknowledged notice'
          : 'Unread notice',
      child: PMCard.standard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: announcement.isAcknowledged
                        ? Colors.transparent
                        : accent.withValues(alpha: 0.12),
                    border: Border.all(color: border),
                    borderRadius: PMRadius.sm,
                  ),
                  child: Icon(
                    announcement.isAcknowledged
                        ? Icons.notifications_none_outlined
                        : Icons.campaign_outlined,
                    color: announcement.isAcknowledged ? secondary : accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: PMSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: PMTypography.headline.copyWith(color: textColor),
                      ),
                      const SizedBox(height: PMSpacing.s1),
                      Text(
                        _formatDateTime(announcement.createdAt),
                        style: PMTypography.caption.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
                if (!announcement.isAcknowledged)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: PMSpacing.s4),
            Text(
              announcement.body,
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s4),
            LayoutBuilder(
              builder: (context, constraints) {
                final acknowledge = announcement.isAcknowledged
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: secondary,
                          ),
                          const SizedBox(width: PMSpacing.s2),
                          Flexible(
                            child: Text(
                              'Acknowledged ${_formatDateTime(announcement.acknowledgedAt!)}',
                              style: PMTypography.caption.copyWith(
                                color: secondary,
                              ),
                            ),
                          ),
                        ],
                      )
                    : PMButton.primary(
                        key: ValueKey('acknowledge-${announcement.id}'),
                        label: 'Acknowledge',
                        icon: Icons.check,
                        isLoading: acknowledging,
                        onPressed: acknowledging ? null : onAcknowledge,
                      );
                final open = onOpen == null
                    ? null
                    : PMButton.secondary(
                        label: 'Open',
                        icon: Icons.open_in_new,
                        onPressed: onOpen,
                      );

                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (open != null) ...[
                        open,
                        const SizedBox(height: PMSpacing.s2),
                      ],
                      acknowledge,
                    ],
                  );
                }
                return Row(
                  children: [
                    ?open,
                    const Spacer(),
                    Flexible(child: acknowledge),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticesEmptyState extends StatelessWidget {
  const _NoticesEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'No notices',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'New notices will appear here.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticesErrorState extends StatelessWidget {
  const _NoticesErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $period';
}
