import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'get_started_slider_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLogin = prefs.getString('saved_login');
    final savedPass = prefs.getString('saved_password');
    final remember = prefs.getBool('remember_password') ?? true;

    if (remember && savedLogin != null && savedPass != null) {
      setState(() {
        _loginController.text = savedLogin;
        _passwordController.text = savedPass;
        _rememberPassword = true;
      });
    }
  }

  void _handleLogin() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (login.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter phone/email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    if (_rememberPassword) {
      await prefs.setString('saved_login', login);
      await prefs.setString('saved_password', password);
      await prefs.setBool('remember_password', true);
    } else {
      await prefs.remove('saved_login');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_password', false);
    }

    String? fcmToken;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      fcmToken = await messaging.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ApiService.saveFcmToken(fcmToken);
      }
    } catch (e) {
      debugPrint("FCM token fetch error before login: $e");
    }

    try {
      final result = await ApiService.login(login, password, fcmToken: fcmToken);
      setState(() => _isLoading = false);

      if (result['status'] == 200 && result['body']['user'] != null) {
        if (fcmToken != null && fcmToken.isNotEmpty) {
          try {
            await ApiService.registerFcmToken(fcmToken);
            await FirebaseMessaging.instance.subscribeToTopic('attendance');
          } catch (e) {
            debugPrint("Register FCM token post login error: $e");
          }
        }

        final user = UserModel.fromJson(result['body']['user']);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GetStartedSliderScreen(user: user)),
        );
      } else {
        setState(() {
          _errorMessage = result['body']['message'] ?? 'Login failed. Please check credentials.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error connecting to server: $e';
      });
    }
  }

  @override
  Widget build(BuildContext me) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5A1F),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.apartment, size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tulsi Fabrics HRMS',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111111)),
                    ),
                    const Text(
                      'Employee & Manager App Portal',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _loginController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Phone Number or Email',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFFF5A1F))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111111),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Sign In to App', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
