import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

import 'home_page.dart';
import 'signup_page.dart';
import 'register_person_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService authService = AuthService();
  final UserService userService = UserService();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginAndRedirect() async {
    final ctx = context;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text("Email और Password दोनों भरना ज़रूरी है")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await authService.signIn(email, password);

      if (!mounted) return;

      if (user == null) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Login Failed")),
        );
        return;
      }

      final uid = user.uid;
      final authEmail = user.email ?? email;

      try {
        await user.reload();
      } catch (_) {}

      final refreshed = FirebaseAuth.instance.currentUser;
      final isVerified =
          refreshed?.emailVerified ?? user.emailVerified ?? false;

      if (!isVerified) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Please verify your email first")),
        );
        return;
      }

      var userModel = await userService.getUserById(uid);

if (!mounted) return;

setState(() => isLoading = false);

if (userModel == null || (userModel.name?.isEmpty ?? true)) {

  // पहली बार login → Register page
  Navigator.of(ctx).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RegisterPersonPage()),
    (route) => false,
  );

} else {

  // details already मौजूद हैं
  Navigator.of(ctx).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()),
    (route) => false,
  );

}
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [

                const SizedBox(height: 40),

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Login to continue",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 5),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final email = emailController.text.trim();

                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("पहले Email डालें"),
                                ),
                              );
                              return;
                            }

                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(email: email);

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Password reset email भेज दिया गया"),
                              ),
                            );
                          },
                          child: const Text("Forgot Password?"),
                        ),
                      ),

                      const SizedBox(height: 15),

                      isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: loginAndRedirect,
                                child: const Text(
                                  "Login",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignupPage()),
                    );
                  },
                  child: const Text("Create Account"),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
