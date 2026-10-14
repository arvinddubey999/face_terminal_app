import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
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
      final fcmToken = await messaging.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ApiService.saveFcmToken(fcmToken);
        await ApiService.registerFcmToken(fcmToken);
      }
      await messaging.subscribeToTopic('attendance');
    } catch (e) {
      debugPrint("FCM notification setup info: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
