import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  String? _cachedToken;
  DateTime? _tokenExpiry;

  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;

      // Reuse cached token if not forcing refresh and still valid (2 min safety window)
      if (!forceRefresh && _cachedToken != null && _tokenExpiry != null) {
        final now = DateTime.now();
        if (now.isBefore(_tokenExpiry!.subtract(const Duration(minutes: 2)))) {
          return _cachedToken;
        }
      }

      final token = await user.getIdToken(forceRefresh);
      if (token == null) return null;

      // Decode JWT to extract exp
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(_normalize(parts[1])));
          final data = json.decode(payload);
          final exp = data['exp'];
          if (exp is int) {
            _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            _cachedToken = token;
          }
        }
      } catch (_) {
        // Fallback: assume 55 minutes validity
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        _cachedToken = token;
      }
      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  String _normalize(String str) {
    // Pad base64 url string if necessary
    return str.padRight(str.length + (4 - str.length % 4) % 4, '=');
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
      print('📝 Creating Firebase user...');
      
      // Create Firebase Auth user
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(fullName);
      final token = await userCredential.user?.getIdToken();
      
      print('✅ Firebase user created: ${userCredential.user?.uid}');
      print('🔑 Token obtained: ${token?.substring(0, 20)}...');

      // Call backend to create user document in Firestore
      print('📡 Calling backend signup...');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Include token
        },
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

      print('📥 Backend response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      // Save credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token ?? '');
      await prefs.setString('user_uid', userCredential.user?.uid ?? '');
      
      print('💾 Saved token and UID to SharedPreferences');
      // Ensure user document exists in Firestore (client-side fallback)
      try {
        final uid = userCredential.user?.uid;
        if (uid != null) {
          final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
          final now = DateTime.now().toIso8601String();
          final userData = {
            'uid': uid,
            'fullName': fullName,
            'email': email.toLowerCase(),
            'school': school,
            'course': course,
            'yearLevel': yearLevel,
            'section': section,
            'hasSeenOnboarding': true,
            'groupIds': [],
            'createdAt': now,
            'lastLogin': now,
          };
          await docRef.set(userData, SetOptions(merge: true));
          print('✅ Client-side: ensured Firestore user document for UID: $uid');
        }
      } catch (e) {
        print('⚠️ Failed to create Firestore user doc on client: $e');
      }

      // Persist profile fields locally so ProfileScreen can show them immediately
      await prefs.setString('profile_fullName', fullName);
      await prefs.setString('profile_email', email.toLowerCase());
      await prefs.setString('profile_school', school);
      await prefs.setString('profile_course', course);
      await prefs.setString('profile_yearLevel', yearLevel);
      await prefs.setString('profile_section', section);
      print('💾 Saved profile fields to SharedPreferences');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        // Log backend error but still return success object from client-side creation
        print('⚠️ Backend signup failed: ${response.statusCode} ${response.body}');
        return {
          'success': true,
          'message': 'Account created locally; backend signup returned ${response.statusCode}',
          'user': {'uid': userCredential.user?.uid, 'fullName': fullName, 'email': email}
        };
      }
    } catch (e) {
      print('❌ Signup error: $e');
      throw _handleAuthError(e);
    }
  }

  Future<Map<String, dynamic>> signIn({required String email, required String password}) async {
    try {
      print('🔐 Signing in...');
      
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final token = await userCredential.user?.getIdToken(true);
      print('✅ Signed in: ${userCredential.user?.uid}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token ?? '');
      await prefs.setString('user_uid', userCredential.user?.uid ?? '');

      // Try to read the Firestore user document and cache profile fields locally
      try {
        final uid = userCredential.user?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            final fullName = (data['fullName'] as String?) ?? '';
            final school = (data['school'] as String?) ?? '';
            final section = (data['section'] as String?) ?? '';
            final course = (data['course'] as String?) ?? '';
            final yearLevel = (data['yearLevel'] as String?) ?? '';

            if (fullName.isNotEmpty) {
              await prefs.setString('profile_fullName', fullName);
              try {
                await userCredential.user?.updateDisplayName(fullName);
              } catch (_) {}
            }
            if (school.isNotEmpty) await prefs.setString('profile_school', school);
            if (section.isNotEmpty) await prefs.setString('profile_section', section);
            if (course.isNotEmpty) await prefs.setString('profile_course', course);
            if (yearLevel.isNotEmpty) await prefs.setString('profile_yearLevel', yearLevel);

            print('💾 Cached profile fields from Firestore for UID: $uid');
          }
        }
      } catch (e) {
        print('⚠️ Failed to cache profile fields on signIn: $e');
      }

      return {'success': true, 'user': {'uid': userCredential.user?.uid}};
    } catch (e) {
      // Improved diagnostics for FirebaseAuth errors
      if (e is FirebaseAuthException) {
        print('❌ Sign in FirebaseAuthException code=${e.code} message=${e.message}');
        // Re-map known codes to friendly messages
        throw _handleAuthError(e);
      }
      print('❌ Sign in error: $e');
      throw _handleAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    final user = _firebaseAuth.currentUser;
    print('👤 Current user: ${user?.uid}');
    return user != null;
  }

  User? getCurrentUser() => _firebaseAuth.currentUser;

  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use': return 'Email already registered';
        case 'invalid-email': return 'Invalid email';
        case 'weak-password': return 'Password too weak';
        case 'user-not-found': return 'User not found';
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Incorrect email or password';
        case 'user-disabled':
          return 'This account has been disabled';
        default: return error.message ?? 'Authentication failed';
      }
    }
    return error.toString();
  }
}