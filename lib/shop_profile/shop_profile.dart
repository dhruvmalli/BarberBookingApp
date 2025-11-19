import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../booking/book_now_page.dart';
import '../models/barber_model.dart';
import '../models/mearge_barber_model.dart';
import '../models/shop_profile_model.dart';

class ShopProfile extends StatefulWidget {
  final BarberModel? barberData;

  const ShopProfile({super.key, this.barberData});

  @override
  State<ShopProfile> createState() => _ShopProfileState();
}

class _ShopProfileState extends State<ShopProfile> {
  final lightOrange = const Color(0xFFFFFAF2);
  final orange = Colors.orangeAccent;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  MergedBarber? mergedBarber;
  bool isLoading = true;
  Position? _cachedPosition;
  List<String> _shopImages = [];
  bool? _isRegistered; // Track registration state

  @override
  void initState() {
    super.initState();
    _checkRegistration();
    _fetchShopDetails();
    _getCurrentLocation().then((pos) => _cachedPosition = pos);
  }

  Future<void> _checkRegistration() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('RegisteredShops')
          .doc(widget.barberData?.placeId)
          .get();

      setState(() {
        _isRegistered = doc.exists;
      });
    } catch (e) {
      setState(() {
        _isRegistered = false;
      });
    }
  }

  Future<void> _fetchShopDetails() async {
    try {
      final apiBarber = await GooglePlacesService()
          .getPlaceDetails(widget.barberData!.placeId);

      final doc = await FirebaseFirestore.instance
          .collection("ShopProfileDetails")
          .doc(widget.barberData!.placeId)
          .get();

      ShopProfileDetails? firebaseProfile;
      if (doc.exists) {
        firebaseProfile =
            ShopProfileDetails.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }

      setState(() {
        mergedBarber = MergedBarber.from(apiBarber!, firebaseProfile);
        _shopImages = firebaseProfile?.shopPhotos ?? [];
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching shop details: $e");
      setState(() => isLoading = false);
    }
  }

  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    try {
      final pos = _cachedPosition ?? await _getCurrentLocation();
      final currentLat = pos.latitude;
      final currentLng = pos.longitude;

      final Uri googleUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&origin=$currentLat,$currentLng&destination=$destLat,$destLng&travelmode=driving",
      );

      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Error opening maps: $e");
    }
  }

  // ---------------- HELPER WIDGETS ---------------- //

  Widget _buildImageCard(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: imageUrl.startsWith('http')
          ? Image.network(
        imageUrl,
        width: MediaQuery.of(context).size.width,
        height: 256,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: MediaQuery.of(context).size.width,
            height: 256,
            color: Colors.grey[200],
            child: const Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          );
        },
      )
          : Image.asset(
        imageUrl,
        width: MediaQuery.of(context).size.width,
        height: 256,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildServiceCircle(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightOrange,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: orange, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistCard(String imagePath, String name, String role) {
    return Container(
      width: 110,
      height: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: lightOrange,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------- MAIN BUILD ---------------- //

  @override
  Widget build(BuildContext context) {
    final barber = widget.barberData;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image carousel
                  SizedBox(
                    height: 256,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            _buildImageCard(
                                barber?.imageUrl ?? 'assets/images/image1.jpg'),
                            for (String imageUrl in _shopImages)
                              _buildImageCard(imageUrl),
                          ],
                        ),
                        Positioned(
                          bottom: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              (_shopImages.length + 1),
                                  (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin:
                                const EdgeInsets.symmetric(horizontal: 4),
                                height: 8,
                                width: _currentPage == index ? 20 : 8,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? Colors.orangeAccent
                                      : Colors.grey[400],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Shop Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      mergedBarber?.name ?? barber?.name ?? "The Barber",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Location
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.location_on,
                              color: Colors.orangeAccent),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            mergedBarber?.address ??
                                barber?.address ??
                                "123 Main Street",
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Distance
                  if (barber != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_walk,
                              color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "${barber.distanceKm.toStringAsFixed(1)} km away",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Ratings and Open/Closed
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "${barber?.rating ?? 5.0}",
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[500]),
                        ),
                        const Spacer(),
                        if (barber != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: barber.openNow ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              barber.openNow ? "Open Now" : "Closed",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Services & Actions Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildServiceCircle(Icons.language, "Website", () async {
                          if (mergedBarber?.website != null &&
                              mergedBarber!.website!.isNotEmpty) {
                            final Uri url = Uri.parse(
                              mergedBarber!.website!.startsWith("http")
                                  ? mergedBarber!.website!
                                  : "https://${mergedBarber!.website!}",
                            );
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        }),
                        _buildServiceCircle(Icons.design_services, "Services",
                                () {
                              if (mergedBarber != null) {
                                _showServicesBottomSheet(context, mergedBarber!);
                              }
                            }),
                        _buildServiceCircle(Icons.directions, "Direction",
                                () async {
                              if (barber != null) {
                                await _openGoogleMaps(barber.lat, barber.lng);
                              }
                            }),
                        _buildServiceCircle(Icons.info, "About Us", () {
                          if (mergedBarber != null) {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20))),
                              builder: (context) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 50,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                            BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "About ${mergedBarber!.name}",
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        mergedBarber!.about ??
                                            "No description available",
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        }),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(right: 12, left: 12),
                    child: Divider(color: Colors.grey[200]),
                  ),

                  const SizedBox(height: 8),

                  // Working Hours
                  Padding(
                    padding: const EdgeInsets.only(right: 12, left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Working Hours",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (mergedBarber != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 18, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              Text(
                                "Mon - Fri: ${mergedBarber?.monFriStart ?? "Not Available"} - ${mergedBarber?.monFriEnd ?? "Not Available"}",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 18, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              Text(
                                "Sat - Sun: ${mergedBarber!.satSunStart ?? "Not Available"} - ${mergedBarber!.satSunEnd ?? "Not Available"}",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),

                  // Specialists
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 16, right: 12, left: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Our Specialists",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildSpecialistCard("assets/images/image1.jpg",
                            "John Doe", "Sr. Barber"),
                        _buildSpecialistCard("assets/images/image3.jpg",
                            "Mike Trim", "Sr. Barber"),
                        _buildSpecialistCard("assets/images/image2.jpg",
                            "Alex Fade", "Jr. Barber"),
                        _buildSpecialistCard("assets/images/image1.jpg",
                            "Alex Fade", "Jr. Barber"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          // Book Now Button / Not Registered
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: _isRegistered == null
                    ? const Center(child: CircularProgressIndicator())
                    : _isRegistered == true
                    ? ElevatedButton(
                  onPressed: () {
                    if (mergedBarber != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                BookNowPage(barber: mergedBarber!)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                )
                    : Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(16)
                  ),
                    child: Center(
                      child: Text(
                        "Not Registered",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    )
                  )
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class GooglePlacesService {
  final String apiKey = "AIzaSyDG_h6XHM6HpvXkUsHT_PhmxacLuK57CAg";

  /// Fetch place details by placeId
  Future<BarberModel?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,formatted_address,geometry,rating,opening_hours,photos&key=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data["status"] == "OK") {
        final result = data["result"];

        return BarberModel(
          placeId: placeId,
          name: result["name"] ?? "Unknown",
          address: result["formatted_address"] ?? "",
          rating: (result["rating"] ?? 0).toDouble(),
          lat: result["geometry"]["location"]["lat"],
          lng: result["geometry"]["location"]["lng"],
          openNow: result["opening_hours"]?["open_now"] ?? false,
          imageUrl: result["photos"] != null && result["photos"].isNotEmpty
              ? "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${result["photos"][0]["photo_reference"]}&key=$apiKey"
              : "",
          distanceKm: 0.0, // You can calculate separately if needed
        );
      }
    }
    return null;
  }
}

void _showServicesBottomSheet(BuildContext context, MergedBarber mergedBarber) {
  final services = mergedBarber.services; // Assuming services is available in MergedBarber

  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      if (services == null || services.isEmpty) {
        return const SizedBox(
          height: 200,
          child: Center(child: Text("Services not available")),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 50,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              "Available Services",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  final name = service["service"] ?? "Service not available";
                  final price = service["price"] ?? "N/A";

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(_getServiceIcon(name), color: Colors.orange),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        "₹$price",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
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
    },
  );
}

IconData _getServiceIcon(String serviceName) {
  switch (serviceName) {
    case 'Haircut':
      return Icons.content_cut;
    case 'Shave':
      return Icons.face;
    case 'Trim':
      return Icons.cut;
    case 'Facial':
      return Icons.spa;
    case 'Hair Color':
      return Icons.color_lens;
    case 'Hair Spa':
      return Icons.water_drop;
    default:
      return Icons.build;
  }
}
