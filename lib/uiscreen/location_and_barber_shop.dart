import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:project_sem7/uiscreen/settings.dart';

import 'liked_shops.dart';
import 'main_home_page.dart';
import 'my_booking_page.dart';

class LocationAndBarberShop extends StatefulWidget {
  const LocationAndBarberShop({super.key});

  @override
  State<LocationAndBarberShop> createState() => _LocationAndBarberShopState();
}

class _LocationAndBarberShopState extends State<LocationAndBarberShop> {
  late GoogleMapController _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  String _selectedShopName = '';
  final String apiKey = 'AIzaSyA5xVaMFV6c5rM4BCq1uVzUmXD_MxGwEZY';

  int _selectedIndex = 2;

  void _onNavTap(int index){
    setState(() {
      _selectedIndex = index;
    });

    if(index == 0){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainHomePage()));
    }else if(index == 1){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyBookingPage()));
    }else if(index == 2){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LocationAndBarberShop()));
    }else if(index == 3){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LikedShops()));
    }else if(index == 4){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Settings()));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLocationAndShops();
  }

  Future<void> _fetchLocationAndShops() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Step 1: Check location services
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _selectedShopName = 'Location services are disabled. Please enable GPS.';
      });
      return;
    }

    // Step 2: Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() {
          _selectedShopName = 'Location permission is denied.';
        });
        return;
      }
    }

    // Step 3: Get current position
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
      }

      print('User location: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentPosition = position;
      });

      String apiUrl =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${position.latitude},${position.longitude}'
          '&radius=5000' // Use larger radius
          '&type=hair_care'
          '&keyword=barber'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(apiUrl));
      print('Nearby search response: ${response.body}');


      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          Set<Marker> newMarkers = {};

          for (var place in data['results']) {
            final shopName = place['name'];
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];

            newMarkers.add(
              Marker(
                markerId: MarkerId(shopName),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: shopName),
              ),
            );
          }

          setState(() {
            _markers = newMarkers;
            _selectedShopName = 'Nearby barber shops loaded.';
          });
        } else {
          setState(() {
            _selectedShopName = 'No shops found: ${data['status']}';
          });
        }
      } else {
        setState(() {
          _selectedShopName = 'Failed to load shops: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _selectedShopName = 'Error fetching shops: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: (_currentPosition == null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 14,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_selectedShopName.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedShopName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -3), // ⬅️ Shadow appears at the top side
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.black,
            onTap: _onNavTap,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Booked"),
              BottomNavigationBarItem(icon: Icon(Icons.location_on), label: "Near shop"),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Liked shop"),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
            ],
          ),
        ),
      ),
    );
  }
}

