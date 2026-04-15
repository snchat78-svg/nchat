// 📁 lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String userType; // हमेशा 'person' रहेगा
  final String? name;
  final int? age;
  final String? gender;
  final String? profilePic;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen; // 🔹 Last seen time
  final bool? online; // 🔹 actual stored field

  UserModel({
    required this.uid,
    required this.email,
    this.userType = 'person',
    this.name,
    this.age,
    this.gender,
    this.profilePic,
    this.latitude,
    this.longitude,
    this.lastSeen,
    this.online,
  });

  /// ✅ FIX: alias getter (ChatRoomPage uses isOnline)
  bool? get isOnline => online;

  /// 🔁 Firestore में सेव करने के लिए
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'userType': userType,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (profilePic != null) 'profilePic': profilePic,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
      if (online != null) 'online': online,
    };
    return map;
  }

  /// 🔁 Firestore से डेटा लेने के लिए
  factory UserModel.fromMap(Map<String, dynamic> map) {
    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime? _asDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return UserModel(
      uid: (map['uid'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      userType: (map['userType'] ?? 'person').toString(),
      name: map['name']?.toString(),
      age: _asInt(map['age']),
      gender: map['gender']?.toString(),
      profilePic: map['profilePic']?.toString(),
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      lastSeen: _asDate(map['lastSeen']),
      online: map['online'] == true,
    );
  }

  /// 🧱 CopyWith
  UserModel copyWith({
    String? uid,
    String? email,
    String? userType,
    String? name,
    int? age,
    String? gender,
    String? profilePic,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    bool? online,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      profilePic: profilePic ?? this.profilePic,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      online: online ?? this.online,
    );
  }
}
