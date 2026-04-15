import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../styles/app_styles.dart';
import 'user_detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GoogleMapController? mapController;
  final Set<Marker> _markers = {};

  double initialLat = 20.5937; // भारत का center
  double initialLng = 78.9629;

  @override
  void initState() {
    super.initState();
    listenAcceptedUsers(); // ✅ accepted users को real-time सुनना
  }

  /// 🔁 सिर्फ accepted users fetch करने का stream
  void listenAcceptedUsers() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    _firestore
        .collection('accepted_users') // ✅ तुम्हारे पास यह collection होना चाहिए
        .where('uids', arrayContains: currentUid) // दोनों users का relation
        .snapshots()
        .listen((snapshot) async {
      final acceptedIds = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['uids'] != null) {
          for (var id in List<String>.from(data['uids'])) {
            if (id != currentUid) {
              acceptedIds.add(id);
            }
          }
        }
      }

      if (acceptedIds.isEmpty) {
        setState(() => _markers.clear());
        return;
      }

      // अब users collection से real-time fetch
      _firestore
          .collection('users')
          .where('uid', whereIn: acceptedIds.toList())
          .snapshots()
          .listen((userSnap) {
        final users = userSnap.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .where((u) => u.latitude != null && u.longitude != null)
            .toList();

        if (!mounted) return;
        setState(() {
          _markers.clear();
          for (var user in users) {
            final displayName = user.name ?? "User";

            _markers.add(
              Marker(
                markerId: MarkerId(user.uid),
                position: LatLng(user.latitude!, user.longitude!),
                infoWindow: InfoWindow(
                  title: displayName,
                  snippet: "Accepted User",
                  onTap: () {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailPage(targetUser: user),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        });
      });
    });
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby on Map"),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(initialLat, initialLng),
          zoom: 5,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          mapController = controller;
        },
        myLocationEnabled: true,
        zoomControlsEnabled: true,
        mapType: MapType.normal,
      ),
    );
  }
}
