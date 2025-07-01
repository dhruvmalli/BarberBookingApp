class BarberShop {
  final String name;
  final String address;
  final String imageUrl;
  final double rating;
  final double lat;
  final double lng;

  BarberShop({
    required this.name,
    required this.address,
    required this.imageUrl,
    required this.rating,
    required this.lat,
    required this.lng,
  });

  factory BarberShop.fromJson(Map<String, dynamic> json) {
    String photoReference = '';
    if (json['photos'] != null && json['photos'].isNotEmpty) {
      photoReference = json['photos'][0]['photo_reference'];
    }

    // Build image URL if photoReference exists
    final String imageUrl = photoReference.isNotEmpty
        ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=AIzaSyCNVUq6ul9KSW5i0WGRi0UqF0CXaMPRqQA'
        : 'https://via.placeholder.com/150';

    // Safely extract geometry -> location -> lat/lng
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    final lat = location != null && location['lat'] != null
        ? (location['lat'] as num).toDouble()
        : 0.0;

    final lng = location != null && location['lng'] != null
        ? (location['lng'] as num).toDouble()
        : 0.0;

    return BarberShop(
      name: json['name'] ?? 'No Name',
      address: json['vicinity'] ?? 'No Address',
      imageUrl: imageUrl,
      rating: (json['rating'] ?? 0).toDouble(),
      lat: lat,
      lng: lng,
    );
  }
}
