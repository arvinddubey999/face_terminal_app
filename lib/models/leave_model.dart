class LeaveModel {
  final int id;
  final int userId;
  final String userName;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final String? reason;
  final String status;

  LeaveModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.reason,
    required this.status,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? '',
      leaveType: json['leave_type'] ?? 'Casual Leave',
      fromDate: json['from_date'] ?? '',
      toDate: json['to_date'] ?? '',
      reason: json['reason'],
      status: json['status'] ?? 'pending',
    );
  }
}
