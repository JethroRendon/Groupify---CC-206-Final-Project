import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<String?> getToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      return user != null ? await user.getIdToken() : null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String school,
    required String course,
    required String yearLevel,
    required String section,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(fullName);
      final token = await userCredential.user?.getIdToken();

      // Direct HTTP call without ApiClient
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'school': school,
          'course': course,
          'yearLevel': yearLevel,
          'section': section,
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token ?? '');
      await prefs.setString('user_uid', userCredential.user?.uid ?? '');

      return json.decode(response.body);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<Map<String, dynamic>> signIn({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final token = await userCredential.user?.getIdToken();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token ?? '');
      await prefs.setString('user_uid', userCredential.user?.uid ?? '');

      return {'success': true, 'user': {'uid': userCredential.user?.uid}};
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }

  User? getCurrentUser() => _firebaseAuth.currentUser;

  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use': return 'Email already registered';
        case 'invalid-email': return 'Invalid email';
        case 'weak-password': return 'Password too weak';
        case 'user-not-found': return 'User not found';
        case 'wrong-password': return 'Incorrect password';
        default: return error.message ?? 'Authentication failed';
      }
    }
    return error.toString();
  }
}