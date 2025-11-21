import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_screen.dart';
import 'file_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/notifications_service.dart';
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
  final NotificationsService _notificationsService = NotificationsService();
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<User?>? _authSub;
  bool _repairAttempted = false;
  bool _isLoading = false; // start false so initial load executes
  Map<String, String> _user = {
    'name': 'Loading...',
    'email': '',
    'section': '',
    'school': '',
    'course': '',
    'yearLevel': '',
    'profilePicture': '',
  };
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _loadUserProfile();
    });
    _loadUserProfile();
    _loadNotifications();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
  if (_isLoading) return; // prevent overlapping loads
  final start = DateTime.now();
  setState(() => _isLoading = true);
  
  try {
    // Wait for Firebase Auth to emit the current state (ensures web persistence is restored)
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // Load local sign-up values as a fallback (saved during signUp)
    final prefs = await SharedPreferences.getInstance();
    final prefFullName = prefs.getString('profile_fullName') ?? '';
    final prefEmail = prefs.getString('profile_email') ?? '';
    final prefSchool = prefs.getString('profile_school') ?? '';
    final prefCourse = prefs.getString('profile_course') ?? '';
    final prefYearLevel = prefs.getString('profile_yearLevel') ?? '';
    final prefSection = prefs.getString('profile_section') ?? '';

    // If user is not signed in, show Guest
    if (user == null) {
      setState(() {
        _user = {
          'name': 'Guest',
          'email': 'Not logged in',
          'school': '',
          'course': '',
          'yearLevel': '',
          'section': '',
        };
        _isLoading = false;
      });
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      // ignore: avoid_print
      print('[ProfileScreen] Guest state in ${elapsed}ms');
      return;
    }

    // Start with values from FirebaseAuth and SharedPreferences so UI updates even if backend call fails
    final authDisplayName = user.displayName;
    final authEmail = user.email ?? '';
    String displayName = prefFullName.isNotEmpty ? prefFullName : (authDisplayName ?? 'User');
    String effectiveEmail = prefEmail.isNotEmpty ? prefEmail : authEmail;
    String schoolVal = prefSchool;
    String courseVal = prefCourse;
    String yearVal = prefYearLevel;
    String sectionVal = prefSection;

    // Attempt to fetch server profile and merge if available
    String profilePicture = '';
    try {
      final response = await _userService.getUserProfile();
      print('DEBUG: raw getUserProfile response: $response');
      final userData = response.containsKey('user') ? response['user'] : response;
      print('DEBUG: extracted userData: $userData');

      final cleanedFullName = (userData['fullName'] as String?)?.trim();
      final emailFromFirestore = (userData['email'] as String?)?.trim() ?? '';
      final schoolFromFirestore = (userData['school'] as String?)?.trim() ?? '';
      final courseFromFirestore = (userData['course'] as String?)?.trim() ?? '';
      final yearFromFirestore = (userData['yearLevel'] as String?)?.trim() ?? '';
      final sectionFromFirestore = (userData['section'] as String?)?.trim() ?? '';
      profilePicture = (userData['profilePicture'] as String?)?.trim() ?? '';

        // Avoid placeholder values (case-insensitive)
        final isPlaceholderName = cleanedFullName == null || cleanedFullName.isEmpty ||
          RegExp(r'recovered|example|user', caseSensitive: false).hasMatch(cleanedFullName);
      if (!isPlaceholderName) displayName = cleanedFullName;

      if (emailFromFirestore.isNotEmpty && !emailFromFirestore.contains('example.com')) {
        effectiveEmail = emailFromFirestore;
      }
      if (schoolFromFirestore.isNotEmpty) schoolVal = schoolFromFirestore;
      if (courseFromFirestore.isNotEmpty) courseVal = courseFromFirestore;
      if (yearFromFirestore.isNotEmpty) yearVal = yearFromFirestore;
      if (sectionFromFirestore.isNotEmpty) sectionVal = sectionFromFirestore;
    } catch (e) {
      // If backend call fails, keep using the auth/prefs-derived values and log error
      print('⚠️ getUserProfile failed, using auth/prefs fallback: $e');
    }

    // If school or section still empty, try reading Firestore doc directly as a final fallback
    try {
      if ((schoolVal.isEmpty || sectionVal.isEmpty) && FirebaseAuth.instance.currentUser != null) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          print('DEBUG: direct Firestore users/{uid} read: $data');
          final fsSchool = (data['school'] as String?)?.trim() ?? '';
          final fsSection = (data['section'] as String?)?.trim() ?? '';
          if (fsSchool.isNotEmpty) {
            schoolVal = fsSchool;
            await prefs.setString('profile_school', fsSchool);
          }
          if (fsSection.isNotEmpty) {
            sectionVal = fsSection;
            await prefs.setString('profile_section', fsSection);
          }
        }
      }
    } catch (e) {
      print('⚠️ direct Firestore read failed: $e');
    }

    // One-time repair: if Firestore is missing school/section but prefs have them, push to backend
    try {
      if (!_repairAttempted && FirebaseAuth.instance.currentUser != null) {
        final Map<String, String> toUpdate = {};
        if (schoolVal.isEmpty && prefSchool.isNotEmpty) toUpdate['school'] = prefSchool;
        if (sectionVal.isEmpty && prefSection.isNotEmpty) toUpdate['section'] = prefSection;
        if (toUpdate.isNotEmpty) {
          _repairAttempted = true;
          await _userService.updateProfile(
            school: toUpdate['school'],
            section: toUpdate['section'],
          );
          // Reflect repair in current view
          if (toUpdate['school'] != null) schoolVal = toUpdate['school']!;
          if (toUpdate['section'] != null) sectionVal = toUpdate['section']!;
          print('🛠️ Repaired missing profile fields in Firestore: $toUpdate');
        }
      }
    } catch (e) {
      print('⚠️ Failed to repair missing profile fields: $e');
    }

    if (mounted) {
      setState(() {
        _user = {
          'name': displayName,
          'email': effectiveEmail,
          'school': schoolVal,
          'course': courseVal,
          'yearLevel': yearVal,
          'section': sectionVal,
          'profilePicture': profilePicture,
        };
        _isLoading = false;
      });
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      // ignore: avoid_print
      print('[ProfileScreen] Profile loaded in ${elapsed}ms');
    }
  } catch (e) {
    print('Error loading profile: $e');
    if (mounted) {
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
        _showEditProfileDialog();
        break;
      case 'change_picture':
        _uploadProfilePicture();
        break;
      case 'notifications':
        _showNotifications();
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

  Future<void> _uploadProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Upload to server
      final profilePictureUrl = await _userService.uploadProfilePicture(image);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (profilePictureUrl != null) {
        setState(() {
          _user['profilePicture'] = profilePictureUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      if (!mounted) return;
      
      // Close loading dialog if still open
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload profile picture: $e')),
      );
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _user['name']);
    final schoolController = TextEditingController(text: _user['school']);
    final sectionController = TextEditingController(text: _user['section']);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile', style: TextStyle(fontFamily: 'Outfit')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: schoolController,
                decoration: const InputDecoration(labelText: 'School (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: sectionController,
                decoration: const InputDecoration(labelText: 'Section (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newName = nameController.text.trim();
      final newSchool = schoolController.text.trim();
      final newSection = sectionController.text.trim();
      try {
        setState(() => _isLoading = true);
        await _userService.updateProfile(fullName: newName, school: newSchool.isNotEmpty ? newSchool : null, section: newSection.isNotEmpty ? newSection : null);
        // Reload profile after successful update
        await _loadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
                              Row(
                                children: [
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_outlined),
                                        onPressed: _showNotifications,
                                      ),
                                      if (_unreadCount > 0)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              _unreadCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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
                                  GestureDetector(
                                    onTap: _uploadProfilePicture,
                                    child: Stack(
                                      children: [
                                        ClipOval(
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            color: const Color(0xFF3B82F6),
                                            child: _user['profilePicture'] != null && _user['profilePicture']!.isNotEmpty
                                                ? Image.network(
                                                    _user['profilePicture']!,
                                                    width: 80,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      print('❌ Failed to load profile picture: $error');
                                                      return Center(
                                                        child: Text(
                                                          (_user['name'] != null && _user['name']!.isNotEmpty)
                                                              ? _user['name']![0].toUpperCase()
                                                              : 'U',
                                                          style: const TextStyle(
                                                            fontSize: 32,
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
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Center(
                                                    child: Text(
                                                      (_user['name'] != null && _user['name']!.isNotEmpty)
                                                          ? _user['name']![0].toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        fontSize: 32,
                                                        color: Colors.white,
                                                        fontFamily: 'Outfit',
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 14,
                                              color: Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                      ],
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
                                        const SizedBox(height: 6),
                                        // Show email under the name
                                        Text(
                                          _user['email'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
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
                                  // School
                                  _buildDetailItem(Icons.school_outlined, _user['school'] ?? ''),
                                  const SizedBox(height: 16),
                                  // Section (show only when available)
                                  _buildDetailItem(
                                    Icons.class_outlined,
                                    (_user['section'] != null && _user['section']!.isNotEmpty)
                                        ? 'Section ${_user['section']}'
                                        : 'Section not set',
                                  ),
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
      print('Error loading notifications (profile): $e');
    }
  }

  void _showNotifications() async {
    await _loadNotifications();
    if (!mounted) return;
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
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return ListTile(
                      title: Text(n['message'] ?? '', style: const TextStyle(fontFamily: 'Outfit')),
                      subtitle: Text((n['type'] ?? '').toString(), style: const TextStyle(fontFamily: 'Outfit')),
                      trailing: n['read'] == true
                          ? const Icon(Icons.check, color: Colors.green, size: 18)
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}