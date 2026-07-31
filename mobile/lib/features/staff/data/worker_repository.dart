import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/worker.dart';

abstract class WorkerRepository {
  Future<List<Worker>> getWorkers();
  Future<Worker?> getWorker(String id);
}

class MockWorkerRepository implements WorkerRepository {
  final List<Worker> _mockWorkers = [
    const Worker(
      id: 'w_1',
      firstName: 'Ramesh',
      lastName: 'Kumar',
      role: 'Electrician',
      employeeId: 'PM9876',
      siteId: 'site_1',
      siteName: 'Mohali Tower A',
      dailyWage: 800.0,
      status: 'Active',
    ),
    const Worker(
      id: 'w_2',
      firstName: 'Suresh',
      lastName: 'Yadav',
      role: 'Welder',
      employeeId: 'PM9877',
      siteId: 'site_1',
      siteName: 'Mohali Tower A',
      dailyWage: 950.0,
      status: 'Active',
    ),
    const Worker(
      id: 'w_3',
      firstName: 'Vijay',
      lastName: 'Singh',
      role: 'Carpenter',
      employeeId: 'PM9878',
      siteId: 'site_1',
      siteName: 'Mohali Tower A',
      dailyWage: 750.0,
      status: 'Active',
    ),
    const Worker(
      id: 'w_4',
      firstName: 'Mohammad',
      lastName: 'Ali',
      role: 'Helper',
      employeeId: 'PM9879',
      siteId: 'site_1',
      siteName: 'Mohali Tower A',
      dailyWage: 500.0,
      status: 'On Leave',
    ),
  ];

  @override
  Future<List<Worker>> getWorkers() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockWorkers;
  }

  @override
  Future<Worker?> getWorker(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockWorkers.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }
}

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return MockWorkerRepository();
});

final workersListProvider = FutureProvider<List<Worker>>((ref) {
  return ref.watch(workerRepositoryProvider).getWorkers();
});
