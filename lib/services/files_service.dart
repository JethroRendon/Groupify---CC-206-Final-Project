import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'api_client.dart';
import 'package:flutter/material.dart';


class FilesService {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> uploadFile({
    required List<int> fileBytes,
    required String fileName,
    required String groupId,
    String? description,
  }) async {
    try {
      print('[FilesService] Starting upload for $fileName, size: ${fileBytes.length} bytes');
      final token = await _authService.getToken();
      print('[FilesService] Got auth token');
      final uri = Uri.parse('${ApiConfig.baseUrl}/files/upload');
      print('[FilesService] Upload URL: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['groupId'] = groupId;
      if (description != null) request.fields['description'] = description;
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ));

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