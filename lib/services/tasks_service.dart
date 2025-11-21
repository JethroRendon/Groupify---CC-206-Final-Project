import 'api_client.dart';
import 'auth_service.dart';

class TasksService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  Future<void> _setToken() async {
    final token = await _authService.getToken();
    _apiClient.setToken(token);
  }

  Future<Map<String, dynamic>> createTask({
    required String title,
    required String groupId,
    String? description,
    String? assignedTo,
    String? dueDate,
    String? priority,
  }) async {
    await _setToken();
    return await _apiClient.post('/tasks/create', {
      'title': title,
      'groupId': groupId,
      'description': description ?? '',
      'assignedTo': assignedTo,
      'dueDate': dueDate,
      'priority': priority ?? 'medium',
    });
  }

  Future<List<dynamic>> getTasksByGroup(String groupId, {String? status}) async {
    await _setToken();
    final endpoint = status != null ? '/tasks/group/$groupId?status=$status' : '/tasks/group/$groupId';
    final response = await _apiClient.get(endpoint);
    return response['tasks'] ?? [];
  }

  Future<List<dynamic>> getMyTasks({String? status}) async {
    await _setToken();
    final endpoint = status != null ? '/tasks/my-tasks?status=$status' : '/tasks/my-tasks';
    final response = await _apiClient.get(endpoint);
    return response['tasks'] ?? [];
  }

  Future<Map<String, dynamic>> getTaskById(String taskId) async {
    await _setToken();
    return await _apiClient.get('/tasks/$taskId');
  }

  Future<void> updateTask(String taskId, {
    String? title,
    String? description,
    String? assignedTo,
    String? status,
    String? dueDate,
    String? priority,
    int? progress,
  }) async {
    await _setToken();
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (assignedTo != null) body['assignedTo'] = assignedTo;
    if (status != null) body['status'] = status;
    if (dueDate != null) body['dueDate'] = dueDate;
    if (priority != null) body['priority'] = priority;
    if (progress != null) body['progress'] = progress;
    await _apiClient.put('/tasks/$taskId', body);
  }

  Future<void> deleteTask(String taskId) async {
    await _setToken();
    await _apiClient.delete('/tasks/$taskId');
  }
}