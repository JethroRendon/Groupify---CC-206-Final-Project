import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'dashboard.dart';

class DebugSignupScreen extends StatefulWidget {
  const DebugSignupScreen({super.key});

  @override
  State<DebugSignupScreen> createState() => _DebugSignupScreenState();
}

class _DebugSignupScreenState extends State<DebugSignupScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  String _status = '';

  Future<void> _testSignup() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting signup...';
    });

    try {
      // Test data
      final testData = {
        'fullName': 'Test User',
        'email': 'test${DateTime.now().millisecondsSinceEpoch}@test.com',
        'password': 'Test123456',
        'school': 'Test University',
        'course': 'Computer Science',
        'yearLevel': '3rd Year',
        'section': 'A',
      };

      setState(() => _status = 'Creating account with: ${testData['email']}');

      final result = await _authService.signUp(
        fullName: testData['fullName']!,
        email: testData['email']!,
        password: testData['password']!,
        school: testData['school']!,
        course: testData['course']!,
        yearLevel: testData['yearLevel']!,
        section: testData['section']!,
      );

      setState(() => _status = 'Success! ✅\n${result.toString()}');

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _status = 'Error ❌:\n$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Signup')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _testSignup,
                child: const Text('Test Signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}