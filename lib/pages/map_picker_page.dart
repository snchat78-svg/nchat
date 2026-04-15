// lib/pages/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  LatLng _initialPosition = const LatLng(24.5854, 73.7125); // fallback
  bool _gettingLocation = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareLocationAndMap();
  }

  Future<void> _prepareLocationAndMap() async {
    setState(() {
      _gettingLocation = true;
      _error = null;
    });

    try {
      final position = await _determinePosition();
      _initialPosition = LatLng(position.latitude, position.longitude);
      _selectedPosition = _initialPosition;
    } catch (e) {
      // fallback to default (_initialPosition already set)
      _error = e.toString();
      // we still allow the user to pick from fallback map
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
        // if map already created, move camera
        if (_mapController != null && _selectedPosition != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedPosition!, 15),
          );
        }
      }
    }
  }

  Future<Position> _determinePosition() async {
    // Check if location services are enabled.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. कृपया GPS चालू करें।');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      throw Exception(
          'Location permissions are permanently denied. कृपया App Settings से अनुमति दें।');
    }

    // Everything ok, get position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        actions: [
          TextButton(
            onPressed: _selectedPosition == null
                ? null
                : () {
                    Navigator.pop(context, {
                      "lat": _selectedPosition!.latitude,
                      "lng": _selectedPosition!.longitude,
                    });
                  },
            child: const Text("Done", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _gettingLocation
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("Getting current location...")
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // animate to selected if available
                    if (_selectedPosition != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(_selectedPosition!, 15),
                      );
                    }
                  },
                  onTap: (pos) {
                    setState(() => _selectedPosition = pos);
                  },
                  markers: _selectedPosition != null
                      ? {
                          Marker(
                              markerId: const MarkerId('selected'),
                              position: _selectedPosition!)
                        }
                      : {},
                ),
                if (_error != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Card(
                      color: Colors.orange.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Warning: $_error",
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 14,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      if (_selectedPosition != null) {
                        Navigator.pop(context, {
                          "lat": _selectedPosition!.latitude,
                          "lng": _selectedPosition!.longitude,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('कृपया पहले मैप पर एक जगह चुनें')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("Select Location"),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
