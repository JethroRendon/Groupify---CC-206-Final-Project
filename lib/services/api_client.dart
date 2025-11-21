import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  // In-flight request dedup map: key -> Future
  static final Map<String, Future<dynamic>> _inFlight = {};

  factory ApiClient() => _instance;

  ApiClient._internal();

  String? _cachedToken;

  void setToken(String? token) {
    _cachedToken = token;
    try {
      print('🔑 ApiClient token set: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
    } catch (_) {
      print('🔑 ApiClient token set (masked)');
    }
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    
    if (requiresAuth && _cachedToken != null) {
      headers['Authorization'] = 'Bearer $_cachedToken';
      print('📤 Request headers include Authorization');
    } else if (requiresAuth && _cachedToken == null) {
      print('⚠️ Warning: Auth required but no token available');
    }
    
    return headers;
  }

  // Coalesced GET: Deduplicate concurrent identical GET requests.
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final key = 'GET:$endpoint';
    if (_inFlight.containsKey(key)) {
      print('🔁 Coalesced GET $endpoint (reusing in-flight future)');
      return _inFlight[key]!; // Return existing future
    }

    final completer = Completer<dynamic>();
    _inFlight[key] = completer.future;

    () async {
      try {
        final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
        print('📡 GET: $url');
        final headers = await _getHeaders(requiresAuth: requiresAuth);
        final response = await http.get(url, headers: headers).timeout(ApiConfig.timeout);
        print('📥 Response: ${response.statusCode}');
        final parsed = _handleResponse(response);
        completer.complete(parsed);
      } catch (e) {
        print('❌ GET Error: $e');
        completer.completeError(_handleError(e));
      } finally {
        _inFlight.remove(key);
      }
    }();

    return completer.future;
  }
  
  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      print('📡 DELETE: $url');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.delete(url, headers: headers).timeout(ApiConfig.timeout);
      print('📥 Response: ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ DELETE Error: $e');
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String endpoint, dynamic body, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      print('📡 POST: $url');
      print('📤 Body: ${json.encode(body)}');
      
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.post(
        url, 
        headers: headers, 
        body: json.encode(body)
      ).timeout(ApiConfig.timeout);
      
      print('📥 Response: ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ POST Error: $e');
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String endpoint, dynamic body, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      print('📡 PUT: $url');
      
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.put(
        url, 
        headers: headers, 
        body: json.encode(body)
      ).timeout(ApiConfig.timeout);
      
      print('📥 Response: ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ PUT Error: $e');
      throw _handleError(e);
    }
  }

  Future<dynamic> patch(String endpoint, dynamic body, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      print('📡 PATCH: $url');
      print('📤 Body: ${json.encode(body)}');

      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.patch(
        url,
        headers: headers,
        body: json.encode(body),
      ).timeout(ApiConfig.timeout);

      print('📥 Response: ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      print('❌ PATCH Error: $e');
      throw _handleError(e);
    }
  }

  

  dynamic _handleResponse(http.Response response) {
    print('📄 Response body: ${response.body}');
    
    try {
      final body = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        final debug = body is Map && body.containsKey('debugError') ? body['debugError'] : null;
        final message = (body is Map && body.containsKey('error')) ? body['error'] : 'Unknown error';
        if (debug != null) {
          print('🛠️ Server debugError: $debug');
        }
        throw ApiException(
          statusCode: response.statusCode, 
          message: debug != null ? '$message - debug: $debug' : message
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to parse response: ${response.body}'
      );
    }
  }

  String _handleError(dynamic error) {
    print('❌ API Error: $error');
    
    if (error is SocketException) return 'No internet connection';
    if (error is HttpException) return 'Server error';
    if (error is ApiException) return error.message;
    return 'Something went wrong: $error';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException({required this.statusCode, required this.message});
  
  @override
  String toString() => message;
}