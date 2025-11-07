import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/barber_model.dart';
import '../widgets/custom_search_bar.dart';

class CityBarberListScreen extends StatefulWidget {
  final String cityName;
  const CityBarberListScreen({super.key, required this.cityName});

  @override
  State<CityBarberListScreen> createState() => _CityBarberListScreenState();
}

class _CityBarberListScreenState extends State<CityBarberListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BarberModel> _allBarbers = [];
  List<BarberModel> _filteredBarbers = [];

  @override
  void initState() {
    super.initState();
    fetchBarbersByCity(widget.cityName);
  }

  Future<void> fetchBarbersByCity(String city) async {
    const apiKey = 'AIzaSyDG_h6XHM6HpvXkUsHT_PhmxacLuK57CAg';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?query=barber+in+$city&key=$apiKey',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'OK') {
      List<BarberModel> barbers = (data['results'] as List).map((place) {
        return BarberModel(
          name: place['name'],
          placeId: place['placeId'],
          address: place['formatted_address'] ?? '',
          imageUrl: place['photos'] != null
              ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${place['photos'][0]['photo_reference']}&key=$apiKey'
              : 'https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/generic_business-71.png',
          distanceKm: 0.0,
          rating: (place['rating'] ?? 0).toDouble(),
          lat: place['geometry']['location']['lat'],
          lng: place['geometry']['location']['lng'],
          openNow: place['opening_hours'] != null ? place['opening_hours']['open_now'] : false,
        );
      }).toList();

      barbers.sort((a, b) => b.rating.compareTo(a.rating));

      setState(() {
        _allBarbers = barbers;
        _filteredBarbers = barbers;
      });
    } else {
      throw Exception('Failed to load barbers');
    }
  }

  void _filterBarbers(String query) {
    setState(() {
      _filteredBarbers = _allBarbers
          .where((barber) =>
          barber.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: Text("Barbers in ${widget.cityName}"),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: CustomSearchBar(
              controller: _searchController,
              onChanged: _filterBarbers,
            ),
          ),

          Expanded(
            child: _filteredBarbers.isEmpty
                ? const Center(child: Text("No barbers found."))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredBarbers.length,
              itemBuilder: (context, index) {
                final barber = _filteredBarbers[index];
                return SizedBox(
                  height: 120,
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    margin:
                    const EdgeInsets.only(right: 4, left: 4, bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              barber.imageUrl,
                              width: 70,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 70,
                                  height: 90,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  barber.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  barber.address,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 18, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      barber.rating.toString(),
                                      style:
                                      const TextStyle(fontSize: 14),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: barber.openNow
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      barber.openNow
                                          ? 'Open Now'
                                          : 'Closed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: barber.openNow
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
