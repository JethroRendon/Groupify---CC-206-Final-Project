import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  Future<void> _setToken() async {
    final token = await _authService.getToken();
    _apiClient.setToken(token);
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    await _setToken();
    return await _apiClient.get('/user/profile');
  }

  Future<void> updateProfile({
    String? fullName,
    String? school,
    String? course,
    String? yearLevel,
    String? section,
  }) async {
    await _setToken();
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (school != null) body['school'] = school;
    if (course != null) body['course'] = course;
    if (yearLevel != null) body['yearLevel'] = yearLevel;
    if (section != null) body['section'] = section;
    await _apiClient.put('/user/profile', body);
    // If fullName was updated, also update Firebase Auth display name so
    // UI that reads from FirebaseAuth.currentUser shows the new name.
    if (fullName != null && fullName.trim().isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(fullName.trim());
        }
      } catch (e) {
        print('⚠️ Failed to update FirebaseAuth displayName: $e');
      }
    }
  }

  Future<String?> uploadProfilePicture(XFile imageFile) async {
    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final uri = Uri.parse('${ApiConfig.baseUrl}/user/profile-picture');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      
      // Read file bytes directly - works on both web and mobile
      final bytes = await imageFile.readAsBytes();
      
      final multipartFile = http.MultipartFile.fromBytes(
        'profilePicture',
        bytes,
        filename: imageFile.name,
        contentType: MediaType('image', 'jpeg'),
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['profilePicture'];
        }
      }
      
      throw Exception('Failed to upload profile picture');
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      rethrow;
    }
  }
}