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
  final bool canMarkOthers;
  final bool canViewEmployees;
  final bool canEditEmployees;
  final bool canViewTasks;
  final bool canCreateTasks;
  final bool canManageTasks;
  final List<String> permissions;
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
    this.canMarkOthers = false,
    this.canViewEmployees = false,
    this.canEditEmployees = false,
    this.canViewTasks = false,
    this.canCreateTasks = false,
    this.canManageTasks = false,
    this.permissions = const [],
    required this.mobileAttendance,
    required this.multipleAttendance,
    required this.aiSelfie,
    this.photo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] ?? 'employee').toString().toLowerCase();
    final perms = (json['permissions'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final bool canMark = json['can_mark_others'] == true ||
        role == 'admin' ||
        role == 'manager' ||
        role == 'super_admin' ||
        perms.contains('attendance.mark') ||
        perms.contains('attendance.bulk');
    final bool canViewEmps = json['can_view_employees'] == true ||
        role == 'admin' ||
        role == 'manager' ||
        role == 'super_admin' ||
        perms.contains('employee.view') ||
        perms.contains('employees.view') ||
        perms.contains('attendance.view');
    final bool canEditEmps = json['can_edit_employees'] == true ||
        role == 'admin' ||
        role == 'super_admin' ||
        perms.contains('employee.edit') ||
        perms.contains('employees.edit') ||
        perms.contains('employee.manage');
    final bool canTasks = json['can_view_tasks'] == true ||
        role == 'super_admin' ||
        perms.contains('tasks.view') ||
        perms.contains('task.view') ||
        perms.contains('tasks.create') ||
        perms.contains('tasks.manage');
    final bool canCreate = json['can_create_tasks'] == true ||
        role == 'super_admin' ||
        perms.contains('tasks.create');
    final bool canManage = json['can_manage_tasks'] == true ||
        role == 'super_admin' ||
        perms.contains('tasks.manage');

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
      shiftName: json['shift_name'] ?? (json['shift'] is Map ? json['shift']['name'] : null),
      canMarkOthers: canMark,
      canViewEmployees: canViewEmps,
      canEditEmployees: canEditEmps,
      canViewTasks: canTasks,
      canCreateTasks: canCreate,
      canManageTasks: canManage,
      permissions: perms,
      mobileAttendance: json['mobile_attendance'] ?? true,
      multipleAttendance: json['multiple_attendance'] ?? false,
      aiSelfie: json['ai_selfie'] ?? true,
      photo: json['photo'],
    );
  }

  bool get isSuperAdmin => role == 'super_admin' || role == 'super admin';
  bool get isManager => role == 'admin' || role == 'manager' || role == 'super_admin' || role == 'super admin';
  bool get canAccessStaffTab => canViewEmployees || isManager;
  String? get photoUrl => photo;
}
