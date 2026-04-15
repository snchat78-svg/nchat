// 📁 lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/chat_request_service.dart';

// Pages
import 'chat_users_page.dart';
import 'nearby_users_page.dart';
import 'incoming_request_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AuthService authService;
  late final UserService userService;
  final ChatRequestService _chatRequestService = ChatRequestService();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<QuerySnapshot>? _firestoreListener;
  int _pendingRequestCount = 0;

bool showMapFeature = false; 

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    authService = AuthService();
    userService = UserService();

userService.setOnlineStatus(true);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _startIfPerson();
    _loadPendingRequests();
    _startFirestoreListener();
  }

  void _startFirestoreListener() {
    final uid = authService.currentUserId;
    if (uid == null) return;

    _firestoreListener = FirebaseFirestore.instance
        .collection('chatRequests')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() => _pendingRequestCount = snapshot.docs.length);
    });
  }

  Future<void> _loadPendingRequests() async {
    final currentUser = await userService.getUserData();
    if (currentUser == null) return;
    final requests =
        await _chatRequestService.getIncomingRequests(currentUser.uid);
    if (!mounted) return;
    setState(() => _pendingRequestCount = requests.length);
  }

  Future<void> _startIfPerson() async {
    final u = await userService.getUserData();
    if (u == null) return;

    if (u.userType == 'person') {
      final ok = await LocationService.ensurePermission();
      if (!ok) return;

      _positionSub =
          LocationService.positionStream(distanceFilter: 10).listen((pos) {
        LocationService.updateFirestore(pos);
      });
    }
  }

  void _logout() async {
    _positionSub?.cancel();
    _firestoreListener?.cancel();
   await userService.setOnlineStatus(false);
    await authService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _firestoreListener?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ---------------- NAVIGATION ----------------

  void _openProfile() => Navigator.pushNamed(context, '/profile');
  void _openSettings() => Navigator.pushNamed(context, '/settings');
  void _openNearbyMap() => Navigator.pushNamed(context, '/map');
  void _openBlockedUsers() => Navigator.pushNamed(context, '/blockedUsers');

  void _openChatUsers() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ChatUsersPage()));
  }

  void _openNearbyUsers() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const NearbyUsersPage()));
  }

  void _openIncomingRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncomingRequestPage()),
    );
    _loadPendingRequests();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                  .animate(_controller),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Nchat',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 2),
              Text('Connect with nearby people instantly',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_active_outlined,
              color: Colors.white),
          onPressed: () =>
              Navigator.pushNamed(context, '/notification'),
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.mail_outline, color: Colors.white),
              onPressed: _openIncomingRequests,
            ),
            if (_pendingRequestCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.redAccent,
                  child: Text(
                    _pendingRequestCount.toString(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        if (showMapFeature)
  _animatedCard(
    delay: 0,
    child: _premiumButton(
      Icons.map,
      "Nearby Users on Map",
      "See people around you on live map",
      Colors.teal,
      _openNearbyMap, // जब ready हो तब use होगा
    ),
  ),
          const SizedBox(height: 20),
          _animatedCard(
            delay: 0.1,
            child: _premiumButton(
              Icons.people,
              "Chat Users",
              "Start chatting with connected users",
              Colors.blueGrey,
              _openChatUsers,
            ),
          ),
          const SizedBox(height: 20),
          _animatedCard(
            delay: 0.2,
            child: _premiumButton(
              Icons.location_on,
              "Nearby Users List",
              "Browse users near your location",
              Colors.green,
              _openNearbyUsers,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- DRAWER ----------------

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.teal,
              child: const Text(
                'Nchat Menu',
                style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            _drawerItem(Icons.person, 'My Profile', _openProfile),
            _drawerItem(Icons.block, 'Blocked Users', _openBlockedUsers),
            _drawerItem(Icons.people, 'Chat Users', _openChatUsers),
            _drawerItem(Icons.location_on, 'Nearby Users List', _openNearbyUsers),
            _drawerItem(Icons.settings, 'Settings', _openSettings),
            const Spacer(),
            _drawerItem(Icons.logout, 'Logout', _logout),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
      IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // ---------------- HELPERS ----------------

  Widget _animatedCard({required Widget child, required double delay}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, 1, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                .animate(_controller),
        child: child,
      ),
    );
  }

  Widget _premiumButton(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
