import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'api_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class FilesService {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> uploadFile({
    List<int>? fileBytes,
    String? filePath,
    required String fileName,
    required String groupId,
    String? description,
  }) async {
    try {
      print('[FilesService] Starting upload for $fileName');
      final token = await _authService.getToken();
      print('[FilesService] Got auth token');
      final uri = Uri.parse('${ApiConfig.baseUrl}/files/upload');
      print('[FilesService] Upload URL: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['groupId'] = groupId;
      if (description != null) request.fields['description'] = description;
      
      // Use filePath for mobile, fileBytes for web
      if (filePath != null && !kIsWeb) {
        print('[FilesService] Using file path: $filePath');
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ));
      } else if (fileBytes != null) {
        print('[FilesService] Using file bytes, size: ${fileBytes.length} bytes');
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ));
      } else {
        throw Exception('Either filePath or fileBytes must be provided');
      }

      print('[FilesService] Sending request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Upload timeout - file may be too large or network is slow');
        },
      );
      print('[FilesService] Got response: ${streamedResponse.statusCode}');
      
      final response = await http.Response.fromStream(streamedResponse);
      print('[FilesService] Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        throw Exception('Upload failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('[FilesService] Upload error: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<List<dynamic>> getFilesByGroup(String groupId, {bool signed = false}) async {
    await _setToken();
    final endpoint = '/files/group/$groupId${signed ? '?signed=1' : ''}';
    final response = await _apiClient.get(endpoint);
    return response['files'] ?? [];
  }

  Future<void> deleteFile(String fileId) async {
    await _setToken();
    await _apiClient.delete('/files/$fileId');
  }

  Future<void> _setToken() async {
    final token = await _authService.getToken();
    _apiClient.setToken(token);
  }
}