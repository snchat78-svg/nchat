// 📁 lib/services/nearby_notification_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'push_notification_service.dart';

class NearbyNotificationService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Timer? _timer;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// ✅ Start monitoring nearby users (every 3 minutes)
  Future<void> startMonitoring() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    // हर 3 मिनट में nearby users चेक करें
    _timer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      await _checkNearbyUsers();
    });
  }

  /// ✅ Nearby Personal Users Finder
  Future<void> _checkNearbyUsers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // 🔹 Current location लो
    final position = await Geolocator.getCurrentPosition();

    // 🔹 Firestore से सभी person users लाओ
    final allDocs = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'person')
        .get();

    for (var doc in allDocs.docs) {
      if (doc.id == currentUser.uid) continue; // खुद को छोड़ दो

      final data = doc.data();
      final double lat = (data['latitude'] ?? 0).toDouble();
      final double lng = (data['longitude'] ?? 0).toDouble();
      final String name = data['name'] ?? 'Unknown User';

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );

      // ✅ अगर यूज़र 500m के अंदर है तो notify करो
      if (distance <= 500) {
        await _sendNotification(name);

        await PushNotificationService().sendPushMessage(
          currentUser.uid, // खुद यूज़र को
          "Nearby User Found",
          "$name आपके पास है! चैट शुरू करें।",
          data: {"screen": "chatUsersPage", "targetUser": name},
        );

        break; // एक बार notify करने के बाद loop रोक दो
      }
    }
  }

  /// ✅ Local Notification (Android)
  Future<void> _sendNotification(String userName) async {
    const android = AndroidNotificationDetails(
      'nearby_user_channel',
      'Nearby Users',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: android);

    await _localNotifications.show(
      1,
      '📍 नज़दीकी यूज़र मिला',
      '$userName अभी आपके पास है! चैट शुरू करें।',
      details,
    );
  }

  /// ✅ Stop monitoring
  void stopMonitoring() {
    _timer?.cancel();
  }

  /// ✅ Initialize local notifications (main.dart में कॉल करें)
  static Future<void> initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
  }
}
