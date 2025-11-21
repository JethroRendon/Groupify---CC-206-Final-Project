import 'api_client.dart';
import 'auth_service.dart';

class DashboardService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _auth = AuthService();

  Future<void> _ensureToken() async {
    final t = await _auth.getToken();
    _apiClient.setToken(t);
  }

  Future<Map<String, dynamic>> getOverview() async {
    await _ensureToken();
    final resp = await _apiClient.get('/dashboard/overview');
    return (resp['overview'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  }
}