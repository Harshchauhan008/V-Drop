import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/forgottenpassword_screen.dart';
import 'package:spotvibe/main.dart';
import 'package:spotvibe/profile_screen.dart';
import 'package:spotvibe/signup_screen.dart';


import 'adding_infoscreen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  bool _isChecking = true; // Add this flag to prevent screen flashing

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySignUp = prefs.getBool('signedup') ?? false;

    if (!alreadySignUp) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    // Optional: Try to check if session is still valid (skip this to force sign-in every time)
    final googleUser = await GoogleAuthService.getGoogleSignIn().signInSilently();

    if (googleUser != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else {
      if (mounted) setState(() => _isChecking = false);
    }
  }


  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final account = await GoogleAuthService.signInWithGoogle();

      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        final hasSignedUp = prefs.getBool('signedup') ?? false;

        if (hasSignedUp) {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        } else {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const AddInfoScreen()),
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Google Sign-In was cancelled ❌')),
        );
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      messenger.showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    }
  }


  Future<void> loginUser() async {
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://f410765f9588.ngrok-free.app/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final user = data['user'];
        final token = data['token']; // << Add this

        final userId = user['userId'] ?? user['user_id'];
        await prefs.setString('userId', userId.toString());
        await prefs.setString('token', token);

        final hasUsername = user['username'] != null && user['username'].toString().isNotEmpty;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful ✅")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => hasUsername ? const MainNavigation() : const AddInfoScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Login failed")),
        );
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong during login")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Transform.scale(
              scale: 1.2,
              child: Image.asset(
                'assets/images/Worldmap.jpg',
                width: size.width,
                height: size.height,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors:[Color(0xFF2490BD).withAlpha(152),Color(0xFFED2529).withAlpha(102)],
                stops: [0.0, 0.9],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'SpotVibe',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF2D7A), Color(0xFF8E2DE2)],
                      ).createShader(const Rect.fromLTWH(0, 0, 500, 0)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Let you explore the World',
                  style: TextStyle(
                    fontFamily: 'HomemadeApple',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF2D7A), Color(0xFF8E2DE2)],
                      ).createShader(const Rect.fromLTWH(0, 0, 500, 0)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 280,
              left: 50,
              child: Stack(
                children: [
                  Container(
                    height: 430,
                    width: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(150),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: loginEmailController,
                            decoration: InputDecoration(
                              labelText: 'Username/Email',
                              labelStyle: const TextStyle(fontSize: 13),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  'assets/images/user.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.white,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blueGrey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: loginPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Enter Password',
                              labelStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blueGrey),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen())
                                );
                              },
                              child: const Text(
                                'Forgotten Password?',
                                style: TextStyle(fontSize: 12, color: Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: loginUser,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: const [
                              Expanded(child: Divider(thickness: 1.2, endIndent: 10)),
                              Text('OR', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Divider(thickness: 1.2, indent: 10)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _handleGoogleSignIn(context),
                            child: Container(
                              width: 120,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Image.asset(
                                'assets/images/Google_Logo.png',
                                height: 30,
                                width: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 40),
                                child: Text(
                                  'Do not have account?',
                                  style: TextStyle(color: Colors.black87, fontSize: 14),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SignUpScreen())
                                  );
                                },
                                child: const Text(
                                  'Sign up',
                                  style: TextStyle(color: Colors.blue, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  static Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      await _googleSignIn.disconnect().catchError((_) => null);
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      debugPrint('Google Sign-In Failed: $error');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _googleSignIn.disconnect();
  }

  static GoogleSignIn getGoogleSignIn() {
    return _googleSignIn;
  }
}


