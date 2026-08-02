class PayrollRecord {
  final String workerId;
  final String workerName;
  final String role;
  final int daysWorked;
  final double amount;
  final String status; // Pending, Paid

  const PayrollRecord({
    required this.workerId,
    required this.workerName,
    required this.role,
    required this.daysWorked,
    required this.amount,
    required this.status,
  });
}
