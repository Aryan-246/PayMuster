import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';
import '../../sites/data/site_api.dart';
import '../data/attendance_api.dart';

const _unset = Object();

class AttendanceState {
  const AttendanceState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.sites = const [],
    this.selectedSiteId,
    required this.selectedDate,
    this.records = const {},
    this.selections = const {},
    this.error,
    this.notice,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<SiteSummary> sites;
  final String? selectedSiteId;
  final DateTime selectedDate;
  final Map<String, AttendanceEntry> records;
  final Map<String, String> selections;
  final String? error;
  final String? notice;

  SiteSummary? get selectedSite {
    for (final site in sites) {
      if (site.id == selectedSiteId) return site;
    }
    return null;
  }

  List<SiteWorker> get workers => selectedSite?.workers ?? const [];

  String? statusFor(String staffId) {
    return records[staffId]?.status ?? selections[staffId];
  }

  bool isPersisted(String staffId) => records.containsKey(staffId);

  int countStatus(String status) {
    return workers.where((worker) => statusFor(worker.id) == status).length;
  }

  AttendanceState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<SiteSummary>? sites,
    Object? selectedSiteId = _unset,
    DateTime? selectedDate,
    Map<String, AttendanceEntry>? records,
    Map<String, String>? selections,
    Object? error = _unset,
    Object? notice = _unset,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      sites: sites ?? this.sites,
      selectedSiteId: identical(selectedSiteId, _unset)
          ? this.selectedSiteId
          : selectedSiteId as String?,
      selectedDate: selectedDate ?? this.selectedDate,
      records: records ?? this.records,
      selections: selections ?? this.selections,
      error: identical(error, _unset) ? this.error : error as String?,
      notice: identical(notice, _unset) ? this.notice : notice as String?,
    );
  }
}

class AttendanceController extends Notifier<AttendanceState> {
  int _loadGeneration = 0;

  @override
  AttendanceState build() {
    final now = DateTime.now();
    Future.microtask(load);
    return AttendanceState(
      selectedDate: DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null, notice: null);
    try {
      final allSites = await ref.read(siteApiProvider).listSites();
      final sites = allSites
          .where((site) => site.isActive)
          .toList(growable: false);
      if (generation != _loadGeneration) return;

      String? selectedSiteId = state.selectedSiteId;
      if (!sites.any((site) => site.id == selectedSiteId)) {
        selectedSiteId = sites.isEmpty ? null : sites.first.id;
      }
      state = state.copyWith(
        sites: sites,
        selectedSiteId: selectedSiteId,
        records: const {},
        selections: const {},
      );
      if (selectedSiteId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      await _loadAttendance(generation);
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        error: _message(error, 'Attendance could not be loaded.'),
      );
    }
  }

  Future<void> selectSite(String siteId) async {
    if (siteId == state.selectedSiteId || state.isSubmitting) return;
    final generation = ++_loadGeneration;
    state = state.copyWith(
      selectedSiteId: siteId,
      isLoading: true,
      records: const {},
      selections: const {},
      error: null,
      notice: null,
    );
    await _loadAttendance(generation);
  }

  Future<void> selectDate(DateTime date) async {
    if (state.isSubmitting) return;
    final normalized = DateTime(date.year, date.month, date.day);
    if (_sameDay(normalized, state.selectedDate)) return;
    final generation = ++_loadGeneration;
    state = state.copyWith(
      selectedDate: normalized,
      isLoading: true,
      records: const {},
      selections: const {},
      error: null,
      notice: null,
    );
    if (state.selectedSiteId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    await _loadAttendance(generation);
  }

  Future<void> _loadAttendance(int generation) async {
    final siteId = state.selectedSiteId;
    if (siteId == null) return;
    try {
      final entries = await ref
          .read(attendanceApiProvider)
          .listAttendance(siteId: siteId, date: state.selectedDate);
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        records: {for (final entry in entries) entry.staffId: entry},
        selections: const {},
        error: null,
      );
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        error: _message(error, 'Attendance could not be loaded.'),
      );
    }
  }

  void markAttendance(String staffId, String status) {
    if (state.isSubmitting || state.isPersisted(staffId)) return;
    if (!state.workers.any((worker) => worker.id == staffId)) return;
    state = state.copyWith(
      selections: {...state.selections, staffId: status},
      notice: null,
    );
  }

  void markAllPresent() {
    if (state.isSubmitting) return;
    final selections = {...state.selections};
    for (final worker in state.workers) {
      if (!state.isPersisted(worker.id)) selections[worker.id] = 'PRESENT';
    }
    state = state.copyWith(selections: selections, notice: null);
  }

  Future<void> submit() async {
    final siteId = state.selectedSiteId;
    final pending = Map<String, String>.from(state.selections);
    if (siteId == null || pending.isEmpty || state.isSubmitting) return;

    state = state.copyWith(isSubmitting: true, error: null, notice: null);
    final successful = <String, AttendanceEntry>{};
    final failures = <String, String>{};

    for (final entry in pending.entries) {
      try {
        successful[entry.key] = await ref
            .read(attendanceApiProvider)
            .createAttendance(
              staffId: entry.key,
              siteId: siteId,
              date: state.selectedDate,
              status: entry.value,
            );
      } catch (error) {
        failures[entry.key] = _message(error, 'Attendance submission failed.');
      }
    }

    var records = {...state.records, ...successful};
    try {
      final authoritative = await ref
          .read(attendanceApiProvider)
          .listAttendance(siteId: siteId, date: state.selectedDate);
      records = {for (final entry in authoritative) entry.staffId: entry};
    } catch (_) {
      // Successful create responses remain authoritative for this session.
    }

    final failedStaffIds = pending.keys
        .where((staffId) => !successful.containsKey(staffId))
        .toSet();
    final remainingSelections = {
      for (final entry in pending.entries)
        if (failedStaffIds.contains(entry.key) &&
            !records.containsKey(entry.key))
          entry.key: entry.value,
    };
    final successCount = pending.length - remainingSelections.length;
    final notice = remainingSelections.isEmpty
        ? '$successCount attendance ${successCount == 1 ? 'record' : 'records'} saved.'
        : '$successCount saved; ${remainingSelections.length} failed. '
              '${failures[remainingSelections.keys.first] ?? 'Attendance submission failed.'}';

    state = state.copyWith(
      isSubmitting: false,
      records: records,
      selections: remainingSelections,
      notice: notice,
    );
  }
}

String _message(Object error, String fallback) {
  if (error is TenantApiException) return error.message;
  return fallback;
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

final attendanceControllerProvider =
    NotifierProvider<AttendanceController, AttendanceState>(
      AttendanceController.new,
    );
