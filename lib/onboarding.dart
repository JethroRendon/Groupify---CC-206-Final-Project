import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/api_client.dart';
import 'sign_in.dart';
import 'create_account.dart';
import 'dashboard.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Debug: indicate onboarding was built
    // ignore: avoid_print
    print('BUILD: OnboardingScreen rendered');

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(
          children: [
            Positioned(
              left: -46,
              top: -172,
              child: Container(
                width: 594,
                height: 749,
                decoration: const ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.50, 0.26),
                    end: Alignment(0.50, 1.00),
                    colors: [Color(0xFF3B82F6), Color(0xFF6595E4)],
                  ),
                  shape: OvalBorder(),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Image.asset(
                      'assets/images/groupifylogo.png',
                      width: 175,
                      height: 124,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Groupify',
                      style: TextStyle(
                        fontSize: 40,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Collaboration made student-simple.',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Outfit',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // If there's an authenticated user, show a clear "Continue" button
                    // that marks onboarding as seen and navigates to Home.
                    if (user != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Text(
                          'Welcome back, ${user.displayName ?? user.email ?? 'Student'}',
                          style: const TextStyle(fontSize: 16, fontFamily: 'Outfit'),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Ask backend to mark onboarding as seen (backend uses Admin SDK)
                            try {
                              final api = ApiClient();
                              await api.post('/auth/complete-onboarding', {});
                              print('NAV: Onboarding -> Home (marked via backend)');
                            } catch (e) {
                              print('⚠️ Failed to mark hasSeenOnboarding via backend: $e');
                              // As a fallback, attempt client-side write (may fail due to security rules)
                              try {
                                final uid = user.uid;
                                await FirebaseFirestore.instance.collection('users').doc(uid).set(
                                  {'hasSeenOnboarding': true, 'lastLogin': DateTime.now().toIso8601String()},
                                  SetOptions(merge: true),
                                );
                                print('NAV: Onboarding -> Home (client-side fallback succeeded)');
                              } catch (e2) {
                                print('⚠️ Client-side fallback also failed: $e2');
                              }
                            }

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Continue to Home',
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ] else ...[
                      // Not signed in: show Sign In / Create Account as before
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignInScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateAccountScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.all(15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
