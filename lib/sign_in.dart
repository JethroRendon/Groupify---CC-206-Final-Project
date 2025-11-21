import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_account.dart';
import 'dashboard.dart';
import 'onboarding.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // After sign in, obtain fresh token and verify with backend
      final token = await _authService.getToken();
      final api = ApiClient();
      api.setToken(token);
      final verifyResp = await api.get('/auth/verify');

      if (!mounted) return;
      var redirectTo = verifyResp['redirectTo'] as String? ?? 'home';
      redirectTo = redirectTo.trim().toLowerCase();
      print('DEBUG: sign-in verify redirectTo => "$redirectTo"');

      if (redirectTo == 'onboarding') {
        print('NAV: sign-in -> Onboarding');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
      } else {
        print('NAV: sign-in -> Home');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
  final emailController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset Password', style: TextStyle(fontFamily: 'Outfit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter your email address and we\'ll send you a password reset link.',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
        ),
        ElevatedButton(
          onPressed: () async {
            if (emailController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your email')),
              );
              return;
            }

            try {
              await FirebaseAuth.instance.sendPasswordResetEmail(
                email: emailController.text.trim(),
              );
              Navigator.pop(context, true);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          },
          child: const Text('Send Reset Link', style: TextStyle(fontFamily: 'Outfit')),
        ),
      ],
    ),
  );

  if (result == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset email sent! Check your inbox.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.50, -0.00),
            end: Alignment(0.50, 0.39),
            colors: [Color(0xFF6595E4), Color(0xFF3B82F6)],
          ),
        ),
        child: Stack(
          children: [
            // Student image
            Positioned(
              left: 0,
              top: 42,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 469,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/student.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // White container
            Positioned(
              left: 0,
              top: 300,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 578,
                decoration: const ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    ),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Stack(
                    children: [
                      // Email Field
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        top: 66,
                        child: const Text(
                          'Email',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        top: 85,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: 43,
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 2,
                                color: Color(0xFFECEDF1),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'studentemail@mail.com',
                              hintStyle: TextStyle(
                                color: Color(0xFFB3B0B0),
                                fontSize: 12,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 13, top: 5, bottom: 15),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      
                      // Password Field
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        top: 146,
                        child: const Text(
                          'Password',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        top: 165,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: 43,
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 2,
                                color: Color(0xFFECEDF1),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(left: 13, top: 5, bottom: 15, right: 13),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: const Color(0xFFB3B0B0),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      
                      // Sign In Button
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.1,
                        top: 236,
                        child: GestureDetector(
                          onTap: _isLoading ? null : _handleSignIn,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            padding: const EdgeInsets.all(10),
                            decoration: ShapeDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
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
                                      'Sign In',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Forgot Password
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 297,
                        child: Center(
                          child: GestureDetector(
                            onTap: _handleForgotPassword,
                            child: const Text(
                              'Forgot Password?',
                             style: TextStyle(
                               color: Color(0xFF3B82F6),
                               fontSize: 15,
                               fontFamily: 'Outfit',
                               fontWeight: FontWeight.w500,
                             ),
                           ),
                          ),
                       ),
                      ),
                      
                      // Sign Up Text
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 422,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CreateAccountScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 15,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Avatar circle
            Positioned(
              left: 39,
              top: 270,
              child: SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const ShapeDecoration(
                          color: Color(0xFFCDE0FF),
                          shape: OvalBorder(),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 16,
                      child: Container(
                        width: 59,
                        height: 42,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/glogo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}