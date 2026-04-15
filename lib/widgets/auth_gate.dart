// 📁 lib/widgets/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_service.dart';
import '../models/user_model.dart';

// 🔑 Pages
import '../pages/login_page.dart';
import '../pages/home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  bool isLoading = true;
  Widget? targetPage;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final currentUser = _auth.currentUser;

    // ❌ अगर कोई लॉगिन यूज़र नहीं है → Login Page दिखाओ
    if (currentUser == null) {
      setState(() {
        targetPage = const LoginPage();
        isLoading = false;
      });
      return;
    }

    try {
      await currentUser.reload(); // Refresh auth state
    } catch (e) {
      debugPrint("reload error: $e");
    }

    final refreshed = _auth.currentUser;
    final isVerified = refreshed?.emailVerified ?? false;

    // ❌ अगर ईमेल वेरिफाइड नहीं है → Login Page दिखाओ
    if (!isVerified) {
      setState(() {
        targetPage = const LoginPage();
        isLoading = false;
      });
      return;
    }

    // ✅ Firestore से यूज़र डेटा लाओ
    UserModel? userModel = await _userService.getUserById(currentUser.uid);
    String userType = (userModel?.userType ?? '').trim();

    // ⚠️ अगर कुछ नहीं मिला तो डिफ़ॉल्ट person बना दो
    if (userModel == null || userType.isEmpty || userType == 'pending') {
      final minimal = UserModel(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        name: '',
        age: 0,
        userType: 'person',
      );
      await _userService.saveUserData(minimal);

      // 🔄 Refresh data
      userModel = await _userService.getUserById(currentUser.uid);
      userType = (userModel?.userType ?? 'person').trim();
    }

    // 🎯 अब सिर्फ़ person फ्लो रहेगा
    targetPage = const HomePage();

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || targetPage == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return targetPage!;
  }
}
