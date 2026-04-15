import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'storage_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storage = StorageService();

  // ================= ROOM ID =================
  String _getRoomId(String otherUid) {
    final myUid = _auth.currentUser!.uid;
    return myUid.compareTo(otherUid) < 0
        ? "${myUid}_$otherUid"
        : "${otherUid}_$myUid";
  }

  // ================= CREATE ROOM =================
  Future<void> ensureRoomOnly(String otherUid) async {
    final roomId = _getRoomId(otherUid);

    final roomRef = _firestore.collection("chatRooms").doc(roomId);
    final snap = await roomRef.get();

    if (!snap.exists) {
      await roomRef.set({
        "participants": [_auth.currentUser!.uid, otherUid],
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  // ================= SEND MESSAGE (🔴 FCM FIX ADDED HERE) =================
  Future<bool> sendMessage({
    required String receiverId,
    String? messageText,
    File? imageFile,
  }) async {
    try {
      final roomId = _getRoomId(receiverId);

      String imageUrl = "";

      if (imageFile != null) {
        imageUrl = await _storage.uploadChatImage(roomId, imageFile);
      }

      // 🔹 1. Save message to Firestore
      await _firestore
          .collection("chatRooms")
          .doc(roomId)
          .collection("messages")
          .add({
        "senderId": _auth.currentUser!.uid,
        "receiverId": receiverId,
        "message": messageText ?? "",
        "imageUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "seenAt": null,
        "deletedFor": [],
      });

      // 🔹 2. Get receiver FCM token
      final userSnap =
          await _firestore.collection("users").doc(receiverId).get();

      if (!userSnap.exists) return true;

      final data = userSnap.data() as Map<String, dynamic>;
      final String? fcmToken = data['fcmToken'];

      if (fcmToken == null || fcmToken.isEmpty) return true;

      // 🔹 3. Send Push Notification via FCM HTTP API
      await _sendPushNotification(
        token: fcmToken,
        title: "New Message",
        body: imageUrl.isNotEmpty ? "📷 Photo" : (messageText ?? ""),
      );

      return true;
    } catch (e) {
      print("SEND MESSAGE ERROR: $e");
      return false;
    }
  }

  // ================= PUSH NOTIFICATION FUNCTION =================
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    const String serverKey = "YOUR_FCM_SERVER_KEY_HERE"; // 🔴 यहां अपना Firebase Server Key डालना होगा

    final url = Uri.parse("https://fcm.googleapis.com/fcm/send");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "key=$serverKey",
      },
      body: jsonEncode({
        "to": token,
        "notification": {
          "title": title,
          "body": body,
          "sound": "default",
        },
        "data": {
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
          "type": "chat",
        }
      }),
    );

    print("FCM RESPONSE: ${response.body}");
  }

  // ================= GET MESSAGES =================
  Stream<QuerySnapshot> getMessages(String otherUid) {
    final roomId = _getRoomId(otherUid);

    return _firestore
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  // ================= UNREAD COUNT =================
  Stream<int> getUnreadCount(String otherUid) {
    final roomId = _getRoomId(otherUid);

    return _firestore
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .where("receiverId", isEqualTo: _auth.currentUser!.uid)
        .where("seenAt", isEqualTo: null)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ================= MARK AS SEEN =================
  Future<void> markMessagesAsSeen(String otherUid) async {
    final roomId = _getRoomId(otherUid);

    final unread = await _firestore
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .where("receiverId", isEqualTo: _auth.currentUser!.uid)
        .where("seenAt", isEqualTo: null)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (var doc in unread.docs) {
      batch.update(doc.reference, {
        "seenAt": FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ================= LAST MESSAGE PREVIEW =================
  Stream<String> getLastMessagePreview(String me, String other) {
    final roomId = _getRoomId(other);

    return _firestore
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("createdAt", descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return "";
          final data = snap.docs.first.data();
          if (data['imageUrl'] != null &&
              (data['imageUrl'] as String).isNotEmpty) {
            return "📷 Photo";
          }
          return data['message'] ?? "";
        });
  }

  // ================= DELETE MESSAGE (UNCHANGED) =================
  Future<void> deleteMessages(
    String otherUid,
    List<String> messageIds,
    String currentUid,
  ) async {
    final roomId = _getRoomId(otherUid);

    final batch = _firestore.batch();

    for (var msgId in messageIds) {
      final msgRef = _firestore
          .collection("chatRooms")
          .doc(roomId)
          .collection("messages")
          .doc(msgId);

      final snap = await msgRef.get();
      if (!snap.exists) continue;

      final data = snap.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;

      List deletedFor = List.from(data['deletedFor'] ?? []);

      if (senderId == currentUid) {
        if (!deletedFor.contains(currentUid)) {
          deletedFor.add(currentUid);
        }
        if (!deletedFor.contains(otherUid)) {
          deletedFor.add(otherUid);
        }
      } else {
        if (!deletedFor.contains(currentUid)) {
          deletedFor.add(currentUid);
        }
      }

      batch.update(msgRef, {
        "deletedFor": deletedFor,
      });
    }

    await batch.commit();
  }
}
