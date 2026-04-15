// 📁 lib/pages/nearby_users_page.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../services/block_service.dart';
import '../services/chat_request_service.dart';
import '../styles/app_styles.dart';
import 'user_detail_page.dart';
import 'incoming_request_page.dart';

class NearbyUsersPage extends StatefulWidget {
  const NearbyUsersPage({super.key});

  @override
  State<NearbyUsersPage> createState() => _NearbyUsersPageState();
}

class _NearbyUsersPageState extends State<NearbyUsersPage>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final BlockService _blockService = BlockService();
  final ChatRequestService _chatService = ChatRequestService();

  Position? _currentPosition;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<QuerySnapshot>? _userListener;
  List<UserModel> _nearby = [];
  List<String> _blockedIds = [];
  List<String> _sentRequests = [];

  bool _isLoading = true;
  bool _timeoutReached = false;
  Timer? _timeoutTimer;

  String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  static const int _timeoutSeconds = 20;
  static const double _radiusKm = 5.0;
  static const int _distanceFilterMeters = 100;

  // Radar animation
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _startTimeout();
    _startPositionStream();
    _loadBlockedUsers();
    _loadSentRequests();
    _listenToFirestoreUpdates();
  }

  void _listenToFirestoreUpdates() {
    _userListener = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((_) async {
      if (_currentPosition != null) {
        await _fetchNearby(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    });
  }

  Future<void> _loadBlockedUsers() async {
    if (currentUid.isEmpty) return;
    final ids = await _block_service_getBlockedSafe();
    if (!mounted) return;
    setState(() => _blockedIds = ids);
  }

  Future<List<String>> _block_service_getBlockedSafe() async {
    try {
      return await _blockService.getBlockedUserIds(currentUid);
    } catch (e) {
      debugPrint("getBlockedUserIds error: $e");
      return [];
    }
  }

  Future<void> _loadSentRequests() async {
    if (currentUid.isEmpty) return;
    final list = await _chat_service_getSentRequestsSafe();
    if (!mounted) return;
    setState(() => _sentRequests = list);
  }

  Future<List<String>> _chat_service_getSentRequestsSafe() async {
    try {
      return await _chatService.getSentRequests(currentUid);
    } catch (e) {
      debugPrint("getSentRequests error: $e");
      return [];
    }
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutReached = false;
    _timeoutTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      if (mounted) {
        setState(() {
          _timeoutReached = true;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _startPositionStream() async {
    try {
      final ok = await LocationService.ensurePermission();
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _timeoutReached = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Location permission denied")),
        );
        return;
      }

      await _posSub?.cancel();
      _posSub = LocationService.positionStream(
        distanceFilter: _distanceFilterMeters,
      ).listen((pos) async {
        if (!mounted) return;
        _timeoutTimer?.cancel();
        _timeoutReached = false;

        setState(() {
          _currentPosition = pos;
          _isLoading = true;
        });

        await LocationService.updateFirestore(pos);
        await _fetchNearby(pos.latitude, pos.longitude);
      }, onError: (e) {
        debugPrint("Position stream error: $e");
      });
    } catch (e) {
      debugPrint("startPositionStream error: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _timeoutReached = true;
      });
    }
  }

  Future<void> _fetchNearby(double myLat, double myLng) async {
    try {
      final all = await _userService.getNearbyPersons(
        myLat,
        myLng,
        radiusInKm: _radiusKm,
      );

      final acceptedIds =
          await _chatService.getAcceptedUserIds(currentUid);

      const double earthRadiusKm = 6371.0;
      final List<UserModel> valid = [];

      for (final u in all) {
        if (u.latitude == null || u.longitude == null) continue;
        if (u.uid == currentUid) continue;
        if (_blockedIds.contains(u.uid)) continue;
        if (acceptedIds.contains(u.uid)) continue;
        if (_sentRequests.contains(u.uid)) continue;

        final double lat1 = myLat * math.pi / 180.0;
        final double lon1 = myLng * math.pi / 180.0;
        final double lat2 = u.latitude! * math.pi / 180.0;
        final double lon2 = u.longitude! * math.pi / 180.0;

        final double dLat = lat2 - lat1;
        final double dLon = lon2 - lon1;

        final double a = math.pow(math.sin(dLat / 2), 2) +
            math.cos(lat1) *
                math.cos(lat2) *
                math.pow(math.sin(dLon / 2), 2);

        final double c =
            2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

        final double distanceKm = earthRadiusKm * c;

        if (distanceKm <= _radiusKm &&
            (u.online == true || u.lastSeen != null)) {
          valid.add(u);
        }
      }

      // 🔥 NEAREST FIRST SORTING (CORRECT PLACE)
      valid.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          myLat,
          myLng,
          a.latitude!,
          a.longitude!,
        );

        final distB = Geolocator.distanceBetween(
          myLat,
          myLng,
          b.latitude!,
          b.longitude!,
        );

        return distA.compareTo(distB);
      });

      if (!mounted) return;
      setState(() {
        _nearby = valid;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("fetchNearby error: $e");
      if (!mounted) return;
      setState(() {
        _nearby = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefreshPressed() async {
    setState(() {
      _isLoading = true;
      _timeoutReached = false;
    });
    _startTimeout();
    await _loadBlockedUsers();
    await _loadSentRequests();

    if (_currentPosition != null) {
      await _fetchNearby(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = pos);
      await LocationService.updateFirestore(pos);
      await _fetchNearby(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint("manual getCurrentPosition error: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _timeoutReached = true;
      });
    }
  }

  Future<void> _onManualUpdate() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await LocationService.updateFirestore(pos);
      setState(() => _currentPosition = pos);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📍 Location updated successfully")),
      );
      await _fetchNearby(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint("manual update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to update location")),
      );
    }
  }

  Future<void> _sendRequest(UserModel target) async {
    if (_blockedIds.contains(target.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚫 आपने इस यूज़र को ब्लॉक किया है")),
      );
      return;
    }

    if (_sentRequests.contains(target.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📨 रिक्वेस्ट पहले ही भेजी जा चुकी है")),
      );
      return;
    }

    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ User not logged in")),
      );
      return;
    }

    UserModel? me;
    try {
      me = await _userService.getUserById(currentUid);
    } catch (e) {
      debugPrint("getUserById error: $e");
    }

    final senderName =
        me?.name ??
            FirebaseAuth.instance.currentUser?.displayName ??
            "Unknown User";
    final senderEmail =
        me?.email ??
            FirebaseAuth.instance.currentUser?.email ??
            "";

    final success = await _chatService.sendRequestByIds(
      currentUid,
      target.uid,
      senderName: senderName,
      senderEmail: senderEmail,
    );

    if (success) {
      if (!mounted) return;
      setState(() => _sentRequests.add(target.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "✅ ${target.name ?? 'User'} को रिक्वेस्ट भेज दी गई"),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to send request")),
      );
    }
  }

  void _openIncomingRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncomingRequestPage()),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _posSub?.cancel();
    _userListener?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  Widget _buildRadar() {
    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(3, (i) {
              final radius = 50.0 + i * 30;
              return AnimatedBuilder(
                animation: _radarController,
                builder: (_, __) {
                  return Container(
                    width: radius,
                    height: radius,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.teal.withOpacity(
                            1.0 - _radarController.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              );
            }),
            RotationTransition(
              turns: _radarController,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.teal.withOpacity(0.3),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            const Icon(Icons.my_location, size: 32, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nearby Users"),
            SizedBox(height: 2),
            Text(
              "People near you",
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orangeAccent),
            onPressed: _onRefreshPressed,
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.tealAccent),
            onPressed: _onManualUpdate,
          ),
        ],
      ),
      body: _isLoading
          ? _buildRadar()
          : _nearby.isEmpty
              ? Center(
                  child: Text(
                    "❌ $_radiusKm km के अंदर कोई यूज़र नहीं मिला।",
                    style: AppStyles.subHeading,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _nearby.length,
                  itemBuilder: (context, index) {
                    final u = _nearby[index];
                    final bool alreadySent =
                        _sentRequests.contains(u.uid);
                    final bool isBlocked =
                        _blockedIds.contains(u.uid);

                    double? dist;
                    if (u.latitude != null &&
                        u.longitude != null &&
                        _currentPosition != null) {
                      final meters = Geolocator.distanceBetween(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        u.latitude!,
                        u.longitude!,
                      );
                      dist = meters / 1000.0;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: const Color(0xFFF1F8F7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
// Avatar (Clickable → Open User Detail Page)
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailPage(targetUser: u),
      ),
    );
  },
  child: Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.teal.shade200,
        width: 2,
      ),
    ),
    child: Stack(
  children: [
    CircleAvatar(
      radius: 28,
      backgroundImage: (u.profilePic != null &&
              u.profilePic!.isNotEmpty)
          ? NetworkImage(u.profilePic!)
          : null,
      child: (u.profilePic == null ||
              u.profilePic!.isEmpty)
          ? const Icon(Icons.person, size: 28)
          : null,
    ),

    // 🟢 Online Green Dot
    if (u.online == true)
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          height: 14,
          width: 14,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
      ),
  ],
),

  ),
),


                            const SizedBox(width: 12),

                            // Info column
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.name ?? "Unknown",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyles.heading,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    u.gender ?? "Not set",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Distance badge
                                  if (dist != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "📍 ${dist.toStringAsFixed(2)} km",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.teal,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Request Button
                            SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  alreadySent
                                      ? Icons.done
                                      : Icons.send,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  alreadySent ? "Sent" : "Request",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                onPressed: (alreadySent || isBlocked)
                                    ? null
                                    : () => _sendRequest(u),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: alreadySent
                                      ? Colors.grey
                                      : Colors.teal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                              ),
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
