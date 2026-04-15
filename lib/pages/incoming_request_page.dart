import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/chat_request_service.dart';
import '../services/block_service.dart';
import '../services/user_service.dart';

import '../models/chat_request_model.dart';
import '../models/user_model.dart';

import '../styles/app_styles.dart';

// Pages
import 'chat_room_page.dart';

class IncomingRequestPage extends StatefulWidget {
  const IncomingRequestPage({super.key});

  @override
  State<IncomingRequestPage> createState() => _IncomingRequestPageState();
}

class _IncomingRequestPageState extends State<IncomingRequestPage> {
  final ChatRequestService _chatRequestService = ChatRequestService();
  final BlockService _blockService = BlockService();
  final UserService _userService = UserService();

  String? currentUserId;
  bool _isLoading = false;

  List<ChatRequestModel> _requests = [];
  final Map<String, String> _senderNames = {};

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      _loadRequests();
    }
  }

  // 🔹 Load incoming requests
  Future<void> _loadRequests() async {
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final data =
          await _chatRequestService.getIncomingRequests(currentUserId!);

      _requests = data;

      for (final r in _requests) {
        final sid = r.senderId;
        if (!_senderNames.containsKey(sid)) {
          _fetchAndCacheSenderName(sid, r);
        }
      }
    } catch (e) {
      debugPrint("⚠️ loadRequests error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndCacheSenderName(
      String senderId, ChatRequestModel r) async {
    try {
      if (r.senderName != null && r.senderName!.isNotEmpty) {
        _senderNames[senderId] = r.senderName!;
      } else {
        final UserModel? user =
            await _userService.getUserById(senderId);
        if (user != null && user.name != null && user.name!.isNotEmpty) {
          _senderNames[senderId] = user.name!;
        } else {
          _senderNames[senderId] = user?.email ?? "Unknown User";
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      _senderNames[senderId] = "Unknown User";
      if (mounted) setState(() {});
    }
  }

  /// 🔥 ACCEPT / REJECT (FINAL FIXED)
  Future<void> _updateRequest(
      String senderId, String status, String senderName) async {
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    await _chatRequestService.updateRequestStatus(
      senderId,
      currentUserId!,
      status,
      senderName: senderName,
    );

    if (status == 'rejected') {
      await _blockService.blockUser(currentUserId!, senderId);
    }

    _requests.removeWhere((r) => r.senderId == senderId);

    if (mounted) setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'accepted'
              ? "✅ Chat Request Accepted"
              : "🚫 Request Rejected",
        ),
      ),
    );

    /// ✅ FINAL & ONLY FIX (NO EXTRA CHANGE)
    if (status == 'accepted' && mounted) {
      final UserModel? senderUser =
          await _userService.getUserById(senderId);

      if (senderUser != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              targetUser: senderUser,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Incoming Requests"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(
                  child: Text(
                    "कोई नया चैट रिक्वेस्ट नहीं है।",
                    style: AppStyles.subHeading,
                  ),
                )
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final displayName =
                        _senderNames[request.senderId] ??
                            request.senderName ??
                            request.senderEmail ??
                            "Unknown User";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(displayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () => _updateRequest(
                                  request.senderId,
                                  'accepted',
                                  displayName),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel,
                                  color: Colors.red),
                              onPressed: () => _updateRequest(
                                  request.senderId,
                                  'rejected',
                                  displayName),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
