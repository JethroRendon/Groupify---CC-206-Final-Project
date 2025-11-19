import 'api_client.dart';
import 'auth_service.dart';

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
  }
}