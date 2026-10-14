import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _loginController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  void _handleReset() async {
    final login = _loginController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (login.isEmpty || newPassword.length < 6) {
      setState(() => _message = 'Enter phone/email and a new password (min 6 chars)');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final res = await ApiService.resetPassword(login, newPassword);
    setState(() => _isLoading = false);

    if (res['status'] == 200 && res['body']['ok'] == true) {
      setState(() {
        _isSuccess = true;
        _message = 'Password reset successfully! You can now login with your new password.';
      });
    } else {
      setState(() {
        _isSuccess = false;
        _message = res['body']['message'] ?? 'Failed to reset password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: const Color(0xFF111111),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.lock_reset, size: 60, color: Color(0xFFFF5A1F)),
            const SizedBox(height: 16),
            const Text(
              'Self Password Reset',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your registered Phone Number or Email and your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(color: _isSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _loginController,
              decoration: InputDecoration(
                labelText: 'Phone Number or Email',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _handleReset,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Reset Password Now', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
