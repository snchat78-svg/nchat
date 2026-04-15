// 📁 lib/main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models/user_model.dart';

// ✅ Pages
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'pages/welcome_page.dart';
import 'pages/splash_page.dart';
import 'pages/register_person_page.dart';
import 'pages/chat_users_page.dart';
import 'pages/chat_room_page.dart';
import 'pages/incoming_request_page.dart';
import 'pages/map_page.dart';
import 'pages/profile_page.dart';
import 'pages/user_detail_page.dart';
import 'pages/settings_page.dart';
import 'pages/notification_page.dart';
import 'pages/blocked_users_page.dart';

// ✅ Services
import 'services/push_notification_service.dart';
import 'services/user_service.dart';

// 🔔 Background Notification Handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 [BG] Message Received: ${message.notification?.title}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await PushNotificationService.initializeLocalNotifications();

  final pushService = PushNotificationService();
  await pushService.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// 🔴 ONLINE STATUS SUPPORT ADDED
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  Future<void> _updateOnlineStatus(bool online) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await UserService().updateUserPresence(
      uid: uid,
      online: online,
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _updateOnlineStatus(true);

    // 🔔 Foreground notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 [FG] Message Received: ${message.notification?.title}");

      if (message.notification != null) {
        PushNotificationService.showNotification(
          title: message.notification!.title ?? "Nchat",
          body: message.notification!.body ?? "",
        );
      }
    });

    // 🔔 Notification click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📲 Notification Clicked → ${message.data}");
      if (!mounted) return;
      final data = message.data;

      if (data['screen'] == 'chatRoom') {
        Navigator.pushNamed(context, '/chatRoom', arguments: null);
      } else if (data['screen'] == 'notification') {
        Navigator.pushNamed(context, '/notification');
      } else if (data['screen'] == 'map') {
        Navigator.pushNamed(context, '/map');
      } else if (data['screen'] == 'incomingRequest') {
        Navigator.pushNamed(context, '/incomingRequest');
      }
    });
  }

  // 🔴 APP LIFE CYCLE TRACKING
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _updateOnlineStatus(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateOnlineStatus(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nchat',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.teal,
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          margin: const EdgeInsets.all(8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16),
            backgroundColor: Colors.teal,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),

      routes: {
        '/home': (_) => const HomePage(),
        '/signup': (_) => const SignupPage(),
        '/login': (_) => const LoginPage(),
        '/welcome': (_) => const WelcomePage(),
        '/splash': (_) => const SplashPage(),
        '/registerPerson': (_) => const RegisterPersonPage(),
        '/chatUsers': (_) => const ChatUsersPage(),
        '/incomingRequest': (_) => const IncomingRequestPage(),
        '/map': (_) => const MapPage(),
        '/profile': (_) => const ProfilePage(),
        '/settings': (_) => const SettingsPage(),
        '/notification': (_) => const NotificationPage(),
        '/blockedUsers': (_) => const BlockedUsersPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/userDetail') {
          final user = settings.arguments as UserModel;
          return MaterialPageRoute(
            builder: (_) => UserDetailPage(targetUser: user),
          );
        }

        if (settings.name == '/chatRoom') {
          final targetUser = settings.arguments as UserModel?;
          if (targetUser == null) {
            return MaterialPageRoute(
              builder: (_) => const IncomingRequestPage(),
            );
          }
          return MaterialPageRoute(
            builder: (_) => ChatRoomPage(targetUser: targetUser),
          );
        }

        return null;
      },
    );
  }
}

/// ✅ AuthGate
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _handleUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const LoginPage();

    if (!user.emailVerified) return const LoginPage();

    final userService = UserService();
    final userModel = await userService.getUserById(user.uid);

    if (userModel == null || userModel.userType.isEmpty) {
      return const RegisterPersonPage();
    }

    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _handleUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const LoginPage();
      },
    );
  }
}
