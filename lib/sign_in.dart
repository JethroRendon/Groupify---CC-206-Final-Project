import 'package:flutter/material.dart';
import 'create_account.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _obscurePassword = true;

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
                child: Stack(
                  children: [
                    // Form fields
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
                        child: const TextField(
                          decoration: InputDecoration(
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
                        ),
                      ),
                    ),
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
                        child: TextField(
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
                        ),
                      ),
                    ),
                    // Sign In Button
                    Positioned(
                      left: MediaQuery.of(context).size.width * 0.1,
                      top: 236,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Center(
                          child: Text(
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
                    // Forgot Password
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 297,
                      child: Center(
                        child: Text(
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
            // Avatar circle and decorations - NOW OUTSIDE the white container
            Positioned(
              left: 39,
              top: 270,
              child: Container(
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