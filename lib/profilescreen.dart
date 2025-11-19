import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_screen.dart';
import 'file_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'onboarding.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedBottomNavIndex = 3;
  final _authService = AuthService();
  final _userService = UserService();

  bool _isLoading = true;
  Map<String, String> _user = {
    'name': 'Loading...',
    'email': '',
    'section': '',
    'school': '',
    'course': '',
    'yearLevel': '',
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
  setState(() => _isLoading = true);
  
  try {
    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _user = {
          'name': 'Guest',
          'email': 'Not logged in',
          'section': '',
          'school': '',
          'course': '',
          'yearLevel': '',
        };
        _isLoading = false;
      });
      return;
    }

    final response = await _userService.getUserProfile();
    final userData = response['user'];

    setState(() {
      _user = {
        'name': userData['fullName'] ?? 'User',
        'email': userData['email'] ?? '',
        'section': userData['section'] ?? '',
        'school': userData['school'] ?? '',
        'course': userData['course'] ?? '',
        'yearLevel': userData['yearLevel'] ?? '',
      };
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading profile: $e');
    setState(() {
      _user = {
        'name': 'Guest',
        'email': 'Not logged in',
        'section': '',
        'school': '',
        'course': '',
        'yearLevel': '',
      };
      _isLoading = false;
    });
  }
}

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out', style: TextStyle(fontFamily: 'Outfit')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  void _handleMenuPress(String action) {
    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit profile coming soon!')),
        );
        break;
      case 'notifications':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications coming soon!')),
        );
        break;
      case 'privacy':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings coming soon!')),
        );
        break;
      case 'settings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings coming soon!')),
        );
        break;
      case 'help':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help coming soon!')),
        );
        break;
      case 'signout':
        _handleSignOut();
        break;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUserProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                onTap: () => _handleMenuPress('edit'),
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
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _user['name']![0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 32,
                                          color: Colors.white,
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
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
                                          '${_user['course']} ${_user['yearLevel']}',
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
                                  _buildDetailItem(Icons.school_outlined, _user['school']!),
                                  const SizedBox(height: 16),
                                  _buildDetailItem(Icons.class_outlined, 'Section ${_user['section']}'),
                                ],
                              ),
                            ],
                          ),
                        ),

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
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(30),
        height: 47,
        decoration: ShapeDecoration(
          color: const Color(0xFF3B82F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
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
        setState(() => _selectedBottomNavIndex = index);
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
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