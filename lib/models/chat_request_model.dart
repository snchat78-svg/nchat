// 📁 lib/models/chat_request_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRequestModel {
  final String senderId;
  final String receiverId;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime timestamp;

  final String? senderName;
  final String? senderEmail;

  ChatRequestModel({
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.timestamp,
    this.senderName,
    this.senderEmail,
  });

  // 🔹 Convert to Map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status,
      // ⬇ Always save as Firestore Timestamp
      'timestamp': Timestamp.fromDate(timestamp),

      if (senderName != null) 'senderName': senderName,
      if (senderEmail != null) 'senderEmail': senderEmail,
    };
  }

  // 🔹 Create from Map (from Firestore)
  factory ChatRequestModel.fromMap(Map<String, dynamic> map) {
    final ts = map['timestamp'];

    DateTime parsedTime;

    if (ts is Timestamp) {
      parsedTime = ts.toDate();
    } else if (ts is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      parsedTime = DateTime.tryParse(ts.toString()) ?? DateTime.now();
    }

    return ChatRequestModel(
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: parsedTime,
      senderName: map['senderName'],
      senderEmail: map['senderEmail'],
    );
  }
}
