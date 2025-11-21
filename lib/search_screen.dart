import 'package:flutter/material.dart';
import 'services/tasks_service.dart';
import 'services/groups_service.dart';
import 'services/files_service.dart';
import 'task_screen.dart';
import 'file_screen.dart';
import 'groups_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TasksService _tasksService = TasksService();
  final GroupsService _groupsService = GroupsService();
  final FilesService _filesService = FilesService();

  bool _isSearching = false;
  List<dynamic> _taskResults = [];
  List<dynamic> _fileResults = [];
  List<dynamic> _groupResults = [];
  List<dynamic> _memberResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _taskResults = [];
        _fileResults = [];
        _groupResults = [];
        _memberResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final lowercaseQuery = query.toLowerCase();

      // Search tasks
      final allTasks = await _tasksService.getMyTasks();
      final tasks = allTasks.where((task) {
        final title = (task['title'] ?? '').toString().toLowerCase();
        final desc = (task['description'] ?? '').toString().toLowerCase();
        return title.contains(lowercaseQuery) || desc.contains(lowercaseQuery);
      }).toList();

      // Search groups and members
      final allGroups = await _groupsService.getMyGroups();
      final groups = allGroups.where((group) {
        final name = (group['name'] ?? '').toString().toLowerCase();
        final subject = (group['subject'] ?? '').toString().toLowerCase();
        return name.contains(lowercaseQuery) || subject.contains(lowercaseQuery);
      }).toList();

      // Search for members across all groups
      final List<Map<String, dynamic>> members = [];
      for (var group in allGroups) {
        try {
          final groupMembers = await _groupsService.getGroupMembers(group['id']);
          for (var member in groupMembers) {
            final fullName = (member['fullName'] ?? '').toString().toLowerCase();
            final email = (member['email'] ?? '').toString().toLowerCase();
            if (fullName.contains(lowercaseQuery) || email.contains(lowercaseQuery)) {
              members.add({
                ...member,
                'groupName': group['name'],
                'groupId': group['id'],
              });
            }
          }
        } catch (e) {
          print('Error loading members for group ${group['id']}: $e');
        }
      }

      // Search files
      final List<dynamic> files = [];
      for (var group in allGroups) {
        try {
          final groupFiles = await _filesService.getFilesByGroup(group['id']);
          final matchingFiles = groupFiles.where((file) {
            final fileName = (file['fileName'] ?? '').toString().toLowerCase();
            return fileName.contains(lowercaseQuery);
          }).toList();
          files.addAll(matchingFiles);
        } catch (e) {
          print('Error loading files for group ${group['id']}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _taskResults = tasks;
          _fileResults = files;
          _groupResults = groups;
          _memberResults = members;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalResults = _taskResults.length + 
                         _fileResults.length + 
                         _groupResults.length + 
                         _memberResults.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 1, color: Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    _performSearch(value);
                  } else {
                    setState(() {
                      _taskResults = [];
                      _fileResults = [];
                      _groupResults = [];
                      _memberResults = [];
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search tasks, files, groups, members...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _taskResults = [];
                              _fileResults = [];
                              _groupResults = [];
                              _memberResults = [];
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchController.text.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Search for tasks, files, groups, or members',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      )
                    : totalResults == 0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No results found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Tasks Section
                              if (_taskResults.isNotEmpty) ...[
                                _buildSectionHeader('Tasks', _taskResults.length),
                                ..._taskResults.map((task) => _buildTaskItem(task)),
                                const SizedBox(height: 16),
                              ],

                              // Files Section
                              if (_fileResults.isNotEmpty) ...[
                                _buildSectionHeader('Files', _fileResults.length),
                                ..._fileResults.map((file) => _buildFileItem(file)),
                                const SizedBox(height: 16),
                              ],

                              // Groups Section
                              if (_groupResults.isNotEmpty) ...[
                                _buildSectionHeader('Groups', _groupResults.length),
                                ..._groupResults.map((group) => _buildGroupItem(group)),
                                const SizedBox(height: 16),
                              ],

                              // Members Section
                              if (_memberResults.isNotEmpty) ...[
                                _buildSectionHeader('Members', _memberResults.length),
                                ..._memberResults.map((member) => _buildMemberItem(member)),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskItem(dynamic task) {
    final status = (task['status'] ?? 'To Do').toString();
    final dueDate = task['dueDate'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.task_alt, color: Color(0xFF3B82F6)),
        title: Text(
          task['title'] ?? 'Untitled Task',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task['description'] != null && task['description'].toString().isNotEmpty)
              Text(
                task['description'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Outfit'),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      color: _getStatusTextColor(status),
                    ),
                  ),
                ),
                if (dueDate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatDueDate(dueDate),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Outfit'),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TasksScreen(initialFilter: status),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileItem(dynamic file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file, color: Color(0xFF3B82F6)),
        title: Text(
          file['fileName'] ?? 'Untitled File',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _formatFileSize(file['size']),
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FilesScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupItem(dynamic group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.group, color: Color(0xFF3B82F6)),
        title: Text(
          group['name'] ?? 'Untitled Group',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          group['subject'] ?? '',
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroupsScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberItem(dynamic member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF3B82F6),
          child: Text(
            _getInitials(member['fullName'] ?? member['email'] ?? 'U'),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          member['fullName'] ?? member['email'] ?? 'Unknown',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'in ${member['groupName'] ?? 'Unknown Group'}',
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroupsScreen(),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'to do':
        return const Color(0xFFFEF3C7);
      case 'in progress':
        return const Color(0xFFDBEAFE);
      case 'done':
        return const Color(0xFFE0FEDB);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'to do':
        return const Color(0xFFD97706);
      case 'in progress':
        return const Color(0xFF3B82F6);
      case 'done':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDueDate(dynamic d) {
    if (d == null) return '';
    try {
      final date = DateTime.parse(d.toString());
      final diff = date.difference(DateTime.now()).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff < 0) return 'Overdue';
      return '$diff days left';
    } catch (_) {
      return '';
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    try {
      final bytes = int.parse(size.toString());
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
