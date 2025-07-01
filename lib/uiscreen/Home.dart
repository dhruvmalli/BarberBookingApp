import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String apiKey = 'AIzaSyA5xVaMFV6c5rM4BCq1uVzUmXD_MxGwEZY';
  final Location location = Location();
  StreamSubscription<LocationData>? locationSubscription;
  LocationData? previousLocation;
  List<DocumentSnapshot> shops = [];

  bool isLoading = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    initLocationUpdates();
    loadShopsFromFirestore(); // Load cached data
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  void initLocationUpdates() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }
    if (!serviceEnabled) {
      setState(() => message = 'Location services disabled.');
      return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }
    if (permissionGranted != PermissionStatus.granted) {
      setState(() => message = 'Location permission denied.');
      return;
    }

    previousLocation = await location.getLocation();
    if (previousLocation != null) {
      fetchAndStoreFromCoords(previousLocation!.latitude!, previousLocation!.longitude!);
    }

    locationSubscription = location.onLocationChanged.listen((currentLocation) {
      if (previousLocation == null ||
          calculateDistance(previousLocation!, currentLocation) >= 300) {
        previousLocation = currentLocation;
        fetchAndStoreFromCoords(currentLocation.latitude!, currentLocation.longitude!);
      }
    });
  }




  double calculateDistance(LocationData a, LocationData b) {
    const R = 6371000; // Radius of Earth in meters
    final lat1 = a.latitude! * pi / 180;
    final lon1 = a.longitude! * pi / 180;
    final lat2 = b.latitude! * pi / 180;
    final lon2 = b.longitude! * pi / 180;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(x), sqrt(1 - x));
    return R * c;
  }

  Future<List<Map<String, dynamic>>> fetchNearbyShops(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=500'
          '&type=hair_care'
          '&keyword=barber'
          '&key=$apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to fetch data from Google Places API');
    }
  }

  Future<Map<String, dynamic>?> fetchPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,rating,formatted_phone_number,photos,formatted_address,geometry,address_components'
          '&key=$apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body)['result'];
    }
    return null;
  }

  Future<void> saveShopsToFirestore(List<Map<String, dynamic>> shops) async {
    final collection = FirebaseFirestore.instance.collection('BarberShops');

    for (var shop in shops) {
      final placeId = shop['place_id'];
      final details = await fetchPlaceDetails(placeId);
      if (details == null) continue;

      List<String> photoUrls = [];
      if (details['photos'] != null) {
        for (var photo in details['photos']) {
          final ref = photo['photo_reference'];
          photoUrls.add(
              'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$ref&key=$apiKey');
        }
      }

      String pinCode = '';
      if (details['address_components'] != null) {
        for (var comp in details['address_components']) {
          if (comp['types'].contains('postal_code')) {
            pinCode = comp['long_name'];
            break;
          }
        }
      }

      await collection.doc(placeId).set({
        'name': details['name'],
        'address': details['formatted_address'],
        'location': GeoPoint(
          details['geometry']['location']['lat'],
          details['geometry']['location']['lng'],
        ),
        'rating': details['rating'] ?? 0.0,
        'phone': details['formatted_phone_number'] ?? '',
        'photos': photoUrls,
        'pincode': pinCode,
        'userRatingsTotal': shop['user_ratings_total'] ?? 0,
      }, SetOptions(merge: true));
    }
  }

  Future<void> fetchAndStoreFromCoords(double lat, double lng) async {
    setState(() {
      isLoading = true;
      message = 'Fetching nearby shops...';
    });

    try {
      final shops = await fetchNearbyShops(lat, lng);
      if (shops.isEmpty) {
        setState(() => message = 'No barber shops found nearby.');
        return;
      }

      await saveShopsToFirestore(shops);
      await loadShopsFromFirestore();
      setState(() => message = 'Nearby barber shops updated.');
    } catch (e) {
      setState(() => message = 'Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadShopsFromFirestore() async {
    final query = await FirebaseFirestore.instance
        .collection('BarberShops')
        .orderBy('rating', descending: true)
        .get();

    setState(() {
      shops = query.docs;
    });
  }

  Widget buildShopCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> photos = data['photos'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: photos.length,
                  itemBuilder: (context, index) => Image.network(
                    photos[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text('Name: ${data['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Address: ${data['address']}'),
            Text('Phone: ${data['phone'] ?? 'N/A'}'),
            Text('Rating: ${data['rating']} ⭐ (${data['userRatingsTotal']} reviews)'),
            Text('Pincode: ${data['pincode'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Barber Finder')),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          if (previousLocation != null) {
            await fetchAndStoreFromCoords(
                previousLocation!.latitude!, previousLocation!.longitude!);
          }
        },
        child: ListView(
          children: [
            const SizedBox(height: 10),
            if (message.isNotEmpty)
              Center(child: Text(message, style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 10),
            ...shops.map(buildShopCard).toList(),
          ],
        ),
      ),
    );
  }
}
