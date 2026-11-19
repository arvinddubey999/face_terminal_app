import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/task_detail_screen.dart';
import 'services/api_service.dart';
import 'models/user_model.dart';
import 'models/task_model.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel attendanceChannel = AndroidNotificationChannel(
  'attendance_channel',
  'Attendance Updates',
  description: 'Notifications for employee punch in, punch out, and status',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
  'task_channel',
  'Task Management Updates',
  description: 'Notifications for task creation, assignments, and reminders',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

void handleNotificationNavigation(Map<String, dynamic> data) async {
  debugPrint("handleNotificationNavigation called with: $data");
  final taskIdStr = data['task_id'];
  if (taskIdStr != null && taskIdStr.toString().isNotEmpty) {
    final taskId = int.tryParse(taskIdStr.toString());
    if (taskId != null) {
      try {
        final res = await ApiService.getTaskDetails(taskId);
        final taskData = res['task'] ?? res['data'];
        if (taskData != null) {
          final task = TaskModel.fromJson(taskData);
          UserModel? user;
          try {
            final userRes = await ApiService.me();
            if (userRes['user'] != null) {
              user = UserModel.fromJson(userRes['user']);
            }
          } catch (_) {}
          user ??= UserModel(
            id: int.tryParse(data['user_id']?.toString() ?? '0') ?? 0,
            firstName: data['user_name']?.toString() ?? 'Employee',
            lastName: '',
            name: data['user_name']?.toString() ?? 'Employee',
            phone: '',
            role: 'employee',
            mobileAttendance: true,
            multipleAttendance: false,
            aiSelfie: false,
          );
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.push(
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task, user: user!)),
            );
            return;
          }
        }
      } catch (e) {
        debugPrint("Error opening task from notification: $e");
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint("Handling background FCM message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(attendanceChannel);
      await androidImplementation.createNotificationChannel(taskChannel);
      await androidImplementation.requestNotificationsPermission();
    }

    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: initSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!);
            handleNotificationNavigation(Map<String, dynamic>.from(data));
          } catch (_) {}
        }
      },
    );
  } catch (e) {
    debugPrint("Firebase init info: $e");
  }
  runApp(const TulsiHrmsApp());
}

class TulsiHrmsApp extends StatefulWidget {
  const TulsiHrmsApp({super.key});

  @override
  State<TulsiHrmsApp> createState() => _TulsiHrmsAppState();
}

class _TulsiHrmsAppState extends State<TulsiHrmsApp> {
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _setupNotificationHandlers();
  }

  void _setupNotificationHandlers() {
    // 1. Foreground message handler: Display heads-up banner notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Foreground Message: ${message.notification?.title} - ${message.notification?.body}");
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        final isTask = data['type'] == 'task' || data.containsKey('task_id');
        final channel = isTask ? taskChannel : attendanceChannel;

        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
            ),
          ),
          payload: jsonEncode(data),
        );
      }
    });

    // 2. Background tap handler (app in background but running)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM onMessageOpenedApp tapped: ${message.data}");
      handleNotificationNavigation(message.data);
    });

    // 3. Terminated tap handler (app was closed completely)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("FCM getInitialMessage tapped: ${message.data}");
        handleNotificationNavigation(message.data);
      }
    });
  }

  void _checkInitialAuth() async {
    try {
      final token = await ApiService.getToken();
      if (token != null && token.isNotEmpty) {
        final res = await ApiService.me();
        if (res['user'] != null) {
          setState(() {
            _currentUser = UserModel.fromJson(res['user']);
            _isLoading = false;
          });

          // Register FCM Token & Subscribe to Push Notification Topic
          _initFirebasePushNotifications();
          return;
        }
      }
    } catch (e) {
      debugPrint("Auth check error: $e");
    }
    setState(() => _isLoading = false);
  }

  void _initFirebasePushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      String? fcmToken;
      try {
        fcmToken = await messaging.getToken().timeout(const Duration(seconds: 6), onTimeout: () => null);
      } catch (e) {
        debugPrint("FCM getToken error in main: $e");
      }
      fcmToken ??= await ApiService.getSavedFcmToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ApiService.saveFcmToken(fcmToken);
        await ApiService.registerFcmToken(fcmToken, userId: _currentUser?.id);
      }
      messaging.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty) {
          ApiService.saveFcmToken(newToken);
          ApiService.registerFcmToken(newToken, userId: _currentUser?.id);
        }
      });
      await messaging.subscribeToTopic('attendance');
      await messaging.subscribeToTopic('tasks');
      if (_currentUser != null) {
        await messaging.subscribeToTopic('user_${_currentUser!.id}');
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        for (final delay in [2, 5, 10, 20]) {
          await Future.delayed(Duration(seconds: delay));
          try {
            final retryToken = await messaging.getToken().timeout(const Duration(seconds: 6), onTimeout: () => null);
            if (retryToken != null && retryToken.isNotEmpty) {
              await ApiService.saveFcmToken(retryToken);
              await ApiService.registerFcmToken(retryToken, userId: _currentUser?.id);
              await messaging.subscribeToTopic('attendance');
              await messaging.subscribeToTopic('tasks');
              if (_currentUser != null) {
                await messaging.subscribeToTopic('user_${_currentUser!.id}');
              }
              break;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("FCM notification setup info: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Tulsi Fabrics HRMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF111111),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5A1F),
          primary: const Color(0xFF111111),
          secondary: const Color(0xFFFF5A1F),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Color(0xFF111111),
              body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A1F))),
            )
          : (_currentUser != null ? DashboardScreen(user: _currentUser!) : const LoginScreen()),
    );
  }
}
