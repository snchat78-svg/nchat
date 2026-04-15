// 📁 Path: lib/services/chat_request_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_request_model.dart';
import 'push_notification_service.dart';

class ChatRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// --------------------------------------------------------
  /// A: SEND REQUEST using full model
  /// --------------------------------------------------------
  Future<void> sendRequest(ChatRequestModel request) async {
    final docId = '${request.senderId}_${request.receiverId}';

    await _firestore.collection('chatRequests').doc(docId).set(request.toMap());

    await PushNotificationService().sendPushMessage(
      request.receiverId,
      "New Chat Request",
      "You have a new chat request from ${request.senderName ?? request.senderId}",
      data: {
        "screen": "incomingRequests",
        "senderId": request.senderId
      },
    );
  }

  /// --------------------------------------------------------
  /// B: SEND REQUEST using only IDs
  /// --------------------------------------------------------
  Future<bool> sendRequestByIds(
      String senderId,
      String receiverId, {
        String? senderName,
        String? senderEmail,
      }) async {
    try {
      final docId = '${senderId}_$receiverId';

      final request = ChatRequestModel(
        senderId: senderId,
        receiverId: receiverId,
        status: "pending",
        timestamp: DateTime.now(),
        senderName: senderName ?? "Unknown User",
        senderEmail: senderEmail,
      );

      await _firestore.collection('chatRequests').doc(docId).set(request.toMap());

      await PushNotificationService().sendPushMessage(
        receiverId,
        "New Chat Request",
        "You have a new chat request from ${senderName ?? 'a user'}",
        data: {
          "screen": "incomingRequests",
          "senderId": senderId
        },
      );

      return true;
    } catch (e) {
      print("❌ sendRequestByIds failed: $e");
      return false;
    }
  }

  /// --------------------------------------------------------
  /// C: GET Incoming Pending Requests
  /// --------------------------------------------------------
  Future<List<ChatRequestModel>> getIncomingRequests(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRequests')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => ChatRequestModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print("⚠️ getIncomingRequests error: $e");
      return [];
    }
  }

  /// --------------------------------------------------------
  /// D: REQUEST STATUS UPDATE (accept / reject)
  /// --------------------------------------------------------
  Future<void> updateRequestStatus(
      String senderId,
      String receiverId,
      String newStatus, {
        String? senderName,
        String? senderEmail,
      }) async {
    try {
      final docId = '${senderId}_$receiverId';
      final docRef = _firestore.collection('chatRequests').doc(docId);

      final data = {
        "status": newStatus,
        "timestamp": FieldValue.serverTimestamp(),
      };

      if (senderName != null) data["senderName"] = senderName;
      if (senderEmail != null) data["senderEmail"] = senderEmail;

      await docRef.set(data, SetOptions(merge: true));

      // ⭐ FIX: अगर request accept हो जाए → reverse entry बना दो
      if (newStatus == "accepted") {
        final reverseId = '${receiverId}_$senderId';

        await _firestore.collection('chatRequests').doc(reverseId).set(
          {
            "senderId": receiverId,
            "receiverId": senderId,
            "status": "accepted",
            "timestamp": FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 🔔 Notify sender
      await PushNotificationService().sendPushMessage(
        senderId,
        "Chat Request Update",
        (newStatus == "accepted")
            ? "Your chat request has been accepted!"
            : "Your chat request was rejected.",
        data: {
          "screen": "chatUsers",
          "receiverId": receiverId
        },
      );
    } catch (e) {
      print("❌ updateRequestStatus failed: $e");
    }
  }

  /// --------------------------------------------------------
  /// E: CHECK PERMISSION (Both Directions)
  /// --------------------------------------------------------
  Future<bool> isChatAllowed(String uid1, String uid2) async {
    try {
      final doc1 =
      await _firestore.collection('chatRequests').doc('${uid1}_$uid2').get();
      final doc2 =
      await _firestore.collection('chatRequests').doc('${uid2}_$uid1').get();

      final a = doc1.exists && doc1.data()?['status'] == 'accepted';
      final b = doc2.exists && doc2.data()?['status'] == 'accepted';

      return a || b;
    } catch (e) {
      print("⚠️ isChatAllowed error: $e");
      return false;
    }
  }

  /// --------------------------------------------------------
  /// F: ALL ACCEPTED USERS (Chat List)
  /// --------------------------------------------------------
  Future<List<String>> getAcceptedUserIds(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRequests')
          .where('status', isEqualTo: 'accepted')
          .get();

      final List<String> accepted = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final s = data['senderId'];
        final r = data['receiverId'];

        if (s == currentUserId && r != null) accepted.add(r);
        if (r == currentUserId && s != null) accepted.add(s);
      }

      return accepted;
    } catch (e) {
      print("⚠️ getAcceptedUserIds error: $e");
      return [];
    }
  }

  /// --------------------------------------------------------
  /// G: GET SENT REQUESTS (receiverIds)
  /// --------------------------------------------------------
  Future<List<String>> getSentRequests(String senderId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRequests')
          .where('senderId', isEqualTo: senderId)
          .get();

      final List<String> receivers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? receiver = data['receiverId'] as String?;
        if (receiver != null) receivers.add(receiver);
      }
      return receivers;
    } catch (e) {
      print("⚠️ getSentRequests error: $e");
      return [];
    }
  }
}
