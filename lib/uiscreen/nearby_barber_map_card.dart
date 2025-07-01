import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../models/barber_shop.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NearbyBarberMapCard extends StatefulWidget {
  final double currentLat;
  final double currentLng;

  const NearbyBarberMapCard(
      {super.key, required this.currentLat, required this.currentLng});

  @override
  State<NearbyBarberMapCard> createState() => _NearbyBarberMapCardState();
}

class _NearbyBarberMapCardState extends State<NearbyBarberMapCard> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadNearbyShops();
  }

  Future<void> _loadNearbyShops() async {
    try {
      final shops = await fetchNearbyBarberShops(widget.currentLat, widget.currentLng);
      setState(() {
        _markers.addAll(shops.map((shop) => Marker(
          markerId: MarkerId(shop.name),
          position: LatLng(shop.lat, shop.lng),
          infoWindow: InfoWindow(title: shop.name, snippet: shop.address),
        )));
      });
    } catch (e) {
      debugPrint("Error fetching barber shops: $e");
    }
  }

  Future<List<BarberShop>> fetchNearbyBarberShops(double lat, double lng) async {
    final String apiUrl =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=2000&type=hair_care&keyword=barber&key=AIzaSyCNVUq6ul9KSW5i0WGRi0UqF0CXaMPRqQA";

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded = json.decode(response.body);
      final List<dynamic> results = decoded['results'] ?? [];

      return results.map((json) => BarberShop.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load nearby barber shops");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.currentLat, widget.currentLng),
              zoom: 14,
            ),
            myLocationEnabled: true,
            markers: _markers,
            zoomControlsEnabled: false,
          ),
        ),
      ),
    );
  }
}
