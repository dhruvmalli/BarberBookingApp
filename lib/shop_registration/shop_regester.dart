import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopRegister extends StatefulWidget {
  const ShopRegister({Key? key}) : super(key: key);

  @override
  State<ShopRegister> createState() => _ShopRegisterState();
}

class _ShopRegisterState extends State<ShopRegister> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  List<TextEditingController> _phoneControllers = [TextEditingController()];

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isAlreadyRegistered = false;
  bool _isLoading = true;
  String? _selectedPlaceId;

  final String _googleApiKey = "AIzaSyDG_h6XHM6HpvXkUsHT_PhmxacLuK57CAg";

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
  }

  /// 🔹 Load the user's registered shop, if any
  Future<void> _loadShopDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Query RegisteredShops by ownerUid
    final querySnap = await FirebaseFirestore.instance
        .collection("RegisteredShops")
        .where("ownerUid", isEqualTo: user.uid)
        .limit(1)
        .get();

    if (querySnap.docs.isNotEmpty) {
      final shopData = querySnap.docs.first.data();
      _shopNameController.text = shopData["shopName"] ?? "";
      _addressController.text = shopData["address"] ?? "";
      _selectedPlaceId = shopData["googlePlaceId"];

      List phones = shopData["mobileNumbers"] ?? [];
      if (phones.isNotEmpty) {
        _phoneControllers =
            phones.map((p) => TextEditingController(text: p)).toList();
      }

      _isAlreadyRegistered = true;
    }

    setState(() => _isLoading = false);
  }

  /// 🔹 Google Places search
  Future<void> _searchShops(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    setState(() => _isSearching = true);

    final encodedQuery = Uri.encodeComponent("$query barber");
    final url =
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&key=$_googleApiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List results = data["results"];

      setState(() {
        _searchResults = results.map((shop) {
          return {
            "name": shop["name"] ?? "",
            "address": shop["formatted_address"] ?? "",
            "place_id": shop["place_id"],
          };
        }).toList();
      });
    } else {
      setState(() => _searchResults.clear());
    }

    setState(() => _isSearching = false);
  }

  /// 🔹 Register the shop using Google Place ID & UID both
  Future<void> _registerShop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedPlaceId == null || _selectedPlaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a shop from search results.")),
      );
      return;
    }

    final placeId = _selectedPlaceId!;

    // Check if this placeId is already registered
    final existingShop = await FirebaseFirestore.instance
        .collection("RegisteredShops")
        .doc(placeId)
        .get();

    if (existingShop.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This shop is already registered.")),
      );
      return;
    }

    // Get user profile
    final profileSnap = await FirebaseFirestore.instance
        .collection("ProfileDetail")
        .doc(user.uid)
        .get();

    if (!profileSnap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile not found. Please update profile first.")),
      );
      return;
    }

    String name = profileSnap.data()?["name"] ?? "Unknown Barber";
    String email = profileSnap.data()?["email"] ?? user.email ?? "";

    List<String> mobileNumbers = _phoneControllers
        .map((c) => c.text.trim())
        .where((num) => num.isNotEmpty)
        .toList();

    if (_shopNameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill shop name and address")),
      );
      return;
    }

    // Data to save
    final shopData = {
      "ownerUid": user.uid,
      "name": name,
      "email": email,
      "shopName": _shopNameController.text.trim(),
      "mobileNumbers": mobileNumbers,
      "address": _addressController.text.trim(),
      "googlePlaceId": placeId,
      "createdAt": FieldValue.serverTimestamp(),
    };

    // Save in RegisteredShops with doc = placeId
    await FirebaseFirestore.instance
        .collection("RegisteredShops")
        .doc(placeId)
        .set(shopData, SetOptions(merge: true));

    // Save same data in RegisteredShops with doc = uid
    await FirebaseFirestore.instance
        .collection("RegisteredShops")
        .doc(user.uid)
        .set(shopData, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Shop registered successfully!")),
    );

    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Register Your Shop",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Find Your Shop",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextField(
                  controller: _searchController,
                  enabled: !_isAlreadyRegistered,
                  onChanged: (value) => _searchShops(value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    hintText: "Search your shop here...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Shop Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                _buildCard(
                  child: TextField(
                    controller: _shopNameController,
                    enabled: !_isAlreadyRegistered,
                    decoration: const InputDecoration(
                      hintText: "Enter shop name",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Contact Numbers",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Column(
                  children: List.generate(_phoneControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCard(
                        child: TextField(
                          controller: _phoneControllers[index],
                          keyboardType: TextInputType.phone,
                          enabled: !_isAlreadyRegistered,
                          decoration: const InputDecoration(
                            hintText: "Enter phone number",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text("Address",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                _buildCard(
                  child: TextField(
                    controller: _addressController,
                    enabled: !_isAlreadyRegistered,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: "Enter shop address",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          // Floating Search Results
          if (_searchResults.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 70,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final shop = _searchResults[index];
                      return ListTile(
                        title: Text(shop["name"]),
                        subtitle: Text(shop["address"]),
                        onTap: () {
                          _shopNameController.text = shop["name"];
                          _addressController.text = shop["address"];
                          _selectedPlaceId = shop["place_id"];
                          setState(() => _searchResults.clear());
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isAlreadyRegistered ? null : _registerShop,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAlreadyRegistered ? Colors.grey : Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _isAlreadyRegistered ? "Already Registered" : "Register Shop",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}