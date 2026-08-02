import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/attendance_record.dart';
import '../../staff/domain/worker.dart';
import '../../staff/data/worker_repository.dart';

class AttendanceState {
  final bool isLoading;
  final List<Worker> workers;
  final Map<String, AttendanceRecord> records; // workerId -> AttendanceRecord

  const AttendanceState({
    this.isLoading = true,
    this.workers = const [],
    this.records = const {},
  });

  AttendanceState copyWith({
    bool? isLoading,
    List<Worker>? workers,
    Map<String, AttendanceRecord>? records,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      workers: workers ?? this.workers,
      records: records ?? this.records,
    );
  }
}

class AttendanceController extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    _init();
    return const AttendanceState();
  }

  Future<void> _init() async {
    final workers = await ref.read(workerRepositoryProvider).getWorkers();
    
    final today = DateTime.now();
    final Map<String, AttendanceRecord> initialRecords = {};
    
    for (var i = 0; i < workers.length; i++) {
      final w = workers[i];
      // Default half of them present, others absent for mock purposes, or just present by default.
      initialRecords[w.id] = AttendanceRecord(
        id: 'rec_$i',
        workerId: w.id,
        siteId: w.siteId,
        date: today,
        status: i % 2 == 0 ? 'Present' : 'Absent', 
      );
    }
    
    state = state.copyWith(
      isLoading: false,
      workers: workers,
      records: initialRecords,
    );
  }

  void markAttendance(String workerId, String status) {
    final currentRecord = state.records[workerId];
    if (currentRecord == null) return;

    final updatedRecord = currentRecord.copyWith(status: status);
    final remainingWorkers = state.workers.where((w) => w.id != workerId).toList();
    
    state = state.copyWith(
      workers: remainingWorkers,
      records: {
        ...state.records,
        workerId: updatedRecord,
      },
    );
  }
  
  void markAllPresent() {
    final Map<String, AttendanceRecord> updatedRecords = {};
    for (final entry in state.records.entries) {
      updatedRecords[entry.key] = entry.value.copyWith(status: 'Present');
    }
    state = state.copyWith(
      workers: [], // All marked
      records: updatedRecords,
    );
  }
}

final attendanceControllerProvider = NotifierProvider<AttendanceController, AttendanceState>(() {
  return AttendanceController();
});
