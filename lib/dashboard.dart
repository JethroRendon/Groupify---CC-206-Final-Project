import 'package:flutter/material.dart';
import 'new_task_screen.dart';
import 'task_screen.dart';
import 'file_screen.dart';
import 'profilescreen.dart';
import 'activity_screen.dart';
import 'services/notifications_service.dart';
import 'groups_screen.dart';
import 'services/dashboard_service.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedBottomNavIndex = 0;
  final _notificationsService = NotificationsService();

  bool _isLoading = false; // start false so initial _loadOverview executes
  String _userName = 'User';
  String? _userProfilePicture;
  int _totalTasks = 0;
  int _pendingTasks = 0;
  int _completedTasks = 0;
  List<dynamic> _activities = [];
  final DashboardService _dashboardService = DashboardService();
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (_isLoading) return; // prevent overlaps after first
    final start = DateTime.now();
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await _dashboardService.getOverview();
      final user = (data['user'] as Map?) ?? {};
      final stats = (data['stats'] as Map?) ?? {};
      final notif = (data['notifications'] as List?) ?? [];
      final acts = (data['activities'] as List?) ?? [];
      final userName = (user['fullName'] ?? 'User').toString();
      final firstName = userName.split(' ').first;
      final profilePic = user['profilePicture']?.toString();
      int unread = 0; for (final n in notif) { if (n is Map && n['read'] != true) unread++; }
      if (mounted) {
        setState(() {
          _userName = firstName;
          _userProfilePicture = profilePic;
          _totalTasks = (stats['totalTasks'] ?? 0) as int;
          _pendingTasks = (stats['pendingTasks'] ?? 0) as int;
          _completedTasks = (stats['completedTasks'] ?? 0) as int;
          _activities = acts;
          _notifications = notif;
          _unreadCount = unread;
          _isLoading = false;
        });
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      // Debug timing
      // ignore: avoid_print
      print('[Dashboard] Overview loaded in ${elapsed}ms (silent: $silent)');
    } catch (e) {
      print('Overview load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Legacy loaders removed (dashboard now uses a single overview endpoint).

  void _showNotifications() async {
    if(!mounted) return;
    showDialog(context: context, builder: (c)=> AlertDialog(
      title: const Text('Notifications', style: TextStyle(fontFamily:'Outfit')),
      content: SizedBox(width: double.maxFinite, child: _notifications.isEmpty? const Text('No notifications') : ListView.builder(
        shrinkWrap: true,
        itemCount: _notifications.length,
        itemBuilder: (ctx,i){ final n=_notifications[i]; return ListTile(
          title: Text(n['message']??'', style: const TextStyle(fontFamily:'Outfit')),
          subtitle: Text((n['type']??'').toString(), style: const TextStyle(fontFamily:'Outfit')),
          trailing: n['read']==true? const Icon(Icons.check,color:Colors.green,size:18) : TextButton(onPressed: () async { 
            Navigator.pop(context);
            await _notificationsService.markRead(n['id']); 
            _loadOverview(silent: true); // Reload silently in background
          }, child: const Text('Mark read')),
        ); },
      )),
      actions: [
        if (_notifications.isNotEmpty) 
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Clearing notifications...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
              try {
                await _notificationsService.clearAll();
                _loadOverview(silent: true); // Reload silently in background
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications cleared'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
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
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Close')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadOverview,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(21),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 20,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                Text(
                                  '$_userName!',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 20,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Stack(children:[
                                  IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: _showNotifications),
                                  if(_unreadCount>0) Positioned(right:6, top:6, child: Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(_unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize:10, fontFamily:'Outfit')))),
                                ]),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ProfileScreen(),
                                      ),
                                    );
                                  },
                                  child: ClipOval(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      color: const Color(0xFF3B82F6),
                                      child: _userProfilePicture != null && _userProfilePicture!.isNotEmpty
                                          ? Image.network(
                                              _userProfilePicture!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Center(
                                                  child: Text(
                                                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                      fontFamily: 'Outfit',
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                );
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Center(
                                              child: Text(
                                                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                  fontFamily: 'Outfit',
                                                  fontWeight: FontWeight.w600,
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

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 19),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            );
                          },
                          child: Container(
                            height: 59,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(width: 1, color: Color(0xFFD1D5DB)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                                ),
                                Text(
                                  'Search tasks, files, etc.',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 16,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 21),

                      // Create New Task Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 19),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const NewTaskScreen(),
                                ),
                              );
                              // Silently refresh dashboard when returning
                              _loadOverview(silent: true);
                            },
                            icon: const Icon(Icons.add, size: 24),
                            label: const Text(
                              'Create new task',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      // Add Groups Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 19),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GroupsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.group),
                            label: const Text(
                              'My Groups',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3B82F6),
                              side: const BorderSide(color: Color(0xFF3B82F6)),
                              padding: const EdgeInsets.all(10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 21),

                      // Task Overview Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 21),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Task Overview',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const TasksScreen()),
                                );
                              },
                              child: const Text(
                                'See All',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 14,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Large Stats Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen(initialFilter: 'All')));
                          },
                          child: Container(
                            height: 200,
                            width: MediaQuery.of(context).size.width,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total tasks',
                                        style: TextStyle(
                                          color: Color(0xFFDAEAFE),
                                          fontSize: 12,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '$_totalTasks',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 64,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$_completedTasks completed',
                                        style: const TextStyle(
                                          color: Color(0xFFDAEAFE),
                                          fontSize: 12,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Image on the right - larger and positioned
                                Positioned(
                                  right: 0,
                                  bottom: -35,
                                  child: Image.asset(
                                    'assets/images/numberoftaskimage.png',
                                    width: 250,
                                    height: 250,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox(width: 250, height: 250);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Small Stats Cards Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen(initialFilter: 'To Do')));
                                },
                                child: _buildSmallStatsCard(
                                  title: 'Pending tasks',
                                  number: '$_pendingTasks',
                                  imagePath: 'assets/images/unfinishedtask.png',
                                ),
                              ),
                            ),
                            const SizedBox(width: 31),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen(initialFilter: 'Done')));
                                },
                                child: _buildSmallStatsCard(
                                  title: 'Completed',
                                  number: '$_completedTasks',
                                  imagePath: 'assets/images/teamtask.png',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 37),

                      // Recent Activity Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Activity',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
                              },
                              child: const Text(
                                'See All',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 14,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 21),

                      // Activity Preview (first 6 activities)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            if (_activities.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No activity yet',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._activities.take(6).map((a) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: InkWell(
                                          onTap: () => _navigateActivity(a),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      (a['details'] ?? a['action'] ?? '').toString(),
                                                      style: const TextStyle(
                                                        color: Color(0xFF0F172A),
                                                        fontSize: 14,
                                                        fontFamily: 'Outfit',
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _activitySubtitle(a),
                                                      style: const TextStyle(
                                                        color: Color(0xFF64748B),
                                                        fontSize: 12,
                                                        fontFamily: 'Outfit',
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _activityChip(a['action']?.toString() ?? ''),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )),
                            if (_activities.length > 6)
                              TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
                                },
                                child: const Text('View All Activity'),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Widget _buildSmallStatsCard({
    required String title,
    required String number,
    String? imagePath,
  }) {
    return Container(
      height: 130,
      decoration: ShapeDecoration(
        color: const Color(0xFF3B82F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (imagePath != null)
            Positioned(
              right: 0,
              bottom: -10,
              child: Image.asset(
                imagePath,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 80, height: 80);
                },
              ),
            ),
        ],
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
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TasksScreen()),
            );
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FilesScreen()),
            );
            break;
          case 3:
            Navigator.push(
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

  String _activitySubtitle(Map a) {
    final actor = (a['actorName'] ?? 'Someone').toString();
    final when = _formatActivityTime(a['timestamp']);
    // include assignee if present
    final assignee = (a['assigneeName'] ?? '').toString();
    if (assignee.isNotEmpty) {
      return '$actor → $assignee • $when';
    }
    return '$actor • $when';
  }

  String _formatActivityTime(dynamic ts) {
    final ms = _tsMillis(ts);
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  int _tsMillis(dynamic ts){
    if (ts == null) return 0;
    try {
      final s = ts['_seconds'] ?? ts['seconds'];
      final ns = ts['_nanoseconds'] ?? ts['nanoseconds'] ?? 0;
      if (s is int) return s * 1000 + (ns is int ? (ns / 1000000).round() : 0);
    } catch(_){ }
    return 0;
  }

  Widget _activityChip(String action) {
    Color bg; Color fg = const Color(0xFF0F172A);
    switch(action){
      case 'file_uploaded': bg = const Color(0xFFDBEAFE); break;
      case 'task_created': bg = const Color(0xFFFEF3C7); break;
      case 'task_assigned': bg = const Color(0xFFE0FEDB); break;
      case 'task_unassigned': bg = const Color(0xFFF1F5F9); break;
      case 'task_progress': bg = const Color(0xFFFAE8FF); break;
      case 'task_completed': bg = const Color(0xFFE0FEDB); break;
      default: bg = const Color(0xFFE2E8F0); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(action.replaceAll('_',' '), style: TextStyle(color: fg, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w500))
    );
  }

  void _navigateActivity(Map a) {
    final action = (a['action'] ?? '').toString();
    if (action.startsWith('file_')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FilesScreen()));
    } else if (action.startsWith('task_')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
    } else if (action.startsWith('group_')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen()));
    }
  }
}