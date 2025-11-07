import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:http/http.dart' as http;
import 'package:project_sem7/uiscreen/ProfileUpdate.dart';
import '../models/barber_model.dart';
import '../shop_profile/shop_profile.dart';
import '../widgets/custom_search_bar.dart';
import 'barber_card_list.dart';
import 'package:geolocator/geolocator.dart';
import 'city_barber_list_screen.dart';
import 'notification.dart';
import 'Login.dart'; // ✅ Make sure your Login screen is imported

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class GooglePlacesService {
  final String _apiKey = 'AIzaSyDG_h6XHM6HpvXkUsHT_PhmxacLuK57CAg';

  Future<List<BarberModel>> getNearbyBarbers(
      double userLat, double userLng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=$userLat,$userLng'
            '&radius=5000'
            '&type=hair_care'
            '&keyword=barber'
            '&key=$_apiKey');

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'OK') {
      List<BarberModel> barbers = (data['results'] as List).map((place) {
        final lat = place['geometry']['location']['lat'];
        final lng = place['geometry']['location']['lng'];

        final distanceInMeters =
        Geolocator.distanceBetween(userLat, userLng, lat, lng);
        final distanceKm = distanceInMeters / 1000;

        return BarberModel(
          placeId: place['place_id'],
          name: place['name'],
          address: place['vicinity'] ?? '',
          imageUrl: place['photos'] != null
              ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${place['photos'][0]['photo_reference']}&key=$_apiKey'
              : 'https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/generic_business-71.png',
          distanceKm: distanceKm,
          rating: (place['rating'] ?? 0).toDouble(),
          lat: lat,
          lng: lng,
          openNow: place['opening_hours'] != null
              ? place['opening_hours']['open_now']
              : false,
        );
      }).toList();

      for (var barber in barbers) {
        final docRef = FirebaseFirestore.instance
            .collection('BarberCards')
            .doc(barber.placeId);

        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          await docRef.set(barber.toMap());
        }
      }

      barbers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return barbers;
    } else {
      throw Exception('Failed to load places: ${data['status']}');
    }
  }
}

Future<Position> _getCurrentPosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
}

Future<String> getCityFromCoordinates(double lat, double lng) async {
  const apiKey = 'AIzaSyDG_h6XHM6HpvXkUsHT_PhmxacLuK57CAg';
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey',
  );

  final response = await http.get(url);
  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data['status'] == 'OK') {
    for (var result in data['results']) {
      for (var component in result['address_components']) {
        final types = component['types'];
        if (types.contains('locality')) {
          return component['long_name'];
        } else if (types.contains('administrative_area_level_2')) {
          return component['long_name'];
        }
      }
    }
    return data['results'][0]['formatted_address'].split(',')[0];
  } else {
    throw Exception("Failed to fetch city");
  }
}

class _MainHomePageState extends State<MainHomePage> {
  late Future<List<BarberModel>> _barberFuture;


  @override
  void initState() {
    super.initState();

    // ✅ Start location + barbers loading
    _barberFuture = _getCurrentPosition()
        .then((position) => GooglePlacesService()
        .getNearbyBarbers(position.latitude, position.longitude))
        .catchError((e) {
      return <BarberModel>[];
    });

    // ✅ Check if blocked on app start
    _checkBlockedStatus();
  }

  Future<void> _checkBlockedStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection("BookedSlots")
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['blocked'] == true) {
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🚫 Your account has been blocked."),
              backgroundColor: Colors.red,
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Login()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      print("Error checking blocked status: $e");
    }
  }




  String _getGreetingMessage(String userName) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Morning, ${_capitalize(userName)} 🌅";
    } else if (hour >= 12 && hour < 17) {
      return "Afternoon, ${_capitalize(userName)} ☀️";
    } else if (hour >= 17 && hour < 21) {
      return "Evening, ${_capitalize(userName)} 🌇";
    } else {
      return "Night, ${_capitalize(userName)} 🌙";
    }
  }

  String _capitalize(String name) {
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 30,
                  width: 30,
                  child: Image.asset(
                      "assets/images/WhatsApp_Image_2025-07-11_at_20.05.12_409f80dc-removebg-preview.png"),
                ),
                const SizedBox(width: 10),
                const Text(
                  "FreshCut",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => NotificationScreen()));
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => Profileupdate()));
                  },
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ProfileDetail')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final userName = snapshot.data!['name'] ?? '';
                return Text(
                  _getGreetingMessage(userName),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                );
              },
            )
          ],
        ),
      ),
      body: FutureBuilder<List<BarberModel>>(
        future: _barberFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No barbers found nearby.'));
          } else {
            final barbers = snapshot.data!;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: CustomSearchBar(
                    controller: TextEditingController(),
                    onChanged: (value) {},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        "Nearby Your Barber",
                        style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          try {
                            final position = await _getCurrentPosition();
                            final city = await getCityFromCoordinates(
                                position.latitude, position.longitude);

                            if (!mounted) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CityBarberListScreen(cityName: city),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text("Failed to fetch city. Please try again.")),
                            );
                          }
                        },
                        child: const Text(
                          "See All",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                BarberCardList(barbers: barbers),
                const SizedBox(height: 20),
              ],
            );
          }
        },
      ),
    );
  }
}
