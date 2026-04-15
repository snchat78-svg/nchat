// 📁 lib/pages/profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../styles/app_styles.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  UserModel? user;
  bool isEditing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String selectedGender = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await _userService.getUserData();
    if (!mounted || data == null) return;

    setState(() {
      user = data;
      _nameController.text = data.name ?? '';
      _ageController.text = data.age?.toString() ?? '';
      selectedGender = data.gender ?? '';
    });
  }

  Future<void> _saveChanges() async {
    if (user == null) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    if (name.isEmpty || age == null || age <= 0 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ कृपया सही नाम और आयु दर्ज करें (1–120)"),
        ),
      );
      return;
    }

    final updated = user!.copyWith(
      name: name,
      age: age,
      gender: selectedGender,
    );

    await _userService.saveUserData(updated);

    if (!mounted) return;
    setState(() {
      user = updated;
      isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Profile Updated Successfully")),
    );
  }

  // 🔹 PROFILE IMAGE UPLOAD (RESTORED)
  Future<void> _uploadProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || user == null) return;

    final url = await _storageService.uploadProfileImage(
      user!.uid,
      File(picked.path),
    );

    final updated = user!.copyWith(profilePic: url);
    await _userService.saveUserData(updated);

    if (!mounted) return;
    setState(() => user = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => isEditing = !isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔹 HEADER WITH PHOTO UPLOAD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF26A69A), Color(0xFF80CBC4)],
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            user!.profilePic?.isNotEmpty == true
                                ? NetworkImage(user!.profilePic!)
                                : const AssetImage(
                                        'assets/default_avatar.png')
                                    as ImageProvider,
                      ),

                      // 📷 Upload Button
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: InkWell(
                          onTap: _uploadProfileImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user!.name ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: AppStyles.cardPadding,
              child: Column(
                children: [
                  _infoCard(
                    icon: Icons.person,
                    title: "Name",
                    child: _buildTextField(_nameController),
                  ),
                  const SizedBox(height: 12),

                  _infoCard(
                    icon: Icons.email,
                    title: "Email",
                    child: Text(user!.email),
                  ),
                  const SizedBox(height: 12),

                  _infoCard(
                    icon: Icons.cake,
                    title: "Age",
                    child: _buildAgeField(),
                  ),
                  const SizedBox(height: 12),

                  _infoCard(
                    icon: Icons.transgender,
                    title: "Gender",
                    child: isEditing
                        ? DropdownButtonFormField<String>(
                            value: selectedGender.isNotEmpty
                                ? selectedGender
                                : null,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Male', child: Text('Male')),
                              DropdownMenuItem(
                                  value: 'Female', child: Text('Female')),
                              DropdownMenuItem(
                                  value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedGender = v ?? ''),
                          )
                        : Text(selectedGender.isNotEmpty
                            ? selectedGender
                            : "Not set"),
                  ),
                  const SizedBox(height: 30),

                  if (isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save),
                        label: const Text("Save Changes"),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal),
                const SizedBox(width: 8),
                Text(title, style: AppStyles.subHeading),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAgeField() {
    return TextField(
      controller: _ageController,
      enabled: isEditing,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return TextField(
      controller: controller,
      enabled: isEditing,
    );
  }
}
