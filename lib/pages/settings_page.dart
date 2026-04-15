// 📁 lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../pages/profile_page.dart';
import '../pages/about_page.dart';
import '../styles/app_styles.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final UserService _userService = UserService();
  UserModel? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = await _userService.getUserData();
    setState(() {
      currentUser = user;
      isLoading = false;
    });
  }

  void _shareApp() {
    const appLink = 'https://play.google.com/store/apps/details?id=com.nchat.app';
    Share.share(
      '🚀 Download Nchat App and chat with nearby people!\n\n$appLink',
      subject: 'Nchat - Nearby Chat App',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"), // 🔹 अब English में
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔹 PROFILE CARD (Premium Header Section)
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: CircleAvatar(
                radius: 26,
                backgroundImage:
                    currentUser?.profilePic?.isNotEmpty == true
                        ? NetworkImage(currentUser!.profilePic!)
                        : null,
                child: currentUser?.profilePic?.isEmpty != false
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
              title: const Text(
                "My Profile",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                "Personal Account",
                style: TextStyle(color: Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // 🔹 ACCOUNT SECTION TITLE
          Text(
            "ACCOUNT",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // 🔹 ACCOUNT CARD
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: "My Profile",
                  subtitle: "View & edit your profile",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 🔹 APP INFO SECTION TITLE
          Text(
            "APP INFO",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // 🔹 APP INFO CARD
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.info_outline,
                  title: "About Nchat",
                  subtitle: "Version 1.0.0",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.share,
                  title: "Share App",
                  subtitle: "Invite your friends",
                  onTap: _shareApp,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 🔹 FOOTER BRANDING
          Column(
            children: const [
              Divider(),
              SizedBox(height: 12),
              Text(
                "© 2025 Nchat",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                "All Rights Reserved",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 Reusable Premium ListTile
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.grey))
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
