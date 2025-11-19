class ShopProfileDetails {
  final String ownerUid;
  final String? shopName;
  final String? address;
  final List<String>? shopPhotos;
  final String? website;
  final String? about;
  final String? numberofbarber;

  // Working hours
  final String? monFriStart;
  final String? monFriEnd;
  final String? satSunStart;
  final String? satSunEnd;

  //Barber name  and contact
  final List<String>? barbers;

  // Services
  final List<Map<String, dynamic>>? services;

  ShopProfileDetails({
    required this.ownerUid,
    this.shopName,
    this.address,
    this.shopPhotos,
    this.website,
    this.about,
    this.monFriStart,
    this.monFriEnd,
    this.satSunStart,
    this.satSunEnd,
    this.services,
    this.numberofbarber,
    this.barbers,
  });

  factory ShopProfileDetails.fromMap(String id, Map<String, dynamic> data) {
    return ShopProfileDetails(
        ownerUid: data['ownerUid'] ?? "",
        shopName: data['shopName'],
        address: data['address'],
        website: data['websiteLink'],
        about: data['aboutShop'],
        monFriStart: data['monFriStart'],
        monFriEnd: data['monFriEnd'],
        satSunStart: data['satSunStart'],
        satSunEnd: data['satSunEnd'],
        numberofbarber: data['numberofbarber'],

        shopPhotos: data['shopPhotos'] != null
            ? List<String>.from(data['shopPhotos'])
            : null,

        // Services list
        services: (data['Services'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),

        barbers: data['barbers'] != null
          ? List<String>.from(data['barbers'])
          :null,


    );
  }
}