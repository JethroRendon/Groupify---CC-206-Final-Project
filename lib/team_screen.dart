import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'task_screen.dart';
import 'file_screen.dart';
import 'profilescreen.dart';
import 'services/notifications_service.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  int _selectedBottomNavIndex = 2; // Team tab is selected

  final Map<String, dynamic> _teamOverview = {
    'members': 6,
    'online': 4,
    'activeTasks': 18,
  };

  final List<Map<String, dynamic>> _teamMembers = [
    {
      'name': 'Michelle Juanico',
      'status': 'Active now',
      'isOnline': true,
      'currentTasks': ['UI design review', 'Database migration'],
      'profileImage': 'assets/images/profile_placeholder.png',
    },
    {
      'name': 'Allyn Ledesma',
      'status': 'Active now',
      'isOnline': true,
      'currentTasks': ['API testing', 'Code review'],
      'profileImage': 'assets/images/profile_placeholder.png',
    },
    {
      'name': 'Joeross Palabrica',
      'status': 'Last seen 2h ago',
      'isOnline': false,
      'currentTasks': ['Documentation', 'Bug fixes'],
      'profileImage': 'assets/images/profile_placeholder.png',
    },
    {
      'name': 'Lean Cabales',
      'status': 'Active now',
      'isOnline': true,
      'currentTasks': ['Backend setup', 'Testing'],
      'profileImage': 'assets/images/profile_placeholder.png',
    },
  ];

  final NotificationsService _notificationsService = NotificationsService();
  List<dynamic> _notifications = [];
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final list = await _notificationsService.getMyNotifications();
      int unread = 0; for(final n in list){ if(n['read'] != true) unread++; }
      if(mounted) setState(() { _notifications = list; _unread = unread; });
    } catch(e){ print('Team notifications error: $e'); }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Team',
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
                          if(_unread>0) Positioned(right:6, top:6, child: Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(_unread.toString(), style: const TextStyle(color: Colors.white, fontSize:10, fontFamily:'Outfit')))),
                        ]),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_)=> const ProfileScreen())); },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: ShapeDecoration(
                              color: const Color(0xFFE2E8F0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: const Center(child: Icon(Icons.person, color: Color(0xFF64748B))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Team Overview Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  height: 148,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(21),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Team Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildOverviewStat(
                              value: _teamOverview['members'].toString(),
                              label: 'Members',
                            ),
                            const SizedBox(width: 60),
                            _buildOverviewStat(
                              value: _teamOverview['online'].toString(),
                              label: 'Online',
                            ),
                            const SizedBox(width: 60),
                            _buildOverviewStat(
                              value: _teamOverview['activeTasks'].toString(),
                              label: 'Active Tasks',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Team Members Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Team Members',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFF0FDF4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFF22C55E),
                          size: 16,
                        ),
                        onPressed: () {
                          // Add new team member
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 19),

              // Team Members List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _teamMembers.length,
                itemBuilder: (context, index) {
                  final member = _teamMembers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 19),
                    child: _buildTeamMemberCard(
                      name: member['name'],
                      status: member['status'],
                      isOnline: member['isOnline'],
                      currentTasks: List<String>.from(member['currentTasks']),
                      profileImage: member['profileImage'],
                    ),
                  );
                },
              ),

              const SizedBox(height: 80),
            ],
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

  Widget _buildOverviewStat({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 24,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.80),
            fontSize: 14,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMemberCard({
    required String name,
    required String status,
    required bool isOnline,
    required List<String> currentTasks,
    required String profileImage,
  }) {
    return Container(
      height: 187,
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.asset(
                          profileImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isOnline)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            status,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () {
                    // Show options menu
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Current Tasks (${currentTasks.length})',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentTasks.map((task) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    task,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    final isSelected = _selectedBottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomNavIndex = index;
        });

        // Handle navigation based on index
      switch (index) {
        case 0:
          // Navigate to Homescreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
          break;

        case 1:
          //Navigate to TasksScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TasksScreen()),
          );
          break;

        case 2:
          //Navigate to TeamsScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => FilesScreen()),
          );
          break;

        case 3:
          // Already on TeamScreen
          break;
      }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          if(isSelected)
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