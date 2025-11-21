import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dashboard.dart';
import 'file_screen.dart';
import 'profilescreen.dart';
import 'services/tasks_service.dart';
import 'services/groups_service.dart';
import 'services/notifications_service.dart';

class NewTaskScreen extends StatefulWidget {
  const NewTaskScreen({super.key});

  @override
  State<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends State<NewTaskScreen> {
  int _selectedBottomNavIndex = 1;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tasksService = TasksService();
  final _groupsService = GroupsService();
  final NotificationsService _notificationsService = NotificationsService();

  bool _isLoading = false;
  String? _selectedGroupId;
  List<dynamic> _groups = [];
  List<dynamic> _members = [];
  String? _selectedAssigneeId;
  String? _selectedAssigneeName;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  List<dynamic> _notifications = [];
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _loadNotifications();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _groupsService.getMyGroups();
      setState(() => _groups = groups);
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  Future<void> _loadMembers(String groupId) async {
    try {
      final members = await _groupsService.getGroupMembers(groupId);
      setState(() {
        _members = members;
        _selectedAssigneeId = null;
        _selectedAssigneeName = null;
      });
    } catch (e) {
      print('Error loading members: $e');
      setState(() {
        _members = [];
        _selectedAssigneeId = null;
        _selectedAssigneeName = null;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2025, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
            ),
            child: child!,
          );
        },
      );

      if (timePicked != null) {
        setState(() {
          _selectedDueDate = picked;
          _selectedDueTime = timePicked;
        });
      }
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a group'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? dueDateString;
      if (_selectedDueDate != null && _selectedDueTime != null) {
        final dueDateTime = DateTime(
          _selectedDueDate!.year,
          _selectedDueDate!.month,
          _selectedDueDate!.day,
          _selectedDueTime!.hour,
          _selectedDueTime!.minute,
        );
        dueDateString = dueDateTime.toIso8601String();
      }

      await _tasksService.createTask(
        title: _titleController.text.trim(),
        groupId: _selectedGroupId!,
        description: _descriptionController.text.trim(),
        dueDate: dueDateString,
        assignedTo: _selectedAssigneeId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final list = await _notificationsService.getMyNotifications();
      int unread = 0; for (final n in list) { if (n['read'] != true) unread++; }
      if(mounted) setState(() { _notifications = list; _unread = unread; });
    } catch (e) { print('NewTask notifications error: $e'); }
  }

  void _showNotifications() async {
    await _loadNotifications();
    if(!mounted) return;
    showDialog(context: context, builder: (c)=> AlertDialog(
      title: const Text('Notifications', style: TextStyle(fontFamily:'Outfit')),
      content: SizedBox(width: double.maxFinite, child: _notifications.isEmpty? const Text('No notifications') : ListView.builder(
        shrinkWrap: true,
        itemCount: _notifications.length,
        itemBuilder: (ctx,i){ final n=_notifications[i]; return ListTile(
          title: Text(n['message']??'', style: const TextStyle(fontFamily:'Outfit')),
          subtitle: Text((n['type']??'').toString(), style: const TextStyle(fontFamily:'Outfit')),
          trailing: n['read']==true? const Icon(Icons.check,color:Colors.green,size:18) : TextButton(onPressed: () async { await _notificationsService.markRead(n['id']); Navigator.pop(context); _loadNotifications(); }, child: const Text('Mark read')),
        ); },
      )),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  String _formatDueDate() {
    if (_selectedDueDate == null || _selectedDueTime == null) {
      return 'Set due date';
    }
    final date = _selectedDueDate!;
    final time = _selectedDueTime!;
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final timeStr = time.format(context);
    return '$dateStr at $timeStr';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Task',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Stack(children:[
                        IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: _showNotifications),
                        if(_unread>0) Positioned(right:6,top:6, child: Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(_unread.toString(), style: const TextStyle(color: Colors.white, fontSize:10, fontFamily:'Outfit')))),
                      ]),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFE2E8F0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Title Field
                    Container(
                      width: double.infinity,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: TextField(
                        controller: _titleController,
                        maxLines: null,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Task Title',
                          hintStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    // Description Field
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: null,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontFamily: 'Outfit',
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Description (optional)',
                          hintStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontFamily: 'Outfit',
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    // Group Selection
                    GestureDetector(
                      onTap: () async {
                        final selected = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Select Group', style: TextStyle(fontFamily: 'Outfit')),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: _groups.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text('No groups available. Create a group first!'),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _groups.length,
                                      itemBuilder: (context, index) {
                                        final group = _groups[index];
                                        return ListTile(
                                          title: Text(group['name'], style: const TextStyle(fontFamily: 'Outfit')),
                                          subtitle: Text(group['subject'], style: const TextStyle(fontFamily: 'Outfit')),
                                          onTap: () => Navigator.pop(context, group['id']),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        );
                        if (selected != null) {
                          setState(() => _selectedGroupId = selected);
                          await _loadMembers(selected);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              const Icon(Icons.group_outlined, color: Color(0xFF64748B), size: 24),
                              const SizedBox(width: 14),
                              Text(
                                _selectedGroupId != null
                                    ? _groups.firstWhere((g) => g['id'] == _selectedGroupId)['name']
                                    : 'Select Group',
                                style: TextStyle(
                                  color: _selectedGroupId != null
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    // Assign To (optional)
                    GestureDetector(
                      onTap: () async {
                        if (_selectedGroupId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a group first')),
                          );
                          return;
                        }
                        final selected = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Assign to member', style: TextStyle(fontFamily: 'Outfit')),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: _members.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text('No members found'),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _members.length,
                                      itemBuilder: (context, index) {
                                        final m = _members[index];
                                        // Backend returns members with keys: uid, fullName, email
                                        final name = (m['fullName'] ?? m['name'] ?? m['email'] ?? m['uid'] ?? '').toString();
                                        return ListTile(
                                          leading: const Icon(Icons.person_outline),
                                          title: Text(name, style: const TextStyle(fontFamily: 'Outfit')),
                                          subtitle: (m['email'] != null && (m['email'] as String).isNotEmpty) ? Text(m['email'], style: const TextStyle(fontFamily: 'Outfit')) : null,
                                          onTap: () => Navigator.pop(context, {
                                            // Use 'uid' from backend as the member id
                                            'id': (m['uid'] ?? m['userId'] ?? m['id'] ?? '').toString(),
                                            'name': name,
                                          }),
                                        );
                                      },
                                    ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              if (_selectedAssigneeId != null)
                                TextButton(
                                  onPressed: () => Navigator.pop(context, {'id': '', 'name': ''}),
                                  child: const Text('Clear'),
                                ),
                            ],
                          ),
                        );
                        if (selected != null) {
                          setState(() {
                            _selectedAssigneeId = selected['id']!.isEmpty ? null : selected['id'];
                            _selectedAssigneeName = selected['name']!.isEmpty ? null : selected['name'];
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF64748B), size: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _selectedAssigneeName != null
                                      ? 'Assigned to: $_selectedAssigneeName'
                                      : 'Assign to (optional)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _selectedAssigneeName != null
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                    fontSize: 16,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    // Due Date Field
                    GestureDetector(
                      onTap: _selectDueDate,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B), size: 24),
                              const SizedBox(width: 14),
                              Text(
                                _formatDueDate(),
                                style: TextStyle(
                                  color: _selectedDueDate != null
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 37,
                              decoration: ShapeDecoration(
                                color: const Color(0xFFE2E8F0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 17),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoading ? null : _saveTask,
                            child: Container(
                              height: 37,
                              decoration: ShapeDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Save',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
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

  Widget _buildBottomNavItem(IconData icon, int index) {
    final isSelected = _selectedBottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedBottomNavIndex = index);
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
            break;
          case 1:
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FilesScreen()),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          if (isSelected)
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