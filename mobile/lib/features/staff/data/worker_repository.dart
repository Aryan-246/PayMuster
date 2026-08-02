import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/worker.dart';

abstract class WorkerRepository {
  Future<List<Worker>> getWorkers();
  Future<Worker?> getWorker(String id);
}

class MockWorkerRepository implements WorkerRepository {
  final List<Worker> _mockWorkers = [
    const Worker(id: 'w_1', firstName: 'Ramesh', lastName: 'Kumar', role: 'Electrician', employeeId: 'PM9876', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 800.0, status: 'Active'),
    const Worker(id: 'w_2', firstName: 'Suresh', lastName: 'Yadav', role: 'Welder', employeeId: 'PM9877', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 950.0, status: 'Active'),
    const Worker(id: 'w_3', firstName: 'Vijay', lastName: 'Singh', role: 'Carpenter', employeeId: 'PM9878', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 750.0, status: 'Active'),
    const Worker(id: 'w_4', firstName: 'Mohammad', lastName: 'Ali', role: 'Helper', employeeId: 'PM9879', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 500.0, status: 'On Leave'),
    const Worker(id: 'w_5', firstName: 'Rajesh', lastName: 'Sharma', role: 'Foreman', employeeId: 'PM9880', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 1200.0, status: 'Active'),
    const Worker(id: 'w_6', firstName: 'Amit', lastName: 'Patel', role: 'Mason', employeeId: 'PM9881', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 850.0, status: 'Active'),
    const Worker(id: 'w_7', firstName: 'Sandeep', lastName: 'Reddy', role: 'Steel Fixer', employeeId: 'PM9882', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 850.0, status: 'Active'),
    const Worker(id: 'w_8', firstName: 'Manoj', lastName: 'Tiwari', role: 'Plumber', employeeId: 'PM9883', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 800.0, status: 'Active'),
    const Worker(id: 'w_9', firstName: 'Deepak', lastName: 'Verma', role: 'Painter', employeeId: 'PM9884', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 700.0, status: 'Inactive'),
    const Worker(id: 'w_10', firstName: 'Sunil', lastName: 'Gavaskar', role: 'Mason', employeeId: 'PM9885', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 850.0, status: 'Active'),
    const Worker(id: 'w_11', firstName: 'Anil', lastName: 'Kapoor', role: 'Helper', employeeId: 'PM9886', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 500.0, status: 'Active'),
    const Worker(id: 'w_12', firstName: 'Vikram', lastName: 'Rathore', role: 'Crane Operator', employeeId: 'PM9887', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 1100.0, status: 'Active'),
    const Worker(id: 'w_13', firstName: 'Rahul', lastName: 'Dravid', role: 'Safety Officer', employeeId: 'PM9888', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 1000.0, status: 'Active'),
    const Worker(id: 'w_14', firstName: 'Karan', lastName: 'Johar', role: 'Helper', employeeId: 'PM9889', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 500.0, status: 'On Leave'),
    const Worker(id: 'w_15', firstName: 'Ravi', lastName: 'Shastri', role: 'Electrician', employeeId: 'PM9890', siteId: 'site_1', siteName: 'Mohali Tower A', dailyWage: 800.0, status: 'Active'),
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
