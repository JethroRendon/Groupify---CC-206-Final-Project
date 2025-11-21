import 'api_client.dart';
import 'auth_service.dart';
import 'data_cache.dart';

class NotificationsService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final DataCache _cache = DataCache();

  Future<void> _setToken() async {
    final token = await _authService.getToken();
    _apiClient.setToken(token);
  }

  Future<List<dynamic>> getMyNotifications() async {
    final cached = _cache.get<List<dynamic>>('my_notifications');
    if (cached != null) return cached;
    await _setToken();
    final resp = await _apiClient.get('/notifications/my');
    final list = resp['notifications'] ?? [];
    _cache.set('my_notifications', list, ttl: const Duration(seconds: 20));
    return list;
  }

  Future<void> markRead(String id) async {
    await _setToken();
    try {
      final resp = await _apiClient.patch('/notifications/$id/read', {});
      if (resp is Map && resp['success'] != true) {
        throw ApiException(statusCode: 500, message: 'Mark read failed');
      }
      _cache.invalidate('my_notifications');
    } catch (e) {
      print('❌ markRead error: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    await _setToken();
    try {
      final resp = await _apiClient.delete('/notifications/clear');
      if (resp is Map && resp['success'] != true) {
        throw ApiException(statusCode: 500, message: 'Clear notifications failed');
      }
      _cache.invalidate('my_notifications');
    } catch (e) {
      print('❌ clearAll error: $e');
      rethrow;
    }
  }
}