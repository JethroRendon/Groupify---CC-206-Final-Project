import 'api_client.dart';
import 'auth_service.dart';

class GroupsService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  Future<void> _setToken() async {
    final token = await _authService.getToken();
    _apiClient.setToken(token);
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String subject,
    String? description,
  }) async {
    await _setToken();
    return await _apiClient.post('/groups/create', {
      'name': name,
      'subject': subject,
      'description': description ?? '',
    });
  }

  Future<List<dynamic>> getMyGroups() async {
    await _setToken();
    final response = await _apiClient.get('/groups/my-groups');
    return response['groups'] ?? [];
  }

  Future<Map<String, dynamic>> getGroupById(String groupId) async {
    await _setToken();
    return await _apiClient.get('/groups/$groupId');
  }

  Future<Map<String, dynamic>> joinGroup(String accessCode) async {
    await _setToken();
    return await _apiClient.post('/groups/join', {'accessCode': accessCode});
  }

  Future<void> leaveGroup(String groupId) async {
    await _setToken();
    await _apiClient.post('/groups/$groupId/leave', {});
  }

  Future<void> updateGroup(String groupId, {String? name, String? description, String? subject}) async {
    await _setToken();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (subject != null) body['subject'] = subject;
    await _apiClient.put('/groups/$groupId', body);
  }

  Future<void> deleteGroup(String groupId) async {
    await _setToken();
    await _apiClient.delete('/groups/$groupId');
  }
}