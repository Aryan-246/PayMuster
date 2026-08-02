import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/payroll_record.dart';

abstract class PayrollRepository {
  Future<List<PayrollRecord>> getPayrollRecords(String period);
}

class MockPayrollRepository implements PayrollRepository {
  @override
  Future<List<PayrollRecord>> getPayrollRecords(String period) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network
    return [
      const PayrollRecord(workerId: 'w_1', workerName: 'Ramesh Kumar', role: 'Electrician', daysWorked: 24, amount: 19200, status: 'Pending'),
      const PayrollRecord(workerId: 'w_2', workerName: 'Suresh Yadav', role: 'Welder', daysWorked: 22, amount: 20900, status: 'Paid'),
      const PayrollRecord(workerId: 'w_3', workerName: 'Vijay Singh', role: 'Carpenter', daysWorked: 26, amount: 19500, status: 'Pending'),
      const PayrollRecord(workerId: 'w_4', workerName: 'Mohammad Ali', role: 'Helper', daysWorked: 18, amount: 9000, status: 'Paid'),
      const PayrollRecord(workerId: 'w_5', workerName: 'Rajesh Sharma', role: 'Foreman', daysWorked: 26, amount: 31200, status: 'Pending'),
      const PayrollRecord(workerId: 'w_6', workerName: 'Amit Patel', role: 'Mason', daysWorked: 23, amount: 19550, status: 'Paid'),
      const PayrollRecord(workerId: 'w_7', workerName: 'Sandeep Reddy', role: 'Steel Fixer', daysWorked: 25, amount: 21250, status: 'Pending'),
      const PayrollRecord(workerId: 'w_8', workerName: 'Manoj Tiwari', role: 'Plumber', daysWorked: 20, amount: 16000, status: 'Pending'),
      const PayrollRecord(workerId: 'w_9', workerName: 'Deepak Verma', role: 'Painter', daysWorked: 15, amount: 10500, status: 'Paid'),
      const PayrollRecord(workerId: 'w_10', workerName: 'Sunil Gavaskar', role: 'Mason', daysWorked: 22, amount: 18700, status: 'Pending'),
      const PayrollRecord(workerId: 'w_11', workerName: 'Anil Kapoor', role: 'Helper', daysWorked: 24, amount: 12000, status: 'Paid'),
      const PayrollRecord(workerId: 'w_12', workerName: 'Vikram Rathore', role: 'Crane Operator', daysWorked: 25, amount: 27500, status: 'Pending'),
      const PayrollRecord(workerId: 'w_13', workerName: 'Rahul Dravid', role: 'Safety Officer', daysWorked: 26, amount: 26000, status: 'Paid'),
      const PayrollRecord(workerId: 'w_14', workerName: 'Karan Johar', role: 'Helper', daysWorked: 10, amount: 5000, status: 'Paid'),
      const PayrollRecord(workerId: 'w_15', workerName: 'Ravi Shastri', role: 'Electrician', daysWorked: 26, amount: 20800, status: 'Pending'),
    ];
  }
}

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return MockPayrollRepository();
});

final payrollListProvider = FutureProvider.family<List<PayrollRecord>, String>((ref, period) {
  return ref.watch(payrollRepositoryProvider).getPayrollRecords(period);
});
