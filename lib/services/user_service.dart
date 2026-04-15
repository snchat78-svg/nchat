import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
            user.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('saveUserData error: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docUser = await _firestore.collection('users').doc(user.uid).get();
      if (docUser.exists && docUser.data() != null) {
        final map = Map<String, dynamic>.from(docUser.data()!);
        map['uid'] = map['uid'] ?? docUser.id;
        map['userType'] = 'person';
        return UserModel.fromMap(map);
      }
    } catch (e) {
      debugPrint('getUserData error: $e');
    }
    return null;
  }

  /// ✅ LOCATION + LAST SEEN
  Future<void> updateLocation(double lat, double lng) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'latitude': lat,
        'longitude': lng,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateLocation error: $e');
    }
  }

  // 🔥 ONLINE / OFFLINE (FIXED FIELD NAME)
  Future<void> setOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'online': isOnline,
        if (!isOnline) 'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setOnlineStatus error: $e');
    }
  }

  // 🔥 MAIN.DART COMPATIBLE METHOD (NEW)
  Future<void> updateUserPresence({
    required String uid,
    required bool online,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'online': online,
        if (!online) 'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateUserPresence error: $e');
    }
  }

  Future<List<UserModel>> getNearbyPersons(
    double myLat,
    double myLng, {
    double radiusInKm = 5.0,
  }) async {
    final current = _auth.currentUser;
    if (current == null) return [];

    try {
      final snapshot = await _firestore.collection('users').get();
      final List<UserModel> nearby = [];

      for (var doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['uid'] = data['uid'] ?? doc.id;
        final user = UserModel.fromMap(data);

        if (user.uid == current.uid ||
            user.latitude == null ||
            user.longitude == null) continue;

        const p = 0.017453292519943295;
        final a = 0.5 -
            math.cos((user.latitude! - myLat) * p) / 2 +
            math.cos(myLat * p) *
                math.cos(user.latitude! * p) *
                (1 - math.cos((user.longitude! - myLng) * p)) / 2;
        final km = 12742 * math.asin(math.sqrt(a));

        if (km <= radiusInKm) nearby.add(user);
      }

      return nearby;
    } catch (e) {
      debugPrint("getNearbyPersons error: $e");
      return [];
    }
  }

  Future<List<UserModel>> getNearbyUsers(
    double myLat,
    double myLng, {
    double radiusInKm = 5.0,
  }) async {
    return getNearbyPersons(myLat, myLng, radiusInKm: radiusInKm);
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final docUser = await _firestore.collection('users').doc(uid).get();
      if (docUser.exists && docUser.data() != null) {
        final map = Map<String, dynamic>.from(docUser.data()!);
        map['uid'] = map['uid'] ?? docUser.id;
        map['userType'] = 'person';
        return UserModel.fromMap(map);
      }
    } catch (e) {
      debugPrint('getUserById error: $e');
    }
    return null;
  }

  /// 🔥 FIXED VERSION (NO CHANGE)
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final futures =
          userIds.map((uid) => _firestore.collection('users').doc(uid).get());

      final snaps = await Future.wait(futures);

      final List<UserModel> result = [];
      for (final doc in snaps) {
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['uid'] = data['uid'] ?? doc.id;
          data['userType'] = 'person';
          result.add(UserModel.fromMap(data));
        }
      }

      return result;
    } catch (e) {
      debugPrint('getUsersByIds error: $e');
      return [];
    }
  }
}
