import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/block_service.dart';
import '../styles/app_styles.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final BlockService _blockService = BlockService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  /// 🔹 ब्लॉक किए गए सभी यूज़र्स को लोड करो (रियल-टाइम)
  Future<void> _loadBlockedUsers() async {
    try {
      setState(() => _isLoading = true);

      _firestore
          .collection('blocked_users')
          .doc(currentUid)
          .collection('list')
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.docs.isEmpty) {
          setState(() {
            _blockedUsers = [];
            _isLoading = false;
          });
          return;
        }

        final blockedIds = snapshot.docs.map((doc) => doc.id).toList();

        final usersSnap = await _firestore
            .collection('users')
            .where('uid', whereIn: blockedIds)
            .get();

        setState(() {
          _blockedUsers = usersSnap.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
          _isLoading = false;
        });
      });
    } catch (e) {
      debugPrint('❌ Error fetching blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 🔹 यूज़र को अनब्लॉक करो और वापस ChatUsersPage जाओ
  Future<void> _unblockUser(String targetUid) async {
    try {
      await _blockService.unblockUser(currentUid, targetUid);

      setState(() {
        _blockedUsers.removeWhere((user) => user.uid == targetUid);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ User unblocked successfully"),
          behavior: SnackBarBehavior.floating,
        ),
      );

      /// ✅ unblock के बाद वापस
      Navigator.pop(context);

    } catch (e) {
      debugPrint('❌ Error unblocking user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Failed to unblock: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBlockedUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? const Center(
                  child: Text(
                    'कोई ब्लॉक किया हुआ यूज़र नहीं है।',
                    style: AppStyles.subHeading,
                  ),
                )
              : ListView.separated(
                  padding: AppStyles.cardPadding,
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, __) => AppStyles.divider,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppStyles.cardRadius),
                      ),
                      child: ListTile(
                        contentPadding: AppStyles.cardPadding,
                        leading: CircleAvatar(
                          backgroundImage: (user.profilePic != null &&
                                  user.profilePic!.isNotEmpty)
                              ? NetworkImage(user.profilePic!)
                              : null,
                          child: (user.profilePic == null ||
                                  user.profilePic!.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          user.name ?? 'Unnamed User',
                          style: AppStyles.heading,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.lock_open,
                            color: Colors.green,
                          ),
                          tooltip: "Unblock User",
                          onPressed: () => _unblockUser(user.uid),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
