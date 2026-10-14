import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL pointing to Laravel Admin backend API
  // Automatically switches between Chrome/Web (127.0.0.1) and Android Emulator (10.0.2.2)
  static String customBaseUrl = '';

  static String get baseUrl {
    if (customBaseUrl.isNotEmpty) return customBaseUrl;
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api'; // Chrome / Web testing
    }
    return 'https://hrms.tulsifabindia.com/api'; // Production Live Server for APK / Mobile Apps
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (token != null) 'X-Api-Token': token,
    };
  }

  // 1. Authentication APIs
  static Future<Map<String, dynamic>> login(String login, String password, {String? fcmToken}) async {
    final tokenToPass = fcmToken ?? await getSavedFcmToken();
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'login': login,
        'password': password,
        if (tokenToPass != null && tokenToPass.isNotEmpty) 'fcm_token': tokenToPass,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      await saveToken(body['token']);
    }
    return {'status': res.statusCode, 'body': body};
  }

  static Future<Map<String, dynamic>> resetPassword(String login, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );
    return {'status': res.statusCode, 'body': jsonDecode(res.body)};
  }

  static Future<Map<String, dynamic>> me() async {
    final res = await http.get(Uri.parse('$baseUrl/me'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // 2. Attendance & Face Scan Voice Greeting API
  static Future<Map<String, dynamic>> punchAttendance({
    required String type, // in or out
    required double lat,
    required double lng,
    bool faceDetected = true,
    int? employeeId, // For Manager/Admin punching staff
    String? photoPath,
  }) async {
    final headers = await _headers();
    
    if (photoPath != null && photoPath.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/attendance/punch'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['type'] = type;
      req.fields['lat'] = lat.toString();
      req.fields['lng'] = lng.toString();
      req.fields['face_detected'] = faceDetected ? '1' : '0';
      if (employeeId != null) req.fields['employee_id'] = employeeId.toString();
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));

      var streamedRes = await req.send();
      var res = await http.Response.fromStream(streamedRes);
      return jsonDecode(res.body);
    } else {
      final res = await http.post(
        Uri.parse('$baseUrl/attendance/punch'),
        headers: headers,
        body: jsonEncode({
          'type': type,
          'lat': lat,
          'lng': lng,
          'face_detected': faceDetected,
          if (employeeId != null) 'employee_id': employeeId,
        }),
      );
      return jsonDecode(res.body);
    }
  }

  static Future<Map<String, dynamic>> getTodayPunches() async {
    final res = await http.get(Uri.parse('$baseUrl/attendance/today'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> registerFcmToken(String token) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register-fcm-token'),
      headers: await _headers(),
      body: jsonEncode({'fcm_token': token}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getAttendanceHistory({int? userId, int? month, int? year}) async {
    final queryParams = <String>[];
    if (userId != null) queryParams.add('user_id=$userId');
    if (month != null) queryParams.add('month=$month');
    if (year != null) queryParams.add('year=$year');
    
    final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final res = await http.get(Uri.parse('$baseUrl/attendance/history$queryStr'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getAttendanceStatistics() async {
    final res = await http.get(Uri.parse('$baseUrl/attendance/statistics'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // 3. Task Management APIs
  static Future<Map<String, dynamic>> getTasks() async {
    final res = await http.get(Uri.parse('$baseUrl/tasks'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTaskDetails(int taskId) async {
    final res = await http.get(Uri.parse('$baseUrl/tasks/$taskId'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    String? client,
    required String priority,
    String repeatType = 'none',
    String? dueDate,
    String? dueTime,
    int? departmentId,
    int? assignedToId,
    List<int>? assigneeIds,
    List<int>? others,
    String? attachmentFilePath,
  }) async {
    final headers = await _headers();
    if (attachmentFilePath != null && attachmentFilePath.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['title'] = title;
      if (description != null) req.fields['description'] = description;
      if (client != null) req.fields['client'] = client;
      req.fields['priority'] = priority;
      req.fields['repeat_type'] = repeatType;
      if (dueDate != null) req.fields['due_date'] = dueDate;
      if (dueTime != null) req.fields['due_time'] = dueTime;
      if (departmentId != null) req.fields['department_id'] = departmentId.toString();
      if (assignedToId != null) req.fields['assigned_to'] = assignedToId.toString();

      if (assigneeIds != null) {
        for (int i = 0; i < assigneeIds.length; i++) {
          req.fields['assignee_ids[$i]'] = assigneeIds[i].toString();
        }
      }
      if (others != null) {
        for (int i = 0; i < others.length; i++) {
          req.fields['others[$i]'] = others[i].toString();
        }
      }

      req.files.add(await http.MultipartFile.fromPath('attachment_file', attachmentFilePath));
      var streamedRes = await req.send();
      var res = await http.Response.fromStream(streamedRes);
      return jsonDecode(res.body);
    } else {
      final res = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          'client': client,
          'priority': priority,
          'repeat_type': repeatType,
          'due_date': dueDate,
          'due_time': dueTime,
          'department_id': departmentId,
          'assigned_to': assignedToId,
          'assignee_ids': assigneeIds,
          'others': others,
        }),
      );
      return jsonDecode(res.body);
    }
  }

  static Future<Map<String, dynamic>> updateTaskStatus(int taskId, String status, {int? assignedTo}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/status'),
      headers: await _headers(),
      body: jsonEncode({
        'status': status,
        if (assignedTo != null) 'assigned_to': assignedTo,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postTaskReply(int taskId, String message, {String? attachmentPath}) async {
    final headers = await _headers();
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks/$taskId/reply'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['message'] = message;
      req.files.add(await http.MultipartFile.fromPath('reply_attachment', attachmentPath));
      var streamedRes = await req.send();
      var res = await http.Response.fromStream(streamedRes);
      return jsonDecode(res.body);
    } else {
      final res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/reply'),
        headers: headers,
        body: jsonEncode({
          'message': message,
        }),
      );
      return jsonDecode(res.body);
    }
  }

  static Future<Map<String, dynamic>> reassignTask(int taskId, int newAssignedTo, {String? remarks}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/reassign'),
      headers: await _headers(),
      body: jsonEncode({
        'new_assigned_to': newAssignedTo,
        'remarks': remarks,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> remindTask(int taskId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/remind'),
      headers: await _headers(),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getDepartmentEmployees([int? departmentId]) async {
    final url = departmentId != null
        ? '$baseUrl/department-employees?department_id=$departmentId'
        : '$baseUrl/department-employees';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    final body = jsonDecode(res.body);
    return body['data'] ?? [];
  }

  static Future<String?> getSavedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('fcm_token');
    if (saved != null && saved.isNotEmpty && saved != 'fcm_demo_token_hrms_2026') {
      return saved;
    }
    return null;
  }

  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  // 4. Request Module APIs (Leave & Loan / Advance)
  static Future<Map<String, dynamic>> getRequestDashboard() async {
    final res = await http.get(Uri.parse('$baseUrl/requests/dashboard'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getRequests({String? type, String? status}) async {
    final queryParams = <String>[];
    if (type != null && type.isNotEmpty) queryParams.add('type=$type');
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');

    final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final res = await http.get(Uri.parse('$baseUrl/requests$queryStr'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> submitLeaveRequest({
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    String? photoPath,
  }) async {
    final headers = await _headers();
    if (photoPath != null && photoPath.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/requests/leave'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['leave_type'] = leaveType;
      req.fields['from_date'] = fromDate;
      req.fields['to_date'] = toDate;
      req.fields['reason'] = reason;
      req.files.add(await http.MultipartFile.fromPath('document_photo', photoPath));

      var streamedRes = await req.send();
      var res = await http.Response.fromStream(streamedRes);
      return jsonDecode(res.body);
    } else {
      final res = await http.post(
        Uri.parse('$baseUrl/requests/leave'),
        headers: headers,
        body: jsonEncode({
          'leave_type': leaveType,
          'from_date': fromDate,
          'to_date': toDate,
          'reason': reason,
        }),
      );
      return jsonDecode(res.body);
    }
  }

  static Future<Map<String, dynamic>> submitLoanRequest({
    required double amount,
    required String reason,
    int repaymentMonths = 1,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requests/loan'),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'reason': reason,
        'repayment_months': repaymentMonths,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateRequestStatus({
    required int id,
    required String category, // leave or loan
    required String status, // approved or rejected
    String? rejectionReason,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requests/$id/status'),
      headers: await _headers(),
      body: jsonEncode({
        'category': category,
        'status': status,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateProfile({
    int? userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? employeeCode,
    String? designation,
    String? department,
    String? vendorName,
    String? password,
    bool? mobileAttendance,
    bool? multipleAttendance,
    bool? aiSelfie,
    bool? liveTracking,
    bool? selfOdometer,
    bool? esiApplicable,
    bool? overtimeApplicable,
    String? photoPath,
  }) async {
    final headers = await _headers();

    if (photoPath != null && photoPath.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/profile/update'));
      headers.forEach((k, v) => req.headers[k] = v);
      if (userId != null) req.fields['user_id'] = userId.toString();
      if (firstName != null) req.fields['first_name'] = firstName;
      if (lastName != null) req.fields['last_name'] = lastName;
      if (phone != null) req.fields['phone'] = phone;
      if (email != null) req.fields['email'] = email;
      if (employeeCode != null) req.fields['employee_code'] = employeeCode;
      if (designation != null) req.fields['designation'] = designation;
      if (department != null) req.fields['department'] = department;
      if (vendorName != null) req.fields['vendor_name'] = vendorName;
      if (password != null && password.isNotEmpty && password != '********') req.fields['password'] = password;
      if (mobileAttendance != null) req.fields['mobile_attendance'] = mobileAttendance ? '1' : '0';
      if (multipleAttendance != null) req.fields['multiple_attendance'] = multipleAttendance ? '1' : '0';
      if (aiSelfie != null) req.fields['ai_selfie'] = aiSelfie ? '1' : '0';
      if (liveTracking != null) req.fields['live_tracking'] = liveTracking ? '1' : '0';
      if (selfOdometer != null) req.fields['self_odometer'] = selfOdometer ? '1' : '0';
      if (esiApplicable != null) req.fields['esi_applicable'] = esiApplicable ? '1' : '0';
      if (overtimeApplicable != null) req.fields['overtime_applicable'] = overtimeApplicable ? '1' : '0';

      req.files.add(await http.MultipartFile.fromPath('profile_photo', photoPath));

      var streamedRes = await req.send();
      var res = await http.Response.fromStream(streamedRes);
      return jsonDecode(res.body);
    } else {
      final res = await http.post(
        Uri.parse('$baseUrl/profile/update'),
        headers: headers,
        body: jsonEncode({
          if (userId != null) 'user_id': userId,
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (employeeCode != null) 'employee_code': employeeCode,
          if (designation != null) 'designation': designation,
          if (department != null) 'department': department,
          if (vendorName != null) 'vendor_name': vendorName,
          if (password != null && password.isNotEmpty && password != '********') 'password': password,
          if (mobileAttendance != null) 'mobile_attendance': mobileAttendance,
          if (multipleAttendance != null) 'multiple_attendance': multipleAttendance,
          if (aiSelfie != null) 'ai_selfie': aiSelfie,
          if (liveTracking != null) 'live_tracking': liveTracking,
          if (selfOdometer != null) 'self_odometer': selfOdometer,
          if (esiApplicable != null) 'esi_applicable': esiApplicable,
          if (overtimeApplicable != null) 'overtime_applicable': overtimeApplicable,
        }),
      );
      return jsonDecode(res.body);
    }
  }

  // 5. Masters API
  static Future<Map<String, dynamic>> getMasters() async {
    final res = await http.get(Uri.parse('$baseUrl/masters'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // 6. Punch Edit & Delete APIs
  static Future<Map<String, dynamic>> updateAttendancePunch({
    required int punchId,
    String? status,
    String? time,
    String? locationText,
    String? remarks,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/attendance/$punchId/update'),
      headers: await _headers(),
      body: jsonEncode({
        if (status != null) 'status': status,
        if (time != null) 'time': time,
        if (locationText != null) 'location_text': locationText,
        if (remarks != null) 'remarks': remarks,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteAttendancePunch(int punchId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/attendance/$punchId'),
      headers: await _headers(),
    );
    return jsonDecode(res.body);
  }
}
