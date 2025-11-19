import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_client.dart';


class ApiClient {
  // Remove AuthService dependency!
  String? _cachedToken;

  // Method to set token from outside
  void setToken(String? token) {
    _cachedToken = token;
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    
    if (requiresAuth && _cachedToken != null) {
      headers['Authorization'] = 'Bearer $_cachedToken';
    }
    
    return headers;
  }

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.get(url, headers: headers).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String endpoint, dynamic body, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.post(url, headers: headers, body: json.encode(body)).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String endpoint, dynamic body, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.put(url, headers: headers, body: json.encode(body)).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.delete(url, headers: headers).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  dynamic _handleResponse(http.Response response) {
    final body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw ApiException(statusCode: response.statusCode, message: body['error'] ?? 'Unknown error');
    }
  }

  String _handleError(dynamic error) {
    print('API Error Details: $error');
    if (error is SocketException) return 'No internet connection';
    if (error is HttpException) return 'Server error';
    if (error is ApiException) return error.message;
    return 'Something went wrong';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});
  @override
  String toString() => message;
}