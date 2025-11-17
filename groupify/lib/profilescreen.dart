import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'task_screen.dart';
import 'file_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedBottomNavIndex = 3; // Profile tab is selected

  final Map<String, String> _user = {
    'name': 'Jethro Rendon',
    'email': 'jethro.rendon@wvsu.edu.ph',
    'phone': '+63 912 345 6789',
    'location': 'Anini-y, Antique',
    'joinDate': 'January 2023',
    'section': 'BSCS 3B',
  };

  List<Map<String, dynamic>> _userGroupings = [
    {
      'id': '1',
      'name': 'BSCS 3A',
      'members': '32',
      'color': Color(0xFF84CC16),
    },
    {
      'id': '2',
      'name': 'Capstone Team',
      'members': '5',
      'color': Color(0xFF3B82F6),
    },
    {
      'id': '3',
      'name': 'Study Group',
      'members': '8',
      'color': Color(0xFFF59E0B),
    },
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Edit Profile',
      'icon': Icons.edit_outlined,
      'action': 'edit',
      'danger': false,
    },
    {
      'title': 'Notifications',
      'icon': Icons.notifications_outlined,
      'action': 'notifications',
      'danger': false,
    },
    {
      'title': 'Privacy & Security',
      'icon': Icons.shield_outlined,
      'action': 'privacy',
      'danger': false,
    },
    {
      'title': 'Settings',
      'icon': Icons.settings_outlined,
      'action': 'settings',
      'danger': false,
    },
    {
      'title': 'Help & Support',
      'icon': Icons.help_outline,
      'action': 'help',
      'danger': false,
    },
    {
      'title': 'Sign Out',
      'icon': Icons.logout,
      'action': 'signout',
      'danger': true,
    },
  ];

  void _showAddGroupingDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController membersController = TextEditingController();
    Color selectedColor = const Color(0xFF3B82F6);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Add New Grouping',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Grouping Name',
                    hintText: 'e.g., BSCS 3A',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: membersController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Members',
                    hintText: 'e.g., 32',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Color',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    const Color(0xFF84CC16),
                    const Color(0xFF3B82F6),
                    const Color(0xFFF59E0B),
                    const Color(0xFFEF4444),
                    const Color(0xFF8B5CF6),
                    const Color(0xFFEC4899),
                  ].map((color) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Outfit'),
              ),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    membersController.text.isNotEmpty) {
                  setState(() {
                    _userGroupings.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'name': nameController.text,
                      'members': membersController.text,
                      'color': selectedColor,
                    });
                  });
                  Navigator.pop(context);
                  _showMessage('Grouping added successfully');
                } else {
                  _showMessage('Please fill in all fields');
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(fontFamily: 'Outfit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupingDialog(Map<String, dynamic> grouping, int index) {
    final TextEditingController nameController =
        TextEditingController(text: grouping['name']);
    final TextEditingController membersController =
        TextEditingController(text: grouping['members']);
    Color selectedColor = grouping['color'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Edit Grouping',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Grouping Name',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: membersController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Members',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Color',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    const Color(0xFF84CC16),
                    const Color(0xFF3B82F6),
                    const Color(0xFFF59E0B),
                    const Color(0xFFEF4444),
                    const Color(0xFF8B5CF6),
                    const Color(0xFFEC4899),
                  ].map((color) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Outfit'),
              ),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    membersController.text.isNotEmpty) {
                  setState(() {
                    _userGroupings[index] = {
                      'id': grouping['id'],
                      'name': nameController.text,
                      'members': membersController.text,
                      'color': selectedColor,
                    };
                  });
                  Navigator.pop(context);
                  _showMessage('Grouping updated successfully');
                } else {
                  _showMessage('Please fill in all fields');
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(fontFamily: 'Outfit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGrouping(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Grouping',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to delete this grouping?',
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userGroupings.removeAt(index);
              });
              Navigator.pop(context);
              _showMessage('Grouping deleted successfully');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Choose what to edit',
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('Camera/Gallery would open here');
            },
            child: const Text(
              'Change Photo',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('Profile edit form would open here');
            },
            child: const Text(
              'Edit Info',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuPress(String action) {
    switch (action) {
      case 'edit':
        _handleEditProfile();
        break;
      case 'notifications':
        _showMessage('Notification settings would open here');
        break;
      case 'privacy':
        _showMessage('Privacy settings would open here');
        break;
      case 'settings':
        _showMessage('App settings would open here');
        break;
      case 'help':
        _showMessage('Help center would open here');
        break;
      case 'signout':
        _showSignOutDialog();
        break;
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Sign Out',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('You have been signed out');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: _handleEditProfile,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDBEAFE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      // Profile Header
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE2E8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      fontSize: 32,
                                      color: Color(0xFF475569),
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _showMessage('Camera/Gallery would open here'),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user['name']!,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _user['section']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF64748B),
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Profile Details
                      Column(
                        children: [
                          _buildDetailItem(Icons.email_outlined, _user['email']!),
                          const SizedBox(height: 16),
                          _buildDetailItem(Icons.phone_outlined, _user['phone']!),
                          const SizedBox(height: 16),
                          _buildDetailItem(Icons.location_on_outlined, _user['location']!),
                          const SizedBox(height: 16),
                          _buildDetailItem(Icons.calendar_today_outlined, 'Joined ${_user['joinDate']}'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Groupings Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Groupings',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showAddGroupingDialog,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _userGroupings.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No groupings yet. Tap + to add one!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: _userGroupings.asMap().entries.map((entry) {
                          final index = entry.key;
                          final grouping = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildGroupingCard(
                              grouping: grouping,
                              index: index,
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 32),

                // Account Menu Section
                const Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: _menuItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Column(
                        children: [
                          _buildMenuItem(
                            icon: item['icon'],
                            title: item['title'],
                            action: item['action'],
                            danger: item['danger'],
                          ),
                          if (index < _menuItems.length - 1)
                            const Divider(
                              height: 1,
                              color: Color(0xFFE2E8F0),
                            ),
                        ],
                      );
                    }).toList(),
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

  Widget _buildGroupingCard({
    required Map<String, dynamic> grouping,
    required int index,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (grouping['color'] as Color).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group,
              size: 24,
              color: grouping['color'],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grouping['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${grouping['members']} members',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showEditGroupingDialog(grouping, index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteGrouping(index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String action,
    required bool danger,
  }) {
    return GestureDetector(
      onTap: () => _handleMenuPress(action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger ? const Color(0xFFFEF2F2) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: danger ? const Color(0xFFEF4444) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: danger ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                ),
              ),
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