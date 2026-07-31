class Worker {
  final String id;
  final String firstName;
  final String lastName;
  final String role; // e.g. Electrician, Helper, Plumber
  final String employeeId;
  final String siteId;
  final String siteName;
  final double dailyWage;
  final String status; // Active, On Leave, Inactive

  const Worker({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.employeeId,
    required this.siteId,
    required this.siteName,
    required this.dailyWage,
    required this.status,
  });

  String get fullName => '$firstName $lastName';
}
