// 📁 lib/pages/user_detail_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_model.dart';
import '../models/chat_request_model.dart';
import '../services/chat_request_service.dart';
import '../services/block_service.dart';
import '../styles/app_styles.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class UserDetailPage extends StatefulWidget {
  final UserModel targetUser;
  final bool fromChatPage; // 👈 NEW

  const UserDetailPage({
    super.key,
    required this.targetUser,
    this.fromChatPage = false, // default Nearby
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final _auth = FirebaseAuth.instance;
  final _chatRequestService = ChatRequestService();
  final _blockService = BlockService();

  late String currentUid;
  bool isAllowed = false; // untouched
  bool isBlocked = false;
  bool _sending = false;

  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    currentUid = _auth.currentUser?.uid ?? '';
    _calculateDistance();
  }

  Future<void> _sendRequest() async {
    if (_sending) return;

    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ User not logged in")),
      );
      return;
    }

    if (currentUid == widget.targetUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't send request to yourself")),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final success = await _chatRequestService.sendRequestByIds(
        currentUid,
        widget.targetUser.uid,
        senderName:
            FirebaseAuth.instance.currentUser?.displayName ?? "Unknown User",
        senderEmail:
            FirebaseAuth.instance.currentUser?.email ?? "",
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Request Sent")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to send request")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error sending request")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _calculateDistance() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      if (!snap.exists) return;

      final myLat = snap['latitude'];
      final myLng = snap['longitude'];

      final u = widget.targetUser;
      if (u.latitude == null || u.longitude == null) return;

      final meters = Geolocator.distanceBetween(
        myLat,
        myLng,
        u.latitude!,
        u.longitude!,
      );

      if (!mounted) return;
      setState(() => _distanceKm = meters / 1000);
    } catch (_) {}
  }
    Future<void> _openSocialLink(String url) async {
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Link open नहीं हो सका"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Link open नहीं हो सका"),
        ),
      );
    }
  }

  Future<void> _toggleBlockStatus() async {
    if (isBlocked) {
      await _blockService.unblockUser(currentUid, widget.targetUser.uid);
    } else {
      await _blockService.blockUser(currentUid, widget.targetUser.uid);
    }

    if (!mounted) return;
    setState(() => isBlocked = !isBlocked);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            isBlocked ? '🚫 User Blocked' : '🔓 User Unblocked'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.targetUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(u.name ?? "User Detail"),
      ),
      body: SingleChildScrollView(
        padding: AppStyles.cardPadding,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Colors.black26,
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        u.profilePic?.isNotEmpty == true
                            ? NetworkImage(u.profilePic!)
                            : null,
                    child: (u.profilePic == null ||
                            u.profilePic!.isEmpty)
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                ),
                if (u.online == true)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      height: 16,
                      width: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              u.name ?? "Unknown User",
              style:
                  AppStyles.heading.copyWith(fontSize: 22),
            ),

            const SizedBox(height: 6),

            if (_distanceKm != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  "📍 ${_distanceKm!.toStringAsFixed(2)} km away",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.teal),
                ),
              ),

            const SizedBox(height: 12),

            if (u.gender != null)
              Text("Gender: ${u.gender}",
                  style: AppStyles.subHeading),
            if (u.age != null)
              Text("Age: ${u.age}",
                  style: AppStyles.subHeading),

            const SizedBox(height: 30),
                        // 🔗 SOCIAL LINKS
            if ((u.instagram?.trim().isNotEmpty == true &&
                    u.instagramVisible) ||
                (u.facebook?.trim().isNotEmpty == true &&
                    u.facebookVisible) ||
                (u.youtube?.trim().isNotEmpty == true &&
                    u.youtubeVisible))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.share,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Social Links",
                            style: AppStyles.subHeading,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 📸 INSTAGRAM
                      if (u.instagram?.trim().isNotEmpty == true &&
                          u.instagramVisible)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.camera_alt,
                            color: Colors.pink,
                          ),
                          title: const Text("Instagram"),
                          subtitle: Text(
                            "@${u.instagram!.trim().replaceFirst('@', '')}",
                          ),
                          trailing: const Icon(
                            Icons.open_in_new,
                            size: 20,
                          ),
                          onTap: () {
                            final username = u.instagram!
                                .trim()
                                .replaceFirst('@', '');

                            _openSocialLink(
                              'https://www.instagram.com/$username/',
                            );
                          },
                        ),

                      // 📘 FACEBOOK
                      if (u.facebook?.trim().isNotEmpty == true &&
                          u.facebookVisible)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.facebook,
                            color: Colors.blue,
                          ),
                          title: const Text("Facebook"),
                          subtitle: const Text(
                            "Open Facebook Profile",
                          ),
                          trailing: const Icon(
                            Icons.open_in_new,
                            size: 20,
                          ),
                          onTap: () {
                            _openSocialLink(
                              u.facebook!.trim(),
                            );
                          },
                        ),

                      // ▶️ YOUTUBE
                      if (u.youtube?.trim().isNotEmpty == true &&
                          u.youtubeVisible)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.red,
                          ),
                          title: const Text("YouTube"),
                          subtitle: const Text(
                            "Open YouTube Channel",
                          ),
                          trailing: const Icon(
                            Icons.open_in_new,
                            size: 20,
                          ),
                          onTap: () {
                            _openSocialLink(
                              u.youtube!.trim(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            AnimatedScale(
              scale: 1,
              duration:
                  const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                icon: Icon(isBlocked
                    ? Icons.lock_open
                    : Icons.block),
                label: Text(isBlocked
                    ? "Unblock User"
                    : "Block User"),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: isBlocked
                      ? Colors.orange
                      : Colors.redAccent,
                ),
                onPressed: _toggleBlockStatus,
              ),
            ),

            const SizedBox(height: 16),

            if (!isBlocked)
              AnimatedScale(
                scale: 1,
                duration:
                    const Duration(milliseconds: 200),
                child: widget.fromChatPage
                    ? ElevatedButton.icon(
                        icon:
                            const Icon(Icons.chat),
                        label:
                            const Text("Start Chat"),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/chatRoom',
                            arguments: u,
                          );
                        },
                      )
                    : ElevatedButton.icon(
                        icon:
                            const Icon(Icons.send),
                        label: Text(_sending
                            ? "Sending..."
                            : "Send Chat Request"),
                        onPressed: _sending
                            ? null
                            : _sendRequest,
                      ),
              ),

            const SizedBox(height: 12),

            if (u.lastSeen != null)
  Text(
    "🕒 Last seen: ${DateFormat('dd MMM yyyy, hh:mm a').format(u.lastSeen!.toLocal())}",
    style: AppStyles.subHeading.copyWith(
      fontSize: 13,
    ),
  ),
          ],
        ),
      ),
    );
  }
}
