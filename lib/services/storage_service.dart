// 📁 lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// 🧍‍♂️ यूज़र प्रोफाइल इमेज अपलोड करो और डाउनलोड URL वापस दो
  Future<String> uploadProfileImage(String uid, File file) async {
    try {
      final fileId = _uuid.v4();
      final ref = _storage.ref().child("profile_pics/$uid/$fileId.jpg");

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      return url;
    } on FirebaseException catch (e) {
      throw Exception("Firebase Error: ${e.message}");
    } on SocketException {
      throw Exception("Internet connection required for upload");
    } catch (e) {
      throw Exception("Image Upload Failed: $e");
    }
  }

  /// 💬 चैट इमेज अपलोड करो और डाउनलोड URL वापस दो
  Future<String> uploadChatImage(String roomId, File file) async {
    try {
      final fileId = _uuid.v4();
      final ref = _storage.ref().child("chat_images/$roomId/$fileId.jpg");

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      return url;
    } on FirebaseException catch (e) {
      throw Exception("Firebase Error: ${e.message}");
    } on SocketException {
      throw Exception("Internet connection required for upload");
    } catch (e) {
      throw Exception("Chat Image Upload Failed: $e");
    }
  }
}
