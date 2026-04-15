// 📁 lib/services/push_notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// 🔹 Initialize Notification System (App Start पर चलाओ)
  Future<void> init() async {
    // 1️⃣ Permission for Notifications
    await _fcm.requestPermission();

    // 2️⃣ Generate and Save FCM Token
    final token = await _fcm.getToken();
    print("🪪 FCM Token: $token");

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && token != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .set({"fcmToken": token}, SetOptions(merge: true));
    }

    // ❌ Foreground listener यहां नहीं है (main.dart handle कर रहा है)

    // 4️⃣ जब यूज़र Notification पर Tap करे
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📩 User tapped notification => ${message.data}");
    });

    // 5️⃣ Token Refresh Listener
    _fcm.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({"fcmToken": newToken}, SetOptions(merge: true));
        print("🔄 FCM Token Updated: $newToken");
      }
    });
  }

  /// 🔹 Public Static Method (Foreground में popup दिखाने के लिए)
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'nchat_channel',
      'Nchat Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: android);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// 🔹 Initialize Local Notification Plugin
  static Future<void> initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
  }

  /// 🔹 किसी User को Push भेजना + Firestore में Auto Save
  Future<void> sendPushMessage(
    String receiverId,
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    try {
      // Receiver का FCM Token लो
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(receiverId)
          .get();

      if (!doc.exists || doc.data()?['fcmToken'] == null) {
        print("❌ Receiver Token नहीं मिला");
        return;
      }

      final String token = doc['fcmToken'];

      // ⚠️ NOTE: यह production में Cloud Functions से होना चाहिए
      const String serverKey = "AIzaSyCUK7TJVNvXrcJT8CxVlA0KzaKRJtTcAgw";

      final response = await http.post(
        Uri.parse("https://fcm.googleapis.com/fcm/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "key=$serverKey",
        },
        body: jsonEncode({
          "to": token,
          "notification": {
            "title": title,
            "body": body,
          },
          "data": data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Push Sent Successfully to $receiverId");

        // 🔹 ✅ AUTO SAVE in Firestore (NotificationPage के लिए)
        await FirebaseFirestore.instance.collection('notifications').add({
          'uid': receiverId,
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
        });

        print("📦 Notification Auto-Saved to Firestore");
      } else {
        print("❌ Push Failed: ${response.body}");
      }
    } catch (e) {
      print("🔥 Error sending push: $e");
    }
  }
}
