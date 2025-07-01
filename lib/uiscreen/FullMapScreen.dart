import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FullMapScreen extends StatelessWidget {
  final double userLat;
  final double userLng;
  final List<DocumentSnapshot> shops;

  const FullMapScreen({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.shops,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Barber Shops')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(userLat, userLng),
          zoom: 14,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('user'),
            position: LatLng(userLat, userLng),
            infoWindow: const InfoWindow(title: "You"),
          ),
          ...shops.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final GeoPoint loc = data['location'];
            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(loc.latitude, loc.longitude),
              infoWindow: InfoWindow(
                title: data['name'],
                snippet: data['address'],
              ),
            );
          }).toSet(),
        },
        myLocationEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }
}
