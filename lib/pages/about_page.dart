import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Nchat"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📱 Nchat",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Nchat एक location-based chatting app है जिसमें आप "
                "अपने आस-पास के लोगों से जुड़ सकते हैं और सुरक्षित तरीके से "
                "chat request भेज सकते हैं। ऐप आपकी privacy और real-time "
                "location accuracy को ध्यान में रखकर बनाया गया है।",
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text(
                "👨‍💻 Features:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text("• अपने नज़दीकी लोगों से चैट करें (5km के अंदर)।"),
              const Text("• सुरक्षित Chat Request System।"),
              const Text("• Firebase द्वारा Real-time चैटिंग।"),
              const Text("• लोकेशन के अनुसार यूज़र्स की लिस्ट।"),
              const Text("• Push Notifications द्वारा अपडेट प्राप्त करें।"),
              const SizedBox(height: 20),
              const Divider(),
              const Text(
                "ℹ️ Developer Info",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text("Developed by: Shambhu Lal"),
              const Text("Team: SLK DEVELOPMENT TEAM"),
              const Text("Location: Udaipur, India"),
              const SizedBox(height: 20),
              const Divider(),
              const Text(
                "📧 Support",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                "यदि आपको किसी प्रकार की तकनीकी सहायता की आवश्यकता है या "
                "कोई समस्या आ रही है, तो कृपया नीचे दिए गए ईमेल पर संपर्क करें:",
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 8),
              const SelectableText(
                "✉️ snchat78@gmail.com",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text("Back to Home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
