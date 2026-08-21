import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/attendance/data/attendance_api.dart';
import 'package:paymuster_mobile/features/attendance/presentation/attendance_controller.dart';
import 'package:paymuster_mobile/features/sites/data/site_api.dart';

const _workerOne = SiteWorker(
  id: 'staff-1',
  publicId: 'STF-0001',
  firstName: 'Ravi',
  lastName: 'Kumar',
  workerType: 'FULL_TIME',
  status: 'ACTIVE',
);

const _workerTwo = SiteWorker(
  id: 'staff-2',
  publicId: 'STF-0002',
  firstName: 'Asha',
  lastName: 'Devi',
  workerType: 'CONTRACT',
  status: 'ACTIVE',
);

const _activeSite = SiteSummary(
  id: 'site-1',
  publicId: 'SITE-0001',
  name: 'North Tower',
  status: 'ACTIVE',
  workerCount: 2,
  workers: [_workerOne, _workerTwo],
  approvedExpenseTotal: 0,
);

const _plannedSite = SiteSummary(
  id: 'site-2',
  publicId: 'SITE-0002',
  name: 'Future Tower',
  status: 'PLANNED',
  workerCount: 0,
  workers: [],
  approvedExpenseTotal: 0,
);

AttendanceEntry _entry({
  required String staffId,
  required String status,
  DateTime? date,
}) {
  final worker = staffId == _workerOne.id ? _workerOne : _workerTwo;
  return AttendanceEntry(
    id: 'attendance-$staffId',
    staffId: staffId,
    siteId: _activeSite.id,
    date: date ?? DateTime.utc(2026, 8, 17),
    status: status,
    shiftType: 'REGULAR',
    staff: AttendanceStaff(
      id: worker.id,
      publicId: worker.publicId,
      firstName: worker.firstName,
      lastName: worker.lastName,
      workerType: worker.workerType,
      status: worker.status,
    ),
    site: const AttendanceSite(
      id: 'site-1',
      publicId: 'SITE-0001',
      name: 'North Tower',
    ),
  );
}

Map<String, dynamic> _entryJson() {
  return {
    'id': 'attendance-1',
    'staffId': 'staff-1',
    'siteId': 'site-1',
    'date': '2026-08-17T00:00:00.000Z',
    'status': 'present',
    'shiftType': 'regular',
    'staff': {
      'id': 'staff-1',
      'publicId': 'STF-0001',
      'firstName': 'Ravi',
      'lastName': 'Kumar',
      'workerType': 'FULL_TIME',
      'status': 'ACTIVE',
    },
    'site': {'id': 'site-1', 'publicId': 'SITE-0001', 'name': 'North Tower'},
    'markedBy': {'id': 'user-1', 'firstName': 'Meera', 'lastName': 'Patel'},
  };
}

class _FakeSiteApi extends SiteApi {
  _FakeSiteApi(Ref ref, this.sites) : super(TenantApiClient(ref));

  final List<SiteSummary> sites;
  int listCalls = 0;

  @override
  Future<List<SiteSummary>> listSites({String? status}) async {
    listCalls += 1;
    return sites;
  }
}

class _AttendanceRead {
  const _AttendanceRead(this.siteId, this.date);

  final String siteId;
  final DateTime date;
}

class _AttendanceCreate {
  const _AttendanceCreate(this.staffId, this.siteId, this.date, this.status);

  final String staffId;
  final String siteId;
  final DateTime date;
  final String status;
}

class _FakeAttendanceApi extends AttendanceApi {
  _FakeAttendanceApi(
    Ref ref, {
    List<AttendanceEntry> initialRecords = const [],
    this.failedStaffIds = const {},
    this.reconcileFailedCreates = false,
  }) : _records = {for (final record in initialRecords) record.staffId: record},
       super(TenantApiClient(ref));

  final Map<String, AttendanceEntry> _records;
  final Set<String> failedStaffIds;
  final bool reconcileFailedCreates;
  final List<_AttendanceRead> reads = [];
  final List<_AttendanceCreate> creates = [];

  @override
  Future<List<AttendanceEntry>> listAttendance({
    required String siteId,
    required DateTime date,
  }) async {
    reads.add(_AttendanceRead(siteId, date));
    return _records.values.toList(growable: false);
  }

  @override
  Future<AttendanceEntry> createAttendance({
    required String staffId,
    required String siteId,
    required DateTime date,
    required String status,
  }) async {
    creates.add(_AttendanceCreate(staffId, siteId, date, status));
    final record = _entry(staffId: staffId, status: status, date: date);
    if (failedStaffIds.contains(staffId)) {
      if (reconcileFailedCreates) _records[staffId] = record;
      throw const TenantApiException(
        'Attendance conflict for this worker.',
        code: 'ATTENDANCE_CONFLICT',
        statusCode: 409,
      );
    }
    _records[staffId] = record;
    return record;
  }
}

class _Harness {
  const _Harness(this.container, this._siteApi, this._attendanceApi);

  final ProviderContainer container;
  final _FakeSiteApi Function() _siteApi;
  final _FakeAttendanceApi Function() _attendanceApi;

  _FakeSiteApi get siteApi => _siteApi();
  _FakeAttendanceApi get attendanceApi => _attendanceApi();
}

_Harness _harness({
  List<SiteSummary> sites = const [_activeSite, _plannedSite],
  List<AttendanceEntry> records = const [],
  Set<String> failedStaffIds = const {},
  bool reconcileFailedCreates = false,
}) {
  late _FakeSiteApi siteApi;
  late _FakeAttendanceApi attendanceApi;
  final container = ProviderContainer(
    overrides: [
      siteApiProvider.overrideWith((ref) {
        siteApi = _FakeSiteApi(ref, sites);
        return siteApi;
      }),
      attendanceApiProvider.overrideWith((ref) {
        attendanceApi = _FakeAttendanceApi(
          ref,
          initialRecords: records,
          failedStaffIds: failedStaffIds,
          reconcileFailedCreates: reconcileFailedCreates,
        );
        return attendanceApi;
      }),
    ],
  );
  container.read(attendanceControllerProvider);
  return _Harness(container, () => siteApi, () => attendanceApi);
}

Future<AttendanceState> _waitForLoaded(ProviderContainer container) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final state = container.read(attendanceControllerProvider);
    if (!state.isLoading && !state.isSubmitting) return state;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Attendance controller did not settle.');
}

void main() {
  group('AttendanceEntry.fromJson', () {
    test('parses Staff, Site, marker, and normalized enum values', () {
      final entry = AttendanceEntry.fromJson(_entryJson());

      expect(entry.staffId, 'staff-1');
      expect(entry.status, 'PRESENT');
      expect(entry.shiftType, 'REGULAR');
      expect(entry.staff.displayName, 'Ravi Kumar');
      expect(entry.site.name, 'North Tower');
      expect(entry.markedBy?.displayName, 'Meera Patel');
      expect(entry.date, DateTime.utc(2026, 8, 17));
    });

    test('rejects malformed Staff data with a typed response error', () {
      final json = _entryJson()..['staff'] = 'staff-1';

      expect(
        () => AttendanceEntry.fromJson(json),
        throwsA(
          isA<TenantApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
    });
  });

  group('AttendanceController', () {
    test(
      'loads only active Sites and requests attendance by Site and date',
      () async {
        final harness = _harness();
        addTearDown(harness.container.dispose);

        var state = await _waitForLoaded(harness.container);

        expect(state.sites.map((site) => site.id), ['site-1']);
        expect(state.selectedSiteId, 'site-1');
        expect(state.workers.map((worker) => worker.id), [
          'staff-1',
          'staff-2',
        ]);
        expect(harness.attendanceApi.reads.single.siteId, 'site-1');
        expect(
          harness.attendanceApi.reads.single.date,
          DateTime(
            state.selectedDate.year,
            state.selectedDate.month,
            state.selectedDate.day,
          ),
        );

        await harness.container
            .read(attendanceControllerProvider.notifier)
            .selectDate(DateTime(2026, 8, 10, 19, 30));
        state = await _waitForLoaded(harness.container);

        expect(state.selectedDate, DateTime(2026, 8, 10));
        expect(harness.attendanceApi.reads.last.siteId, 'site-1');
        expect(harness.attendanceApi.reads.last.date, DateTime(2026, 8, 10));
      },
    );

    test(
      'does not overwrite persisted attendance through local marking',
      () async {
        final harness = _harness(
          records: [_entry(staffId: 'staff-1', status: 'PRESENT')],
        );
        addTearDown(harness.container.dispose);
        await _waitForLoaded(harness.container);
        final controller = harness.container.read(
          attendanceControllerProvider.notifier,
        );

        controller.markAttendance('staff-1', 'ABSENT');
        controller.markAttendance('staff-2', 'ABSENT');
        final state = harness.container.read(attendanceControllerProvider);

        expect(state.statusFor('staff-1'), 'PRESENT');
        expect(state.selections.containsKey('staff-1'), isFalse);
        expect(state.statusFor('staff-2'), 'ABSENT');
        expect(state.selections, {'staff-2': 'ABSENT'});
      },
    );

    test('submits sequentially and retains only unresolved failures', () async {
      final harness = _harness(failedStaffIds: const {'staff-2'});
      addTearDown(harness.container.dispose);
      await _waitForLoaded(harness.container);
      final controller = harness.container.read(
        attendanceControllerProvider.notifier,
      );
      controller.markAttendance('staff-1', 'PRESENT');
      controller.markAttendance('staff-2', 'ABSENT');

      await controller.submit();
      final state = harness.container.read(attendanceControllerProvider);

      expect(harness.attendanceApi.creates.map((call) => call.staffId), [
        'staff-1',
        'staff-2',
      ]);
      expect(harness.attendanceApi.creates.first.siteId, 'site-1');
      expect(harness.attendanceApi.creates.first.status, 'PRESENT');
      expect(state.records.keys, ['staff-1']);
      expect(state.selections, {'staff-2': 'ABSENT'});
      expect(
        state.notice,
        '1 saved; 1 failed. Attendance conflict for this worker.',
      );
    });

    test(
      'treats a failed create found during reconciliation as saved',
      () async {
        final harness = _harness(
          failedStaffIds: const {'staff-1'},
          reconcileFailedCreates: true,
        );
        addTearDown(harness.container.dispose);
        await _waitForLoaded(harness.container);
        final controller = harness.container.read(
          attendanceControllerProvider.notifier,
        );
        controller.markAttendance('staff-1', 'PRESENT');

        await controller.submit();
        final state = harness.container.read(attendanceControllerProvider);

        expect(state.records['staff-1']?.status, 'PRESENT');
        expect(state.selections, isEmpty);
        expect(state.notice, '1 attendance record saved.');
        expect(state.notice, isNot(contains('failed')));
      },
    );
  });
}
