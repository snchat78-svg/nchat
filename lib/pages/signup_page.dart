// 📁 lib/pages/signup_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final AuthService authService = AuthService();
  final UserService userService = UserService();

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
	confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final scaffoldContext = context;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // ✅ Create Firebase account
      final userCred = await authService.signUp(email, password);
      final user = userCred?.user;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(content: Text("❌ Signup failed — User not created")),
        );
        return;
      }

      // ✅ Send Email Verification
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(content: Text('📩 Verification email sent!')),
        );
      } on FirebaseAuthException catch (e) {
        debugPrint('Verification send error: ${e.code} - ${e.message}');
        if (mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(content: Text('⚠️ Email send failed: ${e.message}')),
          );
        }
      }

      // ✅ Save user data in Firestore (PERSONAL ONLY)
      final emailToSave =
          (user.email != null && user.email!.isNotEmpty) ? user.email! : email;

      final userModel = UserModel(
        uid: user.uid,
        email: emailToSave,
        name: '',
        age: 0,
        userType: 'person', // ✅ Personal userType fixed
        gender: null,
        profilePic: '',
      );

      try {
        await userService.saveUserData(userModel);
      } catch (e) {
        debugPrint('Save user data failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(content: Text('⚠️ Error saving user: $e')),
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
  const SnackBar(
    content: Text('✅ Account created! Please verify your email before login.'),
  ),
);

// Signup के बाद user को Login page पर भेजो
Navigator.pop(scaffoldContext);
    } on FirebaseAuthException catch (e, stackTrace) {

  // 🔥 PC में दिखेगा (adb logcat)
  debugPrint("🔥 SIGNUP AUTH ERROR: ${e.code} - ${e.message}");
  debugPrint("📍 STACK TRACE: $stackTrace");

  final msg = e.code == 'email-already-in-use'
      ? '⚠️ यह ईमेल पहले से उपयोग में है'
      : e.message ?? 'Authentication error';

  if (mounted) {
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
} catch (e, stackTrace) {

  // 🔥 PC में दिखेगा
  debugPrint("🔥 SIGNUP GENERAL ERROR: ${e.toString()}");
  debugPrint("📍 STACK TRACE: $stackTrace");

  if (!mounted) return;

  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
    SnackBar(content: Text("❌ Error: $e")),
  );
}
 finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Email भरें";
                  }
                  if (!value.contains('@')) {
                    return "सही Email डालें";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Password भरें";
                  }
                  if (value.length < 6) {
                    return "Password कम से कम 6 characters का होना चाहिए";
                  }
                  return null;
                },
              ),
			  const SizedBox(height: 10),

TextFormField(
  controller: confirmPasswordController,
  obscureText: true,
  decoration: const InputDecoration(
    labelText: 'Re-enter Password',
    prefixIcon: Icon(Icons.lock_outline),
  ),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return "Password फिर से डालें";
    }
    if (value != passwordController.text) {
      return "Passwords match नहीं कर रहे";
    }
    return null;
  },
),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Create Account'),
                      onPressed: _signup,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
