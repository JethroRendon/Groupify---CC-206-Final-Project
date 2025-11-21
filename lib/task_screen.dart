import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard.dart';
import 'file_screen.dart';
import 'new_task_screen.dart';
import 'profilescreen.dart';
import 'services/tasks_service.dart';
import 'services/notifications_service.dart';
import 'services/groups_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.initialFilter});
  final String? initialFilter; // 'All', 'To Do', 'In Progress', 'Done'
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _selectedBottomNavIndex = 1;
  String _selectedTaskFilter = 'To Do';
  final TasksService _tasksService = TasksService();
  final NotificationsService _notificationsService = NotificationsService();
  final GroupsService _groupsService = GroupsService();
  bool _isLoading = false; // start false so initial load executes
  List<dynamic> _allTasks = [];
  List<dynamic> _filteredTasks = [];
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  final List<String> _taskFilters = ['All', 'To Do', 'In Progress', 'Done'];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null && _taskFilters.contains(widget.initialFilter)) {
      _selectedTaskFilter = widget.initialFilter!;
    }
    _loadTasks();
    _loadNotifications();
  }

  Future<void> _loadTasks() async {
    if (_isLoading) return; // prevent overlapping loads
    final start = DateTime.now();
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _allTasks = [];
          _filteredTasks = [];
          _isLoading = false;
        });
        return;
      }
      final tasks = await _tasksService.getMyTasks();
      setState(() {
        _allTasks = tasks;
        _filterTasks();
        _isLoading = false;
      });
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      // ignore: avoid_print
      print('[TaskScreen] Tasks loaded in ${elapsed}ms');
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _allTasks = [];
        _filteredTasks = [];
        _isLoading = false;
      });
    }
  }

  void _filterTasks() {
    setState(() {
      if (_selectedTaskFilter == 'All') {
        _filteredTasks = List.from(_allTasks);
      } else {
        _filteredTasks = _allTasks
            .where((t) => t['status']
                .toString()
                .toLowerCase() == _selectedTaskFilter.toLowerCase())
            .toList();
      }
    });
  }

  Future<void> _loadNotifications() async {
    try {
      final list = await _notificationsService.getMyNotifications();
      int unread = 0;
      for (final n in list) {
        if (n['read'] != true) unread++;
      }
      if (mounted) {
        setState(() {
          _notifications = list;
          _unreadCount = unread;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  void _showNotifications() async {
    await _loadNotifications();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications', style: TextStyle(fontFamily: 'Outfit')),
        content: SizedBox(
          width: double.maxFinite,
          child: _notifications.isEmpty
              ? const Text('No notifications')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  itemBuilder: (c, i) {
                    final n = _notifications[i];
                    return ListTile(
                      title: Text(n['message'] ?? '',
                          style: const TextStyle(fontFamily: 'Outfit')),
                      subtitle: Text((n['type'] ?? '').toString(),
                          style: const TextStyle(fontFamily: 'Outfit')),
                      trailing: n['read'] == true
                          ? const Icon(Icons.check,
                              color: Colors.green, size: 18)
                          : TextButton(
                              onPressed: () async {
                                await _notificationsService.markRead(n['id']);
                                Navigator.pop(context);
                                _loadNotifications();
                              },
                              child: const Text('Mark read'),
                            ),
                    );
                  },
                ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                try {
                  await _notificationsService.clearAll();
                  Navigator.pop(context);
                  _loadNotifications();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications cleared'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to clear notifications: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
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

  Color _getStatusTextColor(String s) {
    switch (s.toLowerCase()) {
      case 'to do':
        return const Color(0xFFD97706);
      case 'in progress':
        return const Color(0xFF2563EB);
      case 'done':
        return const Color(0xFF40C721);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDueDate(dynamic d) {
    if (d == null) return 'No deadline';
    try {
      final date = DateTime.parse(d.toString());
      final diff = date.difference(DateTime.now()).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff < 0) return 'Overdue';
      return '$diff days left';
    } catch (_) {
      return 'No deadline';
    }
  }

  Future<void> _deleteTask(String id) async {
    try {
      await _tasksService.deleteTask(id);
      await _loadTasks(); // _loadTasks manages its own loading state
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete error: $e')));
      }
    }
  }

  Future<void> _updateTaskStatus(String id, String s) async {
    try {
      await _tasksService.updateTask(id, status: s);
      await _loadTasks(); // _loadTasks manages its own loading state
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update error: $e')));
      }
    }
  }

  Future<void> _updateTaskProgress(String id, int p) async {
    try {
      await _tasksService.updateTask(id, progress: p);
      await _loadTasks(); // _loadTasks manages its own loading state
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Progress updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Progress error: $e')));
      }
    }
  }

  void _showTaskOptions(dynamic task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((task['status'] ?? '')
                    .toString()
                    .toLowerCase() !=
                'in progress')
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Mark as In Progress'),
                onTap: () {
                  Navigator.pop(c);
                  _updateTaskStatus(task['id'], 'In Progress');
                },
              ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as Done'),
              onTap: () {
                Navigator.pop(c);
                _updateTaskStatus(task['id'], 'Done');
              },
            ),
            if (() {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return false;
              return task['assignedTo'] == uid || task['assignedBy'] == uid;
            }())
              ListTile(
                leading: const Icon(Icons.linear_scale_outlined),
                title: const Text('Update Progress'),
                onTap: () async {
                  Navigator.pop(c);
                  int temp = (task['progress'] is int)
                      ? task['progress']
                      : int.tryParse((task['progress'] ?? 0).toString()) ?? 0;
                  final res = await showDialog<int>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setSB) => AlertDialog(
                        title: const Text('Update Progress',
                            style: TextStyle(fontFamily: 'Outfit')),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: temp.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '$temp%',
                              onChanged: (v) => setSB(() => temp = v.round()),
                            ),
                            Text('$temp%',
                                style: const TextStyle(fontFamily: 'Outfit')),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, temp),
                              child: const Text('Save')),
                        ],
                      ),
                    ),
                  );
                  if (res != null) _updateTaskProgress(task['id'], res);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.pop(c);
                _showEditTaskDialog(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Task',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(c);
                _deleteTask(task['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(dynamic task) async {
    final titleC = TextEditingController(text: task['title'] ?? '');
    final descC = TextEditingController(text: task['description'] ?? '');
    DateTime? due;
    try {
      if (task['dueDate'] != null) due = DateTime.tryParse(task['dueDate']);
    } catch (_) {}
    TimeOfDay? dueTime = due != null
        ? TimeOfDay(hour: due.hour, minute: due.minute)
        : null;
    List<dynamic> members = [];
    String? assignee = task['assignedTo'];
    String? assigneeName = task['assignedToName'];
    try {
      final gid = task['groupId'];
      if (gid != null) members = await _groupsService.getGroupMembers(gid);
    } catch (e) {
      print('Members load fail: $e');
    }
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) => AlertDialog(
          title: const Text('Edit Task', style: TextStyle(fontFamily: 'Outfit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                  controller: descC,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    due != null && dueTime != null
                        ? '${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')} ${dueTime!.format(context)}'
                        : 'Set due date',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: due ?? DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2026));
                    if (picked != null) {
                      final t = await showTimePicker(
                          context: context,
                          initialTime: dueTime ?? TimeOfDay.now());
                      if (t != null) setSB(() { due = picked; dueTime = t; });
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(assigneeName != null
                      ? 'Assigned to: $assigneeName'
                      : 'Assign member'),
                  onTap: () async {
                    final picked = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (c2) => AlertDialog(
                        title: const Text('Select Member',
                            style: TextStyle(fontFamily: 'Outfit')),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: members.isEmpty
                              ? const Text('No members')
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: members.length,
                                  itemBuilder: (iC, idx) {
                                    final m = members[idx];
                                    final name = (m['fullName'] ?? m['name'] ?? m['email'] ?? m['uid'] ?? m['userId'] ?? '')
                                      .toString();
                                    return ListTile(
                                      title: Text(name),
                                      subtitle: m['email'] != null
                                          ? Text(m['email'])
                                          : null,
                                      onTap: () => Navigator.pop(
                                          c2,
                                          {
                                        'id': (m['uid'] ?? m['userId'] ?? m['id'] ?? '')
                                                .toString(),
                                            'name': name
                                          }),
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c2),
                              child: const Text('Cancel')),
                          if (assignee != null)
                            TextButton(
                                onPressed: () => Navigator.pop(
                                    c2, {'id': '', 'name': ''}),
                                child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (picked != null) {
                      setSB(() {
                        assignee = picked['id']!.isEmpty ? null : picked['id'];
                        assigneeName =
                            picked['name']!.isEmpty ? null : picked['name'];
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                String? dueIso;
                if (due != null && dueTime != null) {
                  dueIso = DateTime(due!.year, due!.month, due!.day,
                          dueTime!.hour, dueTime!.minute)
                      .toIso8601String();
                }
                await _tasksService.updateTask(
                  task['id'],
                  title: titleC.text.trim().isEmpty
                      ? null
                      : titleC.text.trim(),
                  description: descC.text.trim(),
                  assignedTo: assignee,
                  dueDate: dueIso,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                await _loadTasks(); // _loadTasks manages its own loading state
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tasks',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: _showNotifications),
                          if (_unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(_unreadCount.toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Outfit')),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: ShapeDecoration(
                              color: const Color(0xFFe2E8F0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50))),
                          child: const Center(
                              child: Icon(Icons.person,
                                  color: Color(0xFF64748B))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 27),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      _selectedTaskFilter == 'All'
                          ? 'All Tasks'
                          : '$_selectedTaskFilter Tasks',
                      style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 16,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400)),
                  Container(
                    width: 45,
                    height: 45,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFF0FDF4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFF22C55E)),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NewTaskScreen()),
                        );
                        _loadTasks();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(8),
              decoration: ShapeDecoration(
                color: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Row(
                children: _taskFilters.map((f) {
                  final sel = _selectedTaskFilter == f;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedTaskFilter = f;
                        _filterTasks();
                      }),
                      child: Container(
                        height: 37,
                        decoration: ShapeDecoration(
                          color: sel ? Colors.white : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            f,
                            style: TextStyle(
                              color: sel ? Colors.black : Colors.white,
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight:
                                  sel ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadTasks,
                      child: _filteredTasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.task_outlined,
                                      size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text('No tasks in "$_selectedTaskFilter"',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w400))
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              itemCount: _filteredTasks.length,
                              itemBuilder: (c, i) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: _buildTaskCard(_filteredTasks[i]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(30),
        height: 47,
        decoration: ShapeDecoration(
          color: const Color(0xFF3B82F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomNavItem(Icons.home, 0),
            _buildBottomNavItem(Icons.task_alt, 1),
            _buildBottomNavItem(Icons.folder, 2),
            _buildBottomNavItem(Icons.person, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task['title'] ?? 'Untitled Task',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: Color(0xFF64748B)),
                    onPressed: () => _showTaskOptions(task),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task['description'] ?? 'No description',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        () {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          final at = task['assignedTo'];
                          final an = task['assignedToName'];
                          if (at == null || at.toString().isEmpty) {
                            return 'Unassigned';
                          }
                          if (uid != null && at == uid) {
                            return 'Assigned to you';
                          }
                          if (an != null && an.toString().isNotEmpty) {
                            return 'Assigned to: ${an.toString()}';
                          }
                          return 'Assigned to member';
                        }(),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        'Due: ${_formatDueDate(task['dueDate'])}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: ShapeDecoration(
                    color: _getStatusColor(task['status']),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    task['status'],
                    style: TextStyle(
                      color: _getStatusTextColor(task['status']),
                      fontSize: 10,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            if (task['progress'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: (() {
                        final p = task['progress'];
                        final v = (p is num)
                            ? p.toDouble()
                            : double.tryParse(p.toString()) ?? 0.0;
                        return (v.clamp(0.0, 100.0)) / 100.0;
                      })(),
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(() {
                        final p = task['progress'];
                        final v = (p is num)
                            ? p.toInt()
                            : int.tryParse(p.toString()) ?? 0;
                        return v;
                      })()}%',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    final sel = _selectedBottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedBottomNavIndex = index);
        switch (index) {
          case 0:
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            break;
          case 1:
            break;
          case 2:
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const FilesScreen()));
            break;
          case 3:
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()));
            break;
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          if (sel)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 3,
              height: 3,
              decoration: const ShapeDecoration(
                color: Colors.white,
                shape: OvalBorder(),
              ),
            ),
        ],
      ),
    );
  }
}