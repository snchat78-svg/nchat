// 📁 lib/pages/register_person_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';

class RegisterPersonPage extends StatefulWidget {
  const RegisterPersonPage({super.key});

  @override
  State<RegisterPersonPage> createState() => _RegisterPersonPageState();
}

class _RegisterPersonPageState extends State<RegisterPersonPage> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  final StorageService _storageService = StorageService();
  File? selectedImage;
  String? profilePicUrl;
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ✅ लोकेशन लेने का फ़ंक्शन
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Location permission denied")),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => currentPosition = pos);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  // ✅ Profile Image Upload
  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final file = File(picked.path);
      final url = await _storageService.uploadProfileImage(uid, file);

      if (!mounted) return;
      setState(() {
        selectedImage = file;
        profilePicUrl = url;
      });
    }
  }

  // ✅ Person Details Save
  Future<void> savePersonDetails() async {
    final name = nameController.text.trim();
    final ageText = ageController.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final age = int.tryParse(ageText);

    if (name.isEmpty || age == null || currentPosition == null || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ कृपया सभी जानकारी और लोकेशन दर्ज करें')),
      );
      return;
    }

    if (age <= 0 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ आयु केवल 1 से 120 के बीच होनी चाहिए')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'userType': 'person',
      'name': name,
      'age': age,
      'profilePic': profilePicUrl ?? '',
      'latitude': currentPosition!.latitude,
      'longitude': currentPosition!.longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Person')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: pickAndUploadImage,
              icon: const Icon(Icons.image),
              label: const Text("Upload Profile Picture"),
            ),

            if (selectedImage != null) ...[
              const SizedBox(height: 8),
              const Text("✅ Image Uploaded", style: TextStyle(color: Colors.green)),
              const SizedBox(height: 8),
              Image.file(selectedImage!, height: 100),
            ],

            const SizedBox(height: 20),

            currentPosition != null
    ? Text(
        "📍 Location Ready (${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)})",
        style: const TextStyle(color: Colors.green),
      )
    : Column(
        children: [
          const Text(
            "⚠️ Location service disabled",
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.location_on),
            label: const Text("Enable Location"),
            onPressed: () async {
              await Geolocator.openLocationSettings();
              _getCurrentLocation();
            },
          ),
        ],
      ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: savePersonDetails,
              icon: const Icon(Icons.check),
              label: const Text('Register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
