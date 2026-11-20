import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL pointing to Laravel Admin backend API
  // Automatically switches between Chrome/Web (127.0.0.1) and Android Emulator (10.0.2.2)
  static String customBaseUrl = '';

  static const MethodChannel _batteryChannel = MethodChannel('samples.flutter.dev/battery');

  static Future<Position?> getDeviceCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (e) {
      debugPrint("Error fetching device GPS position: $e");
      return null;
    }
  }

  static Future<int?> getDeviceBatteryLevel() async {
    try {
      final int level = await _batteryChannel.invokeMethod('getBatteryLevel');
      return level;
    } catch (e) {
      debugPrint("Error reading battery level from device: $e");
      return null;
    }
  }

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
    final tokenToPass = (fcmToken != null && fcmToken.isNotEmpty) ? fcmToken : await getSavedFcmToken();
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'login': login,
        'password': password,
        if (tokenToPass != null && tokenToPass.isNotEmpty) ...{
          'fcm_token': tokenToPass,
          'fcmToken': tokenToPass,
          'device_token': tokenToPass,
        },
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      await saveToken(body['token']);
      if (tokenToPass != null && tokenToPass.isNotEmpty) {
        await saveFcmToken(tokenToPass);
      }
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
    String? locationText,
    bool faceDetected = true,
    int? employeeId, // For Manager/Admin punching staff
    String? photoPath,
    bool autoDetect = false,
  }) async {
    final headers = await _headers();
    final battery = await getDeviceBatteryLevel();
    
    if (photoPath != null && photoPath.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/attendance/punch'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['type'] = type;
      req.fields['lat'] = lat.toString();
      req.fields['lng'] = lng.toString();
      req.fields['face_detected'] = faceDetected ? '1' : '0';
      if (locationText != null && locationText.isNotEmpty) req.fields['location_text'] = locationText;
      if (employeeId != null) req.fields['employee_id'] = employeeId.toString();
      if (autoDetect) req.fields['auto_detect'] = '1';
      if (battery != null) req.fields['battery'] = battery.toString();
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));

      var streamedRes = await req.send();
      var res = await http.Response.fromStream(streamedRes);
      try {
        return jsonDecode(res.body);
      } catch (e) {
        return {'success': false, 'message': 'Server returned ${res.statusCode}: ${res.body}'};
      }
    } else {
      final res = await http.post(
        Uri.parse('$baseUrl/attendance/punch'),
        headers: headers,
        body: jsonEncode({
          'type': type,
          'lat': lat,
          'lng': lng,
          if (locationText != null && locationText.isNotEmpty) 'location_text': locationText,
          'face_detected': faceDetected,
          if (employeeId != null) 'employee_id': employeeId,
          if (autoDetect) 'auto_detect': true,
          if (battery != null) 'battery': battery,
        }),
      );
      try {
        return jsonDecode(res.body);
      } catch (e) {
        return {'success': false, 'message': 'Server returned ${res.statusCode}: ${res.body}'};
      }
    }
  }

  static Future<Map<String, dynamic>> recognizeAndPunch({
    required String photoPath,
    required double lat,
    required double lng,
  }) async {
    return punchAttendance(
      type: 'in', // Backend auto-toggles IN/OUT for recognized staff
      lat: lat,
      lng: lng,
      faceDetected: true,
      photoPath: photoPath,
      autoDetect: true,
    );
  }

  static Future<Map<String, dynamic>> getTodayPunches() async {
    final res = await http.get(Uri.parse('$baseUrl/attendance/today'), headers: await _headers());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> registerFcmToken(String token, {int? userId}) async {
    if (token.isNotEmpty) {
      await saveFcmToken(token);
    }
    final headers = await _headers();
    final payload = <String, dynamic>{
      'fcm_token': token,
      'fcmToken': token,
      'device_token': token,
      if (userId != null) 'user_id': userId,
    };
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register-fcm-token'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      // Fallback endpoint
      final fallbackRes = await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: headers,
        body: jsonEncode(payload),
      );
      return jsonDecode(fallbackRes.body);
    } catch (e) {
      debugPrint("registerFcmToken API error: $e");
      return {'ok': false, 'error': e.toString()};
    }
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

  static Future<Map<String, dynamic>> getAttendanceStatistics({String? date}) async {
    final query = (date != null && date.isNotEmpty) ? '?date=$date' : '';
    final res = await http.get(Uri.parse('$baseUrl/attendance/statistics$query'), headers: await _headers());
    return jsonDecode(res.body);
  }

  // 3. Task Management APIs
  static Future<Map<String, dynamic>> getTasks({
    String? status,
    String? search,
    int? categoryId,
    int? departmentId,
    int? userId,
    int? fromUserId,
    String? priority,
    String? scope,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty && status != 'all') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['q'] = search;
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (departmentId != null) queryParams['department_id'] = departmentId.toString();
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (fromUserId != null) queryParams['from_user_id'] = fromUserId.toString();
    if (priority != null && priority.isNotEmpty && priority != 'all') queryParams['priority'] = priority;
    if (scope != null && scope.isNotEmpty && scope != 'all') queryParams['scope'] = scope;

    final uri = Uri.parse('$baseUrl/tasks').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri, headers: await _headers());
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
    int? categoryId,
    int? departmentId,
    int? assignedToId,
    List<int>? assigneeIds,
    List<int>? others,
    String? attachmentFilePath,
    List<String>? attachmentFilePaths,
  }) async {
    final headers = await _headers();
    final paths = <String>[];
    if (attachmentFilePaths != null && attachmentFilePaths.isNotEmpty) {
      paths.addAll(attachmentFilePaths);
    } else if (attachmentFilePath != null && attachmentFilePath.isNotEmpty) {
      paths.add(attachmentFilePath);
    }

    if (paths.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['title'] = title;
      if (description != null) req.fields['description'] = description;
      if (client != null) req.fields['client'] = client;
      req.fields['priority'] = priority;
      req.fields['repeat_type'] = repeatType;
      if (dueDate != null) req.fields['due_date'] = dueDate;
      if (dueTime != null) req.fields['due_time'] = dueTime;
      if (categoryId != null) req.fields['category_id'] = categoryId.toString();
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

      for (var p in paths) {
        req.files.add(await http.MultipartFile.fromPath('attachment_files[]', p));
      }
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
          'category_id': categoryId,
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

  static Future<Map<String, dynamic>> togglePinTask(int taskId) async {
    final headers = await _headers();
    var res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/pin'),
      headers: headers,
    );
    if (res.statusCode == 404) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/toggle-pin'),
        headers: headers,
      );
    }
    if (res.statusCode == 404) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/status'),
        headers: headers,
        body: jsonEncode({'toggle_pin': true}),
      );
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> reopenTask(int taskId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/reopen'),
      headers: await _headers(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateTaskDeadline(
    int taskId, {
    String? dueDate,
    String? dueTime,
    String? status,
    String? remarks,
  }) async {
    final headers = await _headers();
    final body = jsonEncode({
      if (dueDate != null) 'due_date': dueDate,
      if (dueTime != null) 'due_time': dueTime,
      if (status != null) 'status': status,
      if (remarks != null) 'remarks': remarks,
    });

    var res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/update-deadline'),
      headers: headers,
      body: body,
    );

    if (res.statusCode == 404) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/deadline'),
        headers: headers,
        body: body,
      );
    }

    if (res.statusCode == 404) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/status'),
        headers: headers,
        body: body,
      );
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateTaskDescription(
    int taskId, {
    String? title,
    String? description,
  }) async {
    final headers = await _headers();
    final body = jsonEncode({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });

    var res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/update-description'),
      headers: headers,
      body: body,
    );

    if (res.statusCode == 404) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/update'),
        headers: headers,
        body: body,
      );
    }

    if (res.statusCode == 404) {
      res = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: headers,
        body: body,
      );
    }

    if (res.statusCode == 404) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/status'),
        headers: headers,
        body: body,
      );
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateTaskCategory(int taskId, int? categoryId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/update-category'),
      headers: await _headers(),
      body: jsonEncode({
        'category_id': categoryId,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadTaskAttachment(int taskId, List<String> filePaths) async {
    final headers = await _headers();
    var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks/$taskId/attachment'));
    headers.forEach((k, v) => req.headers[k] = v);
    for (var p in filePaths) {
      req.files.add(await http.MultipartFile.fromPath('attachment_files[]', p));
    }
    var streamedRes = await req.send();
    var res = await http.Response.fromStream(streamedRes);

    if (res.statusCode == 404) {
      var req2 = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks/$taskId/attachments'));
      headers.forEach((k, v) => req2.headers[k] = v);
      for (var p in filePaths) {
        req2.files.add(await http.MultipartFile.fromPath('attachment_files[]', p));
      }
      var s2 = await req2.send();
      res = await http.Response.fromStream(s2);
    }

    if (res.statusCode == 404) {
      var req3 = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks/$taskId/reply'));
      headers.forEach((k, v) => req3.headers[k] = v);
      req3.fields['message'] = 'Attachment uploaded';
      for (var p in filePaths) {
        req3.files.add(await http.MultipartFile.fromPath('reply_attachments[]', p));
      }
      var s3 = await req3.send();
      res = await http.Response.fromStream(s3);
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteTaskAttachment(int attachmentId) async {
    final headers = await _headers();
    var res = await http.delete(
      Uri.parse('$baseUrl/tasks/attachments/$attachmentId'),
      headers: headers,
    );
    if (res.statusCode == 404 || res.statusCode == 405) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/attachments/$attachmentId/delete'),
        headers: headers,
      );
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteReplyAttachment(int replyId, String filePath) async {
    final headers = await _headers();
    final body = jsonEncode({'file_path': filePath});
    var res = await http.delete(
      Uri.parse('$baseUrl/tasks/replies/$replyId/attachment'),
      headers: headers,
      body: body,
    );
    if (res.statusCode == 404 || res.statusCode == 405) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/replies/$replyId/attachment/delete'),
        headers: headers,
        body: body,
      );
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteTask(int taskId) async {
    final headers = await _headers();
    var res = await http.delete(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: headers,
    );
    if (res.statusCode == 404 || res.statusCode == 405) {
      res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/delete'),
        headers: headers,
      );
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postTaskReply(int taskId, String message, {String? attachmentPath, List<String>? attachmentPaths}) async {
    final headers = await _headers();
    final paths = <String>[];
    if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
      paths.addAll(attachmentPaths);
    } else if (attachmentPath != null && attachmentPath.isNotEmpty) {
      paths.add(attachmentPath);
    }

    if (paths.isNotEmpty) {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/tasks/$taskId/reply'));
      headers.forEach((k, v) => req.headers[k] = v);
      req.fields['message'] = message;
      for (var p in paths) {
        req.files.add(await http.MultipartFile.fromPath('reply_attachments[]', p));
      }
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

  static Future<List<dynamic>> getTaskCategories() async {
    final res = await http.get(Uri.parse('$baseUrl/task-categories'), headers: await _headers());
    final body = jsonDecode(res.body);
    return body['data'] ?? [];
  }

  static Future<Map<String, dynamic>> createTaskCategory({
    required String name,
    String? color,
    String? description,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/task-categories'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        if (color != null) 'color': color,
        if (description != null) 'description': description,
      }),
    );
    return jsonDecode(res.body);
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

  static Future<double> getOfficeLat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('office_lat') ?? 21.1936;
  }

  static Future<double> getOfficeLng() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('office_lng') ?? 72.8508;
  }

  static Future<void> saveOfficeCoordinates(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('office_lat', lat);
    await prefs.setDouble('office_lng', lng);
  }

  // Live GPS Tracking Ping to /tracking/store
  static Future<Map<String, dynamic>> sendLocationPing({
    required double lat,
    required double lng,
    double? speed,
    int? battery,
    String? status,
    String? address,
    String? locationText,
  }) async {
    try {
      final actualBattery = battery ?? await getDeviceBatteryLevel();
      final res = await http.post(
        Uri.parse('$baseUrl/tracking/store'),
        headers: await _headers(),
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          if (speed != null) 'speed': speed,
          if (actualBattery != null) 'battery': actualBattery,
          if (status != null) 'status': status,
          if (address != null) 'address': address,
          if (locationText != null) 'location_text': locationText,
          'recorded_at': DateTime.now().toIso8601String(),
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
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

  static Future<Map<String, dynamic>> manualStoreAttendancePunch({
    required int userId,
    required String status,
    required String workDate,
    String? time,
    String? locationText,
    String? remarks,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/attendance/manual-store'),
      headers: await _headers(),
      body: jsonEncode({
        'user_id': userId,
        'status': status,
        'work_date': workDate,
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

  // ==========================================
  // Face Recognition & Images API
  // ==========================================

  /// Upload one or multiple face reference images
  static Future<Map<String, dynamic>> uploadFaceImages({
    List<String>? filePaths,
    String? singleFilePath,
    String? base64Image,
    int? userId,
    String? employeeCode,
    bool replace = false,
    bool setAsAvatar = false,
  }) async {
    final headers = await _headers();

    if ((filePaths != null && filePaths.isNotEmpty) || (singleFilePath != null && singleFilePath.isNotEmpty)) {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/face-images/upload'));
      headers.forEach((k, v) => req.headers[k] = v);

      if (userId != null) req.fields['user_id'] = userId.toString();
      if (employeeCode != null) req.fields['employee_code'] = employeeCode;
      if (replace) req.fields['replace'] = '1';
      if (setAsAvatar) req.fields['set_as_avatar'] = '1';

      if (filePaths != null && filePaths.isNotEmpty) {
        for (var path in filePaths) {
          req.files.add(await http.MultipartFile.fromPath('face_images[]', path));
        }
      } else if (singleFilePath != null && singleFilePath.isNotEmpty) {
        req.files.add(await http.MultipartFile.fromPath('face_images[]', singleFilePath));
      }

      final streamedRes = await req.send();
      final res = await http.Response.fromStream(streamedRes);
      return jsonDecode(res.body);
    } else if (base64Image != null && base64Image.isNotEmpty) {
      final res = await http.post(
        Uri.parse('$baseUrl/face-images/upload'),
        headers: headers,
        body: jsonEncode({
          'image_base64': base64Image,
          if (userId != null) 'user_id': userId,
          if (employeeCode != null) 'employee_code': employeeCode,
          if (replace) 'replace': true,
          if (setAsAvatar) 'set_as_avatar': true,
        }),
      );
      return jsonDecode(res.body);
    }

    return {'success': false, 'message': 'No image file or base64 data provided'};
  }

  /// Get list of all face images for an employee
  static Future<Map<String, dynamic>> getFaceImages({int? userId, String? employeeCode}) async {
    final query = <String>[];
    if (userId != null) query.add('user_id=$userId');
    if (employeeCode != null) query.add('employee_code=$employeeCode');
    final queryStr = query.isNotEmpty ? '?${query.join('&')}' : '';

    final res = await http.get(Uri.parse('$baseUrl/face-images$queryStr'), headers: await _headers());
    return jsonDecode(res.body);
  }

  /// Delete a face image by ID
  static Future<Map<String, dynamic>> deleteFaceImage(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/face-images/$id'), headers: await _headers());
    return jsonDecode(res.body);
  }

  /// Get all staff registered with face images (for local matching in kiosk/terminal)
  static Future<Map<String, dynamic>> getRegisteredStaffFaces({int? companyId, int? departmentId}) async {
    final query = <String>[];
    if (companyId != null) query.add('company_id=$companyId');
    if (departmentId != null) query.add('department_id=$departmentId');
    final queryStr = query.isNotEmpty ? '?${query.join('&')}' : '';

    final res = await http.get(Uri.parse('$baseUrl/face-images/registered-staff$queryStr'), headers: await _headers());
    return jsonDecode(res.body);
  }
}
