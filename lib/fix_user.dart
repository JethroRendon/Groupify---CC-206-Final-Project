import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FixUserScreen extends StatefulWidget {
  const FixUserScreen({super.key});

  @override
  State<FixUserScreen> createState() => _FixUserScreenState();
}

class _FixUserScreenState extends State<FixUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _courseController = TextEditingController();
  String? _selectedYearLevel;
  String? _selectedSection;
  bool _isLoading = false;
  String _status = '';

  final List<String> _yearLevels = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];

  Future<void> _fixUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedYearLevel == null || _selectedSection == null) {
      setState(() => _status = '❌ Please select year level and section');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Getting current user...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        setState(() {
          _status = '❌ No user logged in. Please sign in first.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _status = 'Found user: ${user.uid}\nCreating Firestore document...');

      // Create user document in Firestore
      final userData = {
        'uid': user.uid,
        'fullName': _fullNameController.text.trim(),
        'email': user.email,
        'school': _schoolController.text.trim(),
        'course': _courseController.text.trim(),
        'yearLevel': _selectedYearLevel,
        'section': _selectedSection,
        'hasSeenOnboarding': true,
        'groupIds': [],
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      setState(() {
        _status = '✅ SUCCESS!\n\n'
            'User document created:\n'
            'UID: ${user.uid}\n'
            'Name: ${userData['fullName']}\n'
            'Email: ${userData['email']}\n\n'
            'You can now use the app normally!\n'
            'Restart the app to see changes.';
        _isLoading = false;
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✅ User Fixed!'),
          content: const Text(
            'Your user document has been created in Firestore.\n\n'
            'Please restart the app now.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUser() async {
    setState(() => _status = 'Checking current user...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        setState(() => _status = '❌ No user logged in');
        return;
      }

      // Check if document exists
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _status = '✅ User document EXISTS!\n\n'
              'Data: ${doc.data()}\n\n'
              'You don\'t need to fix anything.';
        });
      } else {
        setState(() {
          _status = '❌ User document MISSING!\n\n'
              'UID: ${user.uid}\n'
              'Email: ${user.email}\n\n'
              'Fill in the form below to create it.';
          _fullNameController.text = user.displayName ?? '';
        });
      }
    } catch (e) {
      setState(() => _status = '❌ Error checking user: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix User Document'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  _status.isEmpty ? 'Checking user status...' : _status,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text(
                'Fill in your details:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: 'School',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _courseController,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedYearLevel,
                decoration: const InputDecoration(
                  labelText: 'Year Level',
                  border: OutlineInputBorder(),
                ),
                items: _yearLevels.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedYearLevel = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                ),
                items: _sections.map((section) {
                  return DropdownMenuItem(
                    value: section,
                    child: Text('Section $section'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSection = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              
              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _fixUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create User Document',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              OutlinedButton(
                onPressed: _checkCurrentUser,
                child: const Text('Check User Status Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _schoolController.dispose();
    _courseController.dispose();
    super.dispose();
  }
}