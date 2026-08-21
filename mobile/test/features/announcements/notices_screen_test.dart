import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/components/feedback/pm_list_skeleton.dart';
import 'package:paymuster_mobile/features/announcements/data/announcement_api.dart';
import 'package:paymuster_mobile/features/announcements/presentation/notices_screen.dart';

class _FakeAnnouncementDataSource implements AnnouncementDataSource {
  _FakeAnnouncementDataSource({required this.page});

  AnnouncementPage page;
  Object? listError;
  Object? acknowledgementError;
  Completer<void>? listGate;
  Completer<void>? acknowledgementGate;
  int listCalls = 0;
  int acknowledgementCalls = 0;
  final invalidations = StreamController<AnnouncementInvalidation>();

  @override
  Future<AnnouncementPage> listAnnouncements({
    int page = 1,
    int limit = 50,
  }) async {
    listCalls += 1;
    await listGate?.future;
    if (listError case final error?) throw error;
    return this.page;
  }

  @override
  Future<AnnouncementAcknowledgement> acknowledge(String announcementId) async {
    acknowledgementCalls += 1;
    await acknowledgementGate?.future;
    if (acknowledgementError case final error?) throw error;
    final acknowledgedAt = DateTime.parse('2026-08-17T12:30:00.000Z');
    page = AnnouncementPage(
      announcements: page.announcements
          .map(
            (notice) => notice.id == announcementId
                ? Announcement(
                    id: notice.id,
                    title: notice.title,
                    type: notice.type,
                    body: notice.body,
                    createdAt: notice.createdAt,
                    deepLink: notice.deepLink,
                    acknowledgedAt: acknowledgedAt,
                  )
                : notice,
          )
          .toList(),
      total: page.total,
      unread: page.unread > 0 ? page.unread - 1 : 0,
      page: page.page,
      totalPages: page.totalPages,
    );
    return AnnouncementAcknowledgement(
      id: announcementId,
      acknowledgedAt: acknowledgedAt,
      changed: true,
    );
  }

  @override
  Stream<AnnouncementInvalidation> watchInvalidations() => invalidations.stream;

  Future<void> close() => invalidations.close();
}

AnnouncementPage _page({List<Announcement> announcements = const []}) {
  return AnnouncementPage(
    announcements: announcements,
    total: announcements.length,
    unread: announcements.where((notice) => !notice.isAcknowledged).length,
    page: 1,
    totalPages: 1,
  );
}

Announcement _notice({DateTime? acknowledgedAt}) {
  return Announcement(
    id: 'notice-1',
    title: 'Payroll window',
    body: 'Payroll closes Friday at 5 PM.',
    type: 'INFORMATION',
    deepLink: '/app/payroll',
    acknowledgedAt: acknowledgedAt,
    createdAt: DateTime.parse('2026-08-17T12:00:00.000Z'),
  );
}

Widget _screenWith(_FakeAnnouncementDataSource api) {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [announcementApiProvider.overrideWithValue(api)],
    child: const MaterialApp(home: NoticesScreen()),
  );
}

void main() {
  testWidgets('shows loading then empty persisted state', (tester) async {
    final gate = Completer<void>();
    final api = _FakeAnnouncementDataSource(page: _page())..listGate = gate;
    addTearDown(api.close);

    await tester.pumpWidget(_screenWith(api));
    expect(find.byType(PMListSkeleton), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('No notices'), findsOneWidget);
    expect(find.text('0 notices available'), findsOneWidget);
  });

  testWidgets('shows typed list failure and supports retry', (tester) async {
    final api = _FakeAnnouncementDataSource(page: _page())
      ..listError = const AnnouncementApiException(
        'Notices are temporarily unavailable.',
        code: 'TEMPORARY_FAILURE',
      );
    addTearDown(api.close);

    await tester.pumpWidget(_screenWith(api));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Notices are temporarily unavailable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    api.listError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('No notices'), findsOneWidget);
    expect(api.listCalls, 2);
  });

  testWidgets('renders unread and acknowledged notices distinctly', (
    tester,
  ) async {
    final api = _FakeAnnouncementDataSource(
      page: _page(
        announcements: [
          _notice(),
          Announcement(
            id: 'notice-2',
            title: 'Policy update',
            body: 'The revised policy is available.',
            type: 'INFORMATION',
            acknowledgedAt: DateTime.parse('2026-08-17T12:10:00.000Z'),
            createdAt: DateTime.parse('2026-08-17T11:00:00.000Z'),
          ),
        ],
      ),
    );
    addTearDown(api.close);

    await tester.pumpWidget(_screenWith(api));
    await tester.pump();
    await tester.pump();

    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Payroll window'), findsOneWidget);
    expect(find.text('Acknowledge'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Policy update'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Policy update'), findsOneWidget);
    expect(find.textContaining('Acknowledged Aug 17, 2026'), findsOneWidget);
  });

  testWidgets(
    'prevents duplicate acknowledgement and refetches durable state',
    (tester) async {
      final gate = Completer<void>();
      final api = _FakeAnnouncementDataSource(
        page: _page(announcements: [_notice()]),
      )..acknowledgementGate = gate;
      addTearDown(api.close);

      await tester.pumpWidget(_screenWith(api));
      await tester.pump();

      final button = find.byKey(const ValueKey('acknowledge-notice-1'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      expect(api.acknowledgementCalls, 1);
      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(api.listCalls, 2);
      expect(find.text('You are up to date'), findsOneWidget);
      expect(find.textContaining('Acknowledged Aug 17, 2026'), findsOneWidget);
    },
  );

  testWidgets('keeps unread state and reports acknowledgement failure', (
    tester,
  ) async {
    final api =
        _FakeAnnouncementDataSource(page: _page(announcements: [_notice()]))
          ..acknowledgementError = const AnnouncementApiException(
            'Acknowledgement was rejected.',
            code: 'ACKNOWLEDGEMENT_REJECTED',
          );
    addTearDown(api.close);

    await tester.pumpWidget(_screenWith(api));
    await tester.pump();
    await tester.tap(find.text('Acknowledge'));
    await tester.pump();

    expect(find.text('Acknowledgement was rejected.'), findsOneWidget);
    expect(find.text('Acknowledge'), findsOneWidget);
    expect(api.listCalls, 1);
  });
}
