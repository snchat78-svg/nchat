// 📁 lib/pages/splash_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/auth_gate.dart'; // ✅ सही Import

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ Fade-in Animation Setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // ✅ 3 सेकंड बाद AuthGate पर Redirect
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ App Icon
              const Image(
                image: AssetImage('assets/icons/app_icon.png'),
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 25),

              // ✅ App Name
              const Text(
                "Nchat",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // ✅ Tagline
              const Text(
                "Connecting Nearby People...",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),

              // ✅ Loading Indicator
              const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
