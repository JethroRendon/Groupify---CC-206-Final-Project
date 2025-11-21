import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'dashboard.dart';
import 'services/api_client.dart';
import 'onboarding.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolController = TextEditingController();
  final _courseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _selectedYearLevel;
  String? _selectedSection;

  final List<String> _yearLevels = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> _sections = ['A', 'B'];

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        school: _schoolController.text.trim(),
        course: _courseController.text.trim(),
        yearLevel: _selectedYearLevel!,
        section: _selectedSection!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!'), backgroundColor: Colors.green),
      );

      // Ensure backend recognizes the user and decide where to redirect
      // Refresh token and give a short pause so Firestore writes propagate.
      await Future.delayed(const Duration(seconds: 1));
      final token = await _authService.getToken();
      print('DEBUG: signup -> using token: ${token?.substring(0, 20)}...');
      final api = ApiClient();
      api.setToken(token);
      final verifyResp = await api.get('/auth/verify');
      var redirectTo = verifyResp['redirectTo'] as String? ?? 'home';
      redirectTo = redirectTo.trim().toLowerCase();
      print('DEBUG: signup verify redirectTo => "$redirectTo"');

      if (!mounted) return;
      if (redirectTo == 'onboarding') {
        print('NAV: sign-up -> Onboarding');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
      } else {
        print('NAV: sign-up -> Home');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _courseController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Color(0xFF3B82F6)),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 70,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height - 70,
                decoration: const ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.077),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 34),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.arrow_back, size: 24),
                            ),
                            const SizedBox(width: 15),
                            const Text('Create Account', style: TextStyle(fontSize: 20, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Full Name
                        _buildLabel('Full Name'),
                        _buildTextField(_fullNameController, 'Juan Dela Cruz', (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),

                        // Email
                        _buildLabel('Email'),
                        _buildTextField(_emailController, 'student@school.edu.ph', (v) {
                          if (v!.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        }, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),

                        // School
                        _buildLabel('School'),
                        _buildTextField(_schoolController, 'West Visayas State University', (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),

                        // Course
                        _buildLabel('Course'),
                        _buildTextField(_courseController, 'BS Computer Science', (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),

                        // Year Level and Section
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Year Level'),
                                  _buildDropdown(_selectedYearLevel, _yearLevels, 'Select year', (v) => setState(() => _selectedYearLevel = v)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Section'),
                                  _buildDropdown(_selectedSection, _sections, 'Select section', (v) => setState(() => _selectedSection = v)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Password
                        _buildLabel('Password'),
                        _buildPasswordField(_passwordController, _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
                        const SizedBox(height: 12),

                        // Confirm Password
                        _buildLabel('Confirm Password'),
                        _buildPasswordField(_confirmPasswordController, _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                        const SizedBox(height: 30),

                        // Create Account Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Create Account', style: TextStyle(fontSize: 20, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500));
  }

  Widget _buildTextField(TextEditingController controller, String hint, String? Function(String?)? validator, {TextInputType? keyboardType}) {
    return Container(
      height: 43,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: Color(0xFFECEDF1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB3B0B0), fontSize: 12, fontFamily: 'Outfit'),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 13, top: 5, bottom: 15),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, bool obscure, VoidCallback toggle) {
    return Container(
      height: 43,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: Color(0xFFECEDF1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: (v) => v!.isEmpty ? 'Required' : (v.length < 8 ? 'Min 8 characters' : null),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 13, top: 5, bottom: 15, right: 13),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFFB3B0B0), size: 20),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String? value, List<String> items, String hint, void Function(String?) onChanged) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: Color(0xFFECEDF1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Color(0xFFB3B0B0), fontSize: 12, fontFamily: 'Outfit')),
          isExpanded: true,
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit')))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}