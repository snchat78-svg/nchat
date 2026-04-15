import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/block_service.dart';
import '../styles/app_styles.dart';
import 'chat_room_page.dart';
import 'user_detail_page.dart';


class ChatUsersPage extends StatefulWidget {
  const ChatUsersPage({super.key});

  @override
  State<ChatUsersPage> createState() => _ChatUsersPageState();
}

class _ChatUsersPageState extends State<ChatUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final BlockService _blockService = BlockService();

  String? currentUid;

  @override
  void initState() {
    super.initState();
    currentUid = _auth.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text("⚠️ User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Users"),
        elevation: 2,
      ),
      body: StreamBuilder<List<String>>(
        stream: _blockService.getBlockedUserIdsStream(currentUid!),
        builder: (context, blockSnap) {
          if (blockSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (blockSnap.hasError) {
            return const Center(child: Text("❌ Block data error"));
          }

          final blockedIds = blockSnap.data ?? [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('chatRequests')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("❌ Chat request error"));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              final Set<String> userIds = {};

              for (var doc in docs) {
                final data = doc.data();
                final sender = data['senderId'];
                final receiver = data['receiverId'];

                if (sender == currentUid && receiver != null) {
                  userIds.add(receiver);
                } else if (receiver == currentUid && sender != null) {
                  userIds.add(sender);
                }
              }

              /// ✅ blocked users remove
              userIds.removeWhere((id) => blockedIds.contains(id));

              if (userIds.isEmpty) {
                return const Center(
                  child: Text("⚠️ अभी तक कोई चैट यूज़र नहीं मिला"),
                );
              }

              return FutureBuilder<List<UserModel>>(
                future: _userService.getUsersByIds(userIds.toList()),
                builder: (context, userSnap) {
                  if (userSnap.hasError) {
                    return const Center(child: Text("❌ User load error"));
                  }

                  if (!userSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = userSnap.data ?? [];

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final name =
                          user.name?.isNotEmpty == true ? user.name! : "Unknown";

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),

                            // 🔹 Premium Avatar
                            leading: GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailPage(
          targetUser: user,
          fromChatPage: true, // 👈 IMPORTANT
        ),
      ),
    );
  },
  child: Stack(
    children: [
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.teal, Colors.green],
          ),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          backgroundImage:
              (user.profilePic != null &&
                      user.profilePic!.isNotEmpty)
                  ? NetworkImage(user.profilePic!)
                  : null,
          child: (user.profilePic == null ||
                  user.profilePic!.isEmpty)
              ? const Icon(Icons.person,
                  color: Colors.grey)
              : null,
        ),
      ),

      // 🟢 Online Dot
      if (user.online == true)
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white, width: 2),
            ),
          ),
        ),
    ],
  ),
),


                            // 🔹 Title + Subtitle
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),

                                // 🔹 Last Message Preview
                                StreamBuilder<String>(
                                  stream: _chatService.getLastMessagePreview(
                                    currentUid!,
                                    user.uid,
                                  ),
                                  builder: (context, snap) {
                                    if (!snap.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      snap.data!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    );
                                  },
                                ),

                                // 🔹 Last Seen
                                if (user.online != true &&
                                    user.lastSeen != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      "Last seen: ${user.lastSeen}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // 🔹 Unread Badge (WhatsApp style)
                            trailing: StreamBuilder<int>(
                              stream:
                                  _chatService.getUnreadCount(user.uid),
                              builder: (context, snap) {
                                if (!snap.hasData || snap.data == 0) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    snap.data.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),

                            onLongPress: () async {
                              await _blockService.blockUser(
                                  currentUid!, user.uid);
                            },

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChatRoomPage(targetUser: user),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
