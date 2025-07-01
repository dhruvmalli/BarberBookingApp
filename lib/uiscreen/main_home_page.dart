import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../models/barber_shop.dart';
import 'barber_shop_card.dart';
import 'nearby_barber_map_card.dart';
import 'package:http/http.dart' as http;

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  int _currentIndex = 0;

  double? _currentLat;
  double? _currentLng;
  Future<List<BarberShop>>? _futureBarberShops; // ✅ declare this

  bool _isLoadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();

    try {
      final hasPermission = await location.requestPermission();
      if (hasPermission != PermissionStatus.granted &&
          hasPermission != PermissionStatus.grantedLimited) {
        setState(() {
          _locationError = "Location permission denied.";
          _isLoadingLocation = false;
        });
        return;
      }

      final locData = await location.getLocation();
      setState(() {
        _currentLat = locData.latitude;
        _currentLng = locData.longitude;
        _futureBarberShops = fetchNearbyBarberShops(_currentLat!, _currentLng!);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = "Failed to get location: $e";
        _isLoadingLocation = false;
      });
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
    return Scaffold(
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : _locationError != null
          ? Center(child: Text(_locationError!))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, top: 48, right: 16, bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.rounded_corner),
                      SizedBox(width: 8),
                      Text(
                        'The Barber',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.notifications_none,
                          color: Colors.black87, size: 24),
                      SizedBox(width: 16),
                      Icon(Icons.account_circle_outlined,
                          color: Colors.black87, size: 24),
                    ],
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Text("Hello, username 👋",
                  style: TextStyle(fontSize: 18)),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 48,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search barbers...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),

            // ✅ Pass lat/lng to NearbyBarberMapCard
            if (_currentLat != null && _currentLng != null)
              NearbyBarberMapCard(
                  currentLat: _currentLat!,
                  currentLng: _currentLng!),
            const SizedBox(height: 8),
            Divider(
                color: Colors.grey[300],
                thickness: 1,
                indent: 16,
                endIndent: 16),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text("Nearby Your Barber",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("See All",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.orangeAccent[200],
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            FutureBuilder<List<BarberShop>>(
              future: _futureBarberShops,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No nearby barber shops found.'));
                }

                final shops = snapshot.data!.take(3).toList();

                return Column(
                  children: shops
                      .map((shop) => Padding(
                    padding:
                    const EdgeInsets.only(bottom: 10),
                    child: BarberShopCard(
                      imageUrl: shop.imageUrl,
                      shopName: shop.name,
                      address: shop.address,
                      rating: shop.rating,
                    ),
                  ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
