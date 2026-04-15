// 📁 lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔐 SIGN UP
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCred.user;
      if (user != null) {
        await requestNotificationPermission(); // 🔔 ADD: Ask permission
        await _saveDeviceToken(user.uid);      // ✅ FCM token save after signup
        listenToTokenRefresh();                // 🔄 ADD: Listen token refresh
      } else {
        debugPrint("🚫 Signup Error: user is null");
      }

      return userCred;
    } on FirebaseAuthException catch (e) {
      debugPrint("⚠️ Firebase Signup Error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      debugPrint("🚫 Signup Error: $e");
      return null;
    }
  }

  // 🔓 SIGN IN
  Future<User?> signIn(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCred.user;
      if (user != null) {
        await requestNotificationPermission(); // 🔔 ADD: Ask permission
        await _saveDeviceToken(user.uid);      // ✅ Save FCM Token after login
        listenToTokenRefresh();                // 🔄 ADD: Listen token refresh
      } else {
        debugPrint("🚫 Signin Error: user is null");
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("⚠️ Firebase Signin Error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      debugPrint("🚫 Signin Error: $e");
      return null;
    }
  }

  // 🚪 LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ✅ ALIAS FOR LOGOUT (For compatibility)
  Future<void> logout() async => await signOut();

  // 🔍 CURRENT USER
  User? get currentUser => _auth.currentUser;

  // ✅ ✅ ADD THIS — Fix for “getter currentUserId not defined” error
  String? get currentUserId {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // 🔔 🔔 ADD: Request Notification Permission (Android 12+ FIX)
  Future<void> requestNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint("🔔 Notification permission status: ${settings.authorizationStatus}");
    } catch (e) {
      debugPrint("🔴 Error requesting notification permission: $e");
    }
  }

  // 🔄 🔄 ADD: Listen to FCM Token Refresh (Very Important)
  void listenToTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'fcmToken': newToken},
          SetOptions(merge: true),
        );

        debugPrint("🔄 FCM Token refreshed & saved");
      } catch (e) {
        debugPrint("🔴 Error saving refreshed FCM Token: $e");
      }
    });
  }

  // ✅ Save FCM Token to Firestore
  Future<void> _saveDeviceToken(String uid) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmToken': fcmToken},
          SetOptions(merge: true),
        );
        debugPrint("✅ FCM Token saved successfully");
      } else {
        debugPrint("⚠️ FCM Token not found");
      }
    } catch (e) {
      debugPrint("🔴 Error saving FCM Token: $e");
    }
  }
}
