import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 किसी यूज़र को ब्लॉक करो
  Future<void> blockUser(String currentUid, String targetUid) async {
    await _firestore
        .collection('blocked_users')
        .doc(currentUid)
        .collection('list')
        .doc(targetUid)
        .set({
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔹 किसी यूज़र को अनब्लॉक करो
  Future<void> unblockUser(String currentUid, String targetUid) async {
    await _firestore
        .collection('blocked_users')
        .doc(currentUid)
        .collection('list')
        .doc(targetUid)
        .delete();
  }

  /// 🔹 चेक करो कि यूज़र ब्लॉक किया गया है या नहीं
  Future<bool> isBlocked(String currentUid, String targetUid) async {
    final doc = await _firestore
        .collection('blocked_users')
        .doc(currentUid)
        .collection('list')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  /// 🔹 सभी ब्लॉक किए गए यूज़र्स की UID (Future)
  Future<List<String>> getBlockedUserIds(String currentUid) async {
    final snap = await _firestore
        .collection('blocked_users')
        .doc(currentUid)
        .collection('list')
        .get();

    return snap.docs.map((doc) => doc.id).toList();
  }

  /// 🔹 सभी ब्लॉक किए गए यूज़र्स की UID (Stream) ✅ REQUIRED
  Stream<List<String>> getBlockedUserIdsStream(String currentUid) {
    return _firestore
        .collection('blocked_users')
        .doc(currentUid)
        .collection('list')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  /// 🔹 वर्तमान लॉगिन यूज़र की UID
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// 🔹 Toggle block / unblock
  Future<void> toggleBlock(String targetUid) async {
    final uid = currentUid;
    if (uid == null) return;

    final alreadyBlocked = await isBlocked(uid, targetUid);
    if (alreadyBlocked) {
      await unblockUser(uid, targetUid);
    } else {
      await blockUser(uid, targetUid);
    }
  }
}
