import 'package:project_sem7/models/shop_profile_model.dart';

import 'barber_model.dart';

class MergedBarber {
  final String placeId;
  final String name;
  final String address;
  final String imageUrl;
  final double distanceKm;
  final double rating;
  final double lat;
  final double lng;
  final bool openNow;

  // Extra from Firebase
  final String? about;
  final String? website;
  final String? phone;
  final String? monFriStart;
  final List<String>? shopPhotos;
  final String? monFriEnd;
  final String? satSunStart;
  final String? satSunEnd;
  final String? primaryContactNumber;
  final List<Map<String, dynamic>>? services;
  final List<String>? additionalContactNumbers;
  final String? ownerUid;
  final String? numberofbarber;// ✅ change here

  MergedBarber({
    required this.placeId,
    required this.name,
    required this.address,
    required this.imageUrl,
    required this.shopPhotos,
    required this.distanceKm,
    required this.rating,
    required this.lat,
    required this.lng,
    required this.openNow,
    this.about,
    this.website,
    this.phone,
    this.monFriStart,
    this.monFriEnd,
    this.satSunStart,
    this.satSunEnd,
    this.services,
    this.primaryContactNumber,
    this.additionalContactNumbers,
    this.ownerUid,
    this.numberofbarber
  });

  /// Merge Google + Firebase
  factory MergedBarber.from(BarberModel api, ShopProfileDetails? fb) {
    return MergedBarber(
      placeId: api.placeId,
      name: api.name,
      address: api.address,
      imageUrl: api.imageUrl,
      distanceKm: api.distanceKm,
      rating: api.rating,
      lat: api.lat,
      lng: api.lng,
      openNow: api.openNow,
      about: fb?.about,
      ownerUid: fb?.ownerUid,
      shopPhotos: fb?.shopPhotos,
      website: fb?.website,
      phone: fb?.phoneNumber,
      monFriStart: fb?.monFriStart,
      monFriEnd: fb?.monFriEnd,
      satSunStart: fb?.satSunStart,
      satSunEnd: fb?.satSunEnd,
      services: fb?.services,
      primaryContactNumber: fb?.primaryContactNumber,
      additionalContactNumbers: fb?.additionalContactNumbers,
      numberofbarber: fb?.numberofbarber,// ✅ now List<String>
    );
  }
}