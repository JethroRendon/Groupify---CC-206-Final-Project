import 'api_client.dart';
import 'auth_service.dart';
import 'data_cache.dart';

class GroupsService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final DataCache _cache = DataCache();

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
    final cached = _cache.get<List<dynamic>>('my_groups');
    if (cached != null) return cached;
    await _setToken();
    final response = await _apiClient.get('/groups/my-groups');
    final groups = response['groups'] ?? [];
    _cache.set('my_groups', groups, ttl: const Duration(seconds: 30));
    return groups;
  }

  Future<Map<String, dynamic>> getGroupById(String groupId) async {
    await _setToken();
    return await _apiClient.get('/groups/$groupId');
  }

  Future<List<dynamic>> getGroupMembers(String groupId) async {
    await _setToken();
    final response = await _apiClient.get('/groups/$groupId/members');
    return response['members'] ?? [];
  }

  Future<Map<String, dynamic>> joinGroup(String accessCode) async {
    await _setToken();
    return await _apiClient.post('/groups/join', {'accessCode': accessCode});
  }

  Future<void> leaveGroup(String groupId) async {
    await _setToken();
    await _apiClient.post('/groups/$groupId/leave', {});
    _cache.invalidate('my_groups');
  }

  Future<void> updateGroup(String groupId, {String? name, String? description, String? subject}) async {
    await _setToken();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (subject != null) body['subject'] = subject;
    await _apiClient.put('/groups/$groupId', body);
    _cache.invalidate('my_groups');
  }

  Future<void> deleteGroup(String groupId) async {
    await _setToken();
    await _apiClient.delete('/groups/$groupId');
    _cache.invalidate('my_groups');
  }
}