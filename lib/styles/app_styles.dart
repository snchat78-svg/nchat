import 'package:flutter/material.dart';

class AppStyles {
  // ✅ Fix for Step 2
  static const double cardRadius = 12.0;
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  // 🔹 Common Padding
  static const horizontalPadding = EdgeInsets.symmetric(horizontal: 16);
  static const verticalPadding = EdgeInsets.symmetric(vertical: 12);

  // 🔹 Heading Text
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 🔹 Subheading Text
  static const subHeading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  // 🔹 Info Text (grey)
  static const infoText = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  // 🔹 Small grey text
  static const smallGrey = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  // 🔹 Button Text
  static const buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // 🔹 Block Button Style
  static final blockButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.redAccent,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // 🔹 Unblock Button Style
  static final unblockButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // 🔹 ListTile Title Text
  static const listTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // 🔹 ListTile Subtitle Text
  static const listSubtitle = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  // 🔹 Section Divider
  static const divider = Divider(
    height: 32,
    thickness: 1,
    color: Colors.grey,
  );
}
