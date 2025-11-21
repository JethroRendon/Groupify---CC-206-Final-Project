import 'api_client.dart';
import 'auth_service.dart';

class ActivitiesService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  Future<void> _setToken() async {
    final token = await _authService.getToken();
    _apiClient.setToken(token);
  }

  Future<List<dynamic>> getGroupActivities(String groupId, {int limit = 20}) async {
    await _setToken();
    final response = await _apiClient.get('/activities/group/$groupId?limit=$limit');
    return response['activities'] ?? [];
  }

  // Aggregate activities across all provided group IDs and sort by timestamp desc.
  Future<List<dynamic>> getActivitiesForGroups(List<String> groupIds, {int perGroupLimit = 10}) async {
    final futures = <Future<List<dynamic>>>[];
    for (final gid in groupIds) {
      futures.add(getGroupActivities(gid, limit: perGroupLimit).catchError((_) => <dynamic>[]));
    }
    final results = await Future.wait(futures);
    final all = results.expand((r) => r).toList();
    all.sort((a, b) {
      final ta = _tsMillis(a['timestamp']);
      final tb = _tsMillis(b['timestamp']);
      return tb.compareTo(ta); // newest first
    });
    return all;
  }

  int _tsMillis(dynamic ts) {
    if (ts == null) return 0;
    try {
      final s = ts['_seconds'] ?? ts['seconds'];
      final ns = ts['_nanoseconds'] ?? ts['nanoseconds'] ?? 0;
      if (s is int) return s * 1000 + (ns is int ? (ns / 1000000).round() : 0);
    } catch (_) {}
    return 0;
  }

  Future<void> clearGroupActivities(String groupId) async {
    await _setToken();
    await _apiClient.delete('/activities/group/$groupId/clear');
  }

  Future<void> clearActivitiesForGroups(List<String> groupIds) async {
    for (final gid in groupIds) {
      try { await clearGroupActivities(gid); } catch (_) {}
    }
  }
}
