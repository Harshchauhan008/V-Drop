import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();

  bool otpSent = false;
  final String baseUrl = "https://f410765f9588.ngrok-free.app/api/auth";

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> sendOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return showSnack("Enter your email");

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(res.body);
      if (data['success']) {
        showSnack("OTP sent to email");
        setState(() => otpSent = true);
      } else {
        showSnack(data['message']);
      }
    } catch (_) {
      showSnack("Failed to send OTP");
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    final newPassword = newPasswordController.text.trim();

    // ✅ Add this validation at the top of the function
    if (otp.length != 6 || newPassword.length < 6) {
      return showSnack("Enter a valid 6-digit OTP and password (min 6 chars)");
    }


    try {
      final res = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(res.body);
      if (!mounted) return;

      if (data['success']) {
        showSnack("Password reset successful ✅");
        Navigator.pop(context); // Go back to login screen
      } else {
        showSnack(data['message']);
      }
    } catch (_) {
      showSnack("Error resetting password");
    }
  }


  Future<void> verifyOtp() async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': emailController.text.trim(), 'otp': otpController.text.trim()}),
    );
    final data = jsonDecode(res.body);
    if (!mounted) return;

    if (data['success']) {
      showSnack("OTP verified ✅");
    } else {
      showSnack("Invalid OTP ❌");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen())); // 👈 Goes back to the previous screen (SignUpScreen)
            },
          ),
          title: Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Username/Email',
                labelStyle: const TextStyle(fontSize: 13),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/user.png',
                    width: 24,
                    height: 24,
                    color: Colors.grey[700],
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueGrey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (otpSent) ...[
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
                  if (value.length == 6) {
                    verifyOtp();
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () {
                  otpSent ? resetPassword() : sendOtp(); // ✅ correct
                },
                child: Container(
                  width: 200,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple], // your gradient colors
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                        otpSent ? "Reset Password" : "Send OTP",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
