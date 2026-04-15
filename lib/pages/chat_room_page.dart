// 🔴 imports SAME
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/block_service.dart';
import '../services/chat_service.dart';
import '../styles/app_styles.dart';

class ChatRoomPage extends StatefulWidget {
  final UserModel targetUser;
  const ChatRoomPage({super.key, required this.targetUser});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final BlockService _blockService = BlockService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();

  String? currentUid;
  bool isBlocked = false;
  bool isSending = false;
  bool roomReady = false;

  // ===== Emoji =====
  bool showEmojiPicker = false;
  final List<String> emojis = ["😀","😂","😍","😮","😢","😡","👍","❤️","🔥","🙏"];

  // ===== Selection =====
  final Set<String> selectedMessageIds = {};
  bool selectionMode = false;

  bool _seenMarked = false;

  @override
  void initState() {
    super.initState();
    currentUid = _auth.currentUser?.uid;
    _checkBlockStatus();
    _initChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initChatRoom() async {
    await _chatService.ensureRoomOnly(widget.targetUser.uid);
    if (mounted) setState(() => roomReady = true);
  }

  Future<void> _checkBlockStatus() async {
    if (currentUid == null) return;
    final blocked =
        await _blockService.isBlocked(currentUid!, widget.targetUser.uid);
    if (mounted) setState(() => isBlocked = blocked);
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || isSending || !roomReady || isBlocked) return;

    _messageController.clear();
    setState(() => isSending = true);

    // 🔹 Existing message send (UNCHANGED)
    await _chatService.sendMessage(
      receiverId: widget.targetUser.uid,
      messageText: text,
    );

    if (mounted) setState(() => isSending = false);
  }

  Future<void> _pickAndSendImage() async {
    if (!roomReady || isBlocked) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    _chatService.sendMessage(
      receiverId: widget.targetUser.uid,
      imageFile: File(picked.path),
    );
  }

  Future<void> _markMessagesAsSeen(List<QueryDocumentSnapshot> docs) async {
    if (_seenMarked) return;
    _seenMarked = true;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] != currentUid && data['seenAt'] == null) {
        await doc.reference.update({
          'seenAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// 🔴 delete logic SAME
  Future<void> _deleteSelectedMessages() async {
    if (selectedMessageIds.isEmpty || currentUid == null) return;

    await _chatService.deleteMessages(
      widget.targetUser.uid,
      selectedMessageIds.toList(),
      currentUid!,
    );

    setState(() {
      selectedMessageIds.clear();
      selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: selectionMode
          ? AppBar(
              title: Text("${selectedMessageIds.length} selected"),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    selectionMode = false;
                    selectedMessageIds.clear();
                  });
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedMessages,
                ),
              ],
            )
          : AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    child: Text(
                      (widget.targetUser.name ?? "U")[0],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.targetUser.name ?? "Chat",
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatService.getMessages(widget.targetUser.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                _markMessagesAsSeen(docs);

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUid;
                    final isSelected = selectedMessageIds.contains(doc.id);

                    final List deletedFor = List.from(data['deletedFor'] ?? []);
                    if (currentUid != null &&
                        deletedFor.contains(currentUid)) {
                      return const SizedBox.shrink();
                    }

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          selectionMode = true;
                          selectedMessageIds.add(doc.id);
                        });
                      },
                      onTap: () {
                        if (!selectionMode) return;
                        setState(() {
                          isSelected
                              ? selectedMessageIds.remove(doc.id)
                              : selectedMessageIds.add(doc.id);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isSelected
                            ? Colors.blue.withOpacity(0.15)
                            : Colors.transparent,
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.teal.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isMe
                                    ? const Radius.circular(12)
                                    : const Radius.circular(0),
                                bottomRight: isMe
                                    ? const Radius.circular(0)
                                    : const Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((data['imageUrl'] ?? '').isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      data['imageUrl'],
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                if ((data['message'] ?? '').isNotEmpty)
                                  Text(
                                    data['message'],
                                    style: const TextStyle(fontSize: 15),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (showEmojiPicker)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: emojis
                    .map((e) => IconButton(
                          onPressed: () {
                            _messageController.text += e;
                          },
                          icon: Text(e, style: const TextStyle(fontSize: 22)),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    onPressed: () {
                      setState(() => showEmojiPicker = !showEmojiPicker);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Type message",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_outlined),
                    onPressed: _pickAndSendImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendTextMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
