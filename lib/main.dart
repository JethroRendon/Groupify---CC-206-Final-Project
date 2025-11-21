import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding.dart';
import 'dashboard.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Groupify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, primary: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Outfit',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for the Firebase auth state to initialize. On web the currentUser
    // may be null briefly until the SDK restores persistence. We listen to
    // authStateChanges for the first settled value, but add a timeout so the
    // splash doesn't hang indefinitely if something is off (fallback to currentUser).
    final firebaseUser = await FirebaseAuth.instance
      .authStateChanges()
      .first
      .timeout(const Duration(seconds: 6), onTimeout: () => FirebaseAuth.instance.currentUser);

    if (!mounted) return;

    if (firebaseUser == null) {
      print('DEBUG: No Firebase user signed in (auth state null)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
      return;
    }
    print('DEBUG: Firebase user present on splash: ${firebaseUser.uid} ${firebaseUser.email}');

    // User is signed in — verify token with backend to determine redirect
    try {
      // Refresh token to ensure server accepts it
      final token = await _authService.getToken();
      final api = ApiClient();
      api.setToken(token);

      final resp = await api.get('/auth/verify');
      var redirectTo = resp['redirectTo'] as String? ?? 'home';
      redirectTo = redirectTo.trim().toLowerCase();

      print('DEBUG: /auth/verify redirectTo => "$redirectTo"');

      if (!mounted) return;
      if (redirectTo == 'onboarding') {
        print('NAV: Navigating to Onboarding from Splash');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        print('NAV: Navigating to Home from Splash');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      // If verify fails, fall back to onboarding (or sign-in)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF3B82F6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text('Groupify', style: TextStyle(fontSize: 40, color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}