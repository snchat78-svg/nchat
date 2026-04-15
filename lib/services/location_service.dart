import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

class LocationService {
  /// ✅ Permission check (location on & granted)
  static Future<bool> ensurePermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("❌ Location service disabled");
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 🔹 यह नया जोड़ा गया हिस्सा — background location permission के लिए
      if (permission == LocationPermission.whileInUse) {
        // Try to get always permission for background updates
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint("❌ Location permission denied");
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint("⚠️ ensurePermission error: $e");
      return false;
    }
  }

  /// ✅ Continuous live location stream (हर 100m पर अपडेट)
  static Stream<Position> positionStream({int distanceFilter = 100}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// ✅ Firestore में user की current location अपडेट करो
  static Future<void> updateFirestore(Position pos) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint("⚠️ updateFirestore: user not logged in");
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'lastSeen': FieldValue.serverTimestamp(),
        'online': true,
      }, SetOptions(merge: true));

      debugPrint(
          "📍 Location updated in Firestore → lat=${pos.latitude}, lng=${pos.longitude}");
    } catch (e) {
      debugPrint("❌ updateFirestore error: $e");
    }
  }

  /// ✅ Shortcut alias (same as updateFirestore)
  static Future<void> updateUserLocation(Position pos) async {
    await updateFirestore(pos);
  }

  /// ✅ Online/Offline स्टेटस update करना
  static Future<void> setOnlineStatus(bool online) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("🔵 User online status updated: $online");
    } catch (e) {
      debugPrint("setOnlineStatus error: $e");
    }
  }

  /// ✅ Manual Location Update (e.g. Refresh Button से)
  static Future<Position?> manualUpdate() async {
    try {
      final ok = await ensurePermission();
      if (!ok) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await updateFirestore(pos);
      return pos;
    } catch (e) {
      debugPrint("manualUpdate error: $e");
      return null;
    }
  }
}
