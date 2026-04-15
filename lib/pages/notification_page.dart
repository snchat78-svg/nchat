import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../styles/app_styles.dart'; // ✅ Add if you use custom styles

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('uid', isEqualTo: currentUid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ Error मैसेज हटाया गया → अब सिर्फ खाली data पर मैसेज दिखेगा
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "📭 अभी आपके पास कोई नोटिफिकेशन नहीं है",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final body = data['body'] ?? '';
              final time = (data['timestamp'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                ),
                child: ListTile(
                  contentPadding: AppStyles.cardPadding,
                  leading: const Icon(Icons.notifications_active, color: Colors.teal),
                  title: Text(title, style: AppStyles.heading),
                  subtitle: Text(body, style: AppStyles.subHeading),
                  trailing: Text(
                    time != null
                        ? "${time.hour}:${time.minute.toString().padLeft(2, '0')}"
                        : "",
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    final scaffoldContext = context;

                    FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(doc.id)
                        .delete()
                        .then((_) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(content: Text("Notification Removed")),
                      );
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
