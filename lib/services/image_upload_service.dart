// lib/services/image_upload_service.dart

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<String?> pickAndUploadImage(String folderName) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile == null) return null;

  final file = File(pickedFile.path);
  final fileName = DateTime.now().millisecondsSinceEpoch.toString();
  final storageRef = FirebaseStorage.instance.ref().child('$folderName/$fileName.jpg');

  UploadTask uploadTask = storageRef.putFile(file);
  TaskSnapshot snapshot = await uploadTask;

  String downloadUrl = await snapshot.ref.getDownloadURL();
  return downloadUrl;
}
