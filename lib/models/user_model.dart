class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String? designation;
  final String? department;
  final String? companyName;
  final String? shiftName;
  final bool mobileAttendance;
  final bool multipleAttendance;
  final bool aiSelfie;
  final String? photo;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.designation,
    this.department,
    this.companyName,
    this.shiftName,
    required this.mobileAttendance,
    required this.multipleAttendance,
    required this.aiSelfie,
    this.photo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'employee',
      designation: json['designation'],
      department: json['department'],
      companyName: json['company_name'] ?? (json['company'] is Map ? json['company']['name'] : null) ?? 'TULSI FABRICS INDIA PVT LTD',
      shiftName: json['shift_name'] ?? (json['shift'] is Map ? json['shift']['name'] : null) ?? 'General Staff Shift (09:45 AM - 08:30 PM)',
      mobileAttendance: json['mobile_attendance'] ?? true,
      multipleAttendance: json['multiple_attendance'] ?? false,
      aiSelfie: json['ai_selfie'] ?? true,
      photo: json['photo'],
    );
  }

  bool get isManager => role == 'admin' || role == 'manager';
  String? get photoUrl => photo;
}
