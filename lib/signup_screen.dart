import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/adding_infoscreen.dart';
import 'package:spotvibe/login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isOtpVerified = false;
  bool otpSubmitted = false;
  int countdown = 0;
  Timer? timer;

  final String baseUrl = "https://f410765f9588.ngrok-free.app/api/auth";

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> sendOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return showSnack("Please enter your email");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        showSnack("OTP sent to $email");
        setState(() {
          countdown = 60;
          isOtpVerified = false;
          otpSubmitted = false;
        });
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() {
            if (countdown == 0) {
              t.cancel();
            } else {
              countdown--;
            }
          });
        });
      } else {
        showSnack("Error: ${data['message']}");
      }
    } catch (_) {
      showSnack("Failed to send OTP. Is server running?");
    }
  }

  Future<void> verifyOtp() async {
    if (otpSubmitted) return;

    final otp = otpController.text.trim();
    final email = emailController.text.trim();
    if (otp.length != 6) return;

    setState(() => otpSubmitted = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() => isOtpVerified = true);
        showSnack("OTP verified ✅");
      } else {
        showSnack("Invalid or expired OTP ❌");
      }
    } catch (_) {
      showSnack("Verification failed");
    }
  }

  Future<void> setPassword() async {
    final email = emailController.text.trim();
    final pass = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (!isOtpVerified) return showSnack("Please verify OTP first");
    if (pass.isEmpty || confirm.isEmpty) return showSnack("Please fill in all fields");
    if (pass != confirm) return showSnack("Passwords do not match");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/set-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pass}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          debugPrint('Token saved to SharedPreferences');
        }

        showSnack("Password set successfully ✅");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AddInfoScreen()),
        );
      } else {
        showSnack(data['message'] ?? "Failed to set password");
      }
    } catch (e) {
      debugPrint("Error setting password: $e");
      showSnack("Error setting password");
    }
  }


  @override
  void dispose() {
    timer?.cancel();
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Sign Up"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Image.asset('assets/images/SpotVibe_Logo.png', height: 100, width: 100),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                suffixIcon: countdown > 0
                    ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text("Wait $countdown s", style: TextStyle(color: Colors.grey[600])),
                )
                    : TextButton(onPressed: sendOtp, child: const Text("Send OTP")),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'OTP',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: "",
              ),
              onChanged: (value) {
                if (value.length == 6 && !isOtpVerified) {
                  verifyOtp();
                }
              },
            ),
            const SizedBox(height: 15),
            if (isOtpVerified) ...[
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 25),
              Center(
                child: GestureDetector(
                  onTap: setPassword,
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Continue',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
