import 'dart:convert';
import 'dart:io';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_sem7/Services.dart';

class EditShopProfile extends StatefulWidget {
  final String uid;
  final String placeId;

  const EditShopProfile({super.key, required this.placeId, required this.uid});

  @override
  State<EditShopProfile> createState() {
    debugPrint("EditShopProfile constructor called with placeId: '$placeId'");
    return _EditShopProfileState();
  }
}

class _EditShopProfileState extends State<EditShopProfile> {

  final TextEditingController _nameController = TextEditingController();
  final List<TextEditingController> _contactControllers = [
    TextEditingController()
  ];
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  final FocusNode _aboutFocus = FocusNode();

  TimeOfDay? _monToFriStart;
  TimeOfDay? _monToFriEnd;
  TimeOfDay? _satToSunStart;
  TimeOfDay? _satToSunEnd;

  bool _loading = true;
  String? _currentUid;

  final ImagePicker _picker = ImagePicker();
  List<XFile> selectedImages = [];
  List<String> _shopImages = [];

  final String imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';
  final String imageKitPrivateKey = 'private_pWr6GTcSorJB7LBrowYhFUndHG0=';

  @override
  void initState() {
    super.initState();
    // Delay the fetch to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchShopDetails();
    });
  }

  Future<List<String>> uploadImagesToImageKit() async {
    List<String> uploadedUrls = [];
    for (XFile image in selectedImages) {
      File file = File(image.path);
      var request = http.MultipartRequest('POST', Uri.parse(imageKitUploadUrl));
      request.headers['Authorization'] =
      'Basic ${base64Encode(utf8.encode('$imageKitPrivateKey:'))}';
      request.fields['fileName'] = file.path.split('/').last;
      request.fields['useUniqueFileName'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      try {
        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final decoded = json.decode(responseData);

        if (response.statusCode == 200) {
          uploadedUrls.add(decoded['url']);
        } else {
          debugPrint("Upload failed: ${decoded['message']}");
        }
      } catch (e) {
        debugPrint("ImageKit upload error: $e");
      }
    }
    return uploadedUrls;
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var controller in _contactControllers) {
      controller.dispose();
    }
    _addressController.dispose();
    _websiteController.dispose();
    _aboutController.dispose();
    _aboutFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchShopDetails() async {
    try {
      setState(() => _loading = true);

      // Debug: Print the placeId to see what we're receiving
      debugPrint("PlaceId received: '${widget.placeId}'");
      debugPrint("PlaceId length: ${widget.placeId.length}");

      // Validate placeId
      if (widget.placeId.isEmpty) {
        setState(() => _loading = false);
        _showErrorAndNavigateBack("Invalid shop ID - placeId is empty");
        return;
      }

      debugPrint("Attempting to fetch from RegisteredShops with placeId: ${widget.placeId}");

      // Step 1: Fetch basic shop data from RegisteredShops using placeId
      DocumentSnapshot registeredShopDoc = await FirebaseFirestore.instance
          .collection('RegisteredShops')
          .doc(widget.uid)
          .get();

      debugPrint("Document exists: ${registeredShopDoc.exists}");

      if (!registeredShopDoc.exists) {
        setState(() => _loading = false);
        _showErrorAndNavigateBack("Shop not found in RegisteredShops collection");
        return;
      }

      final registeredShopData = registeredShopDoc.data() as Map<String, dynamic>;
      debugPrint("RegisteredShop data: $registeredShopData");

      // Step 2: Try to fetch existing profile details from ShopProfileDetails
      DocumentSnapshot profileDoc = await FirebaseFirestore.instance
          .collection('ShopProfileDetails')
          .doc(widget.placeId)
          .get();

      debugPrint("Profile document exists: ${profileDoc.exists}");

      Map<String, dynamic> profileData = {};
      if (profileDoc.exists) {
        profileData = profileDoc.data() as Map<String, dynamic>;
        debugPrint("Profile data: $profileData");
      }

      setState(() {
        // Get UID from registered shop data
        _currentUid = registeredShopData['ownerUid'] ?? widget.uid;


        // Basic shop information from RegisteredShops - try different field names
        _nameController.text = registeredShopData['shopName'] ?? '';
        _addressController.text = registeredShopData['address'] ?? '';


        // Contact numbers from RegisteredShops - try different field names
        String phoneNumber = registeredShopData['number'] ??
            registeredShopData['phoneNumber'] ??
            registeredShopData['contactNumber'] ?? '';

        _contactControllers.clear();
        if (phoneNumber.isNotEmpty) {
          _contactControllers.add(TextEditingController(text: phoneNumber));
        } else {
          // Try to get from array fields
          List contactNumbers = registeredShopData['contactNumbers'] ??
              registeredShopData['mobileNumbers'] ?? [];
          if (contactNumbers.isNotEmpty) {
            for (var contact in contactNumbers) {
              _contactControllers.add(TextEditingController(text: contact.toString()));
            }
          } else {
            _contactControllers.add(TextEditingController());
          }
        }

        // Additional profile data from ShopProfileDetails (if exists)
        _websiteController.text = profileData['websiteLink'] ?? '';
        _aboutController.text = profileData['aboutShop'] ?? '';

        // Load working hours if available
        if (profileData['monFriStart'] != null) {
          _monToFriStart = _parseTime(profileData['monFriStart']);
        }
        if (profileData['monFriEnd'] != null) {
          _monToFriEnd = _parseTime(profileData['monFriEnd']);
        }
        if (profileData['satSunStart'] != null) {
          _satToSunStart = _parseTime(profileData['satSunStart']);
        }
        if (profileData['satSunEnd'] != null) {
          _satToSunEnd = _parseTime(profileData['satSunEnd']);
        }

        _shopImages = List<String>.from(profileData['Images'] ?? []);

        // Add any additional contact numbers from profile
        List additionalContacts = profileData['additionalContactNumbers'] ?? [];
        for (var contact in additionalContacts) {
          _contactControllers.add(TextEditingController(text: contact));
        }
      });
    } catch (e) {
      debugPrint("Error fetching shop details: $e");
      setState(() => _loading = false);
      _showErrorAndNavigateBack("Error loading shop details: $e");
    }

    setState(() => _loading = false);
  }

  void _showErrorAndNavigateBack(String message) {
    // Use addPostFrameCallback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final format = DateFormat.jm();
      final dt = format.parse(timeStr);
      return TimeOfDay.fromDateTime(dt);
    } catch (e) {
      debugPrint("Error parsing time: $e");
      return TimeOfDay.now();
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUid == null) {
      _showSnackBar("Unable to save: User ID not found", Colors.red);
      return;
    }

    try {
      if (widget.placeId.isEmpty) {
        _showSnackBar("Invalid shop ID", Colors.red);
        return;
      }

      // Collect contacts
      final contacts = _contactControllers
          .map((c) => c.text.trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (contacts.isEmpty) {
        _showSnackBar("Please add at least one contact number", Colors.red);
        return;
      }

      setState(() => _loading = true);

      // Upload any new images added in this session
      final imageUrls = await uploadImagesToImageKit();

      final profileData = {
        'ownerUid': _currentUid,
        'placeId': widget.placeId,
        'shopName': _nameController.text.trim(),
        'shopAddress': _addressController.text.trim(),
        'primaryContactNumber': contacts.isNotEmpty ? contacts.first : null,
        'additionalContactNumbers': contacts.length > 1 ? contacts.sublist(1) : [],
        'websiteLink': _websiteController.text.trim(),
        'aboutShop': _aboutController.text.trim(),
        'numberofbarber': _numberController.text.trim(),
        'monFriStart': _monToFriStart != null ? formatTime(_monToFriStart) : null,
        'monFriEnd': _monToFriEnd != null ? formatTime(_monToFriEnd) : null,
        'satSunStart': _satToSunStart != null ? formatTime(_satToSunStart) : null,
        'satSunEnd': _satToSunEnd != null ? formatTime(_satToSunEnd) : null,
        // Images field is only for profile gallery images, shopPhotos/specialistPhotos are migrated separately
        'Images': imageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // ✅ Save full profile under ShopProfileDetails/{placeId}
      final placeIdDoc =
      firestore.collection('ShopProfileDetails').doc(widget.placeId);
      batch.set(placeIdDoc, profileData, SetOptions(merge: true));

      // ✅ Save full profile under ShopProfileDetails/{uid}
      final uidDoc =
      firestore.collection('ShopProfileDetails').doc(_currentUid);
      batch.set(uidDoc, profileData, SetOptions(merge: true));

      await batch.commit();

      // ✅ After saving profile, migrate images from RegisteredShops → ShopProfileDetails
      await _migrateImagesToShopProfileDetails(_currentUid!, widget.placeId, true);  // specialistPhotos
      await _migrateImagesToShopProfileDetails(_currentUid!, widget.placeId, false); // shopPhotos

      setState(() => _loading = false);

      _showSnackBar("Shop profile updated successfully", Colors.green);

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint("Error saving profile: $e");
      _showSnackBar("Error saving profile: $e", Colors.red);
    }
  }




  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart, bool isWeekday) async {
    // Remove focus & close keyboard
    FocusScope.of(context).requestFocus(FocusNode());

    // Delay to allow focus change to finish before opening picker
    await Future.delayed(const Duration(milliseconds: 100));

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isWeekday) {
          isStart ? _monToFriStart = picked : _monToFriEnd = picked;
        } else {
          isStart ? _satToSunStart = picked : _satToSunEnd = picked;
        }
      });
    }
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) return "--:--";
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }


  @override
  Widget build(BuildContext context) {
    const lightGrey = Color(0xFFF2F2F2);
    const mediumGreyBorder = Color(0xFFCCCCCC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Edit Shop Profile",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Shop Name
            _buildCardTextField(
              _nameController,
              "Shop Name",
              lightGrey,
            ),
            const SizedBox(height: 10),

            // Contact Numbers (Dynamic)
            ..._buildContactNumberFields(lightGrey),
            const SizedBox(height: 10),

            // Shop Address
            _buildCardTextField(
              _addressController,
              "Shop Address",
              lightGrey,
              maxLines: 2,
            ),
            const SizedBox(height: 10),

            // Website Link
            _buildCardTextField(
              _websiteController,
              "Website Link (Optional)",
              lightGrey,
            ),
            const SizedBox(height: 10),

            // About Shop
            _buildCardTextField(
              _aboutController,
              "About Your Shop (Optional)",
              lightGrey,
              maxLines: 6,
              focusNode: _aboutFocus,
            ),
            const SizedBox(height: 20),

            // Working Hours
            _buildTimeSection(
              "Mon - Fri",
              _monToFriStart,
              _monToFriEnd,
              true,
              lightGrey,
              mediumGreyBorder,
            ),
            const SizedBox(height: 10),
            _buildTimeSection(
              "Sat - Sun",
              _satToSunStart,
              _satToSunEnd,
              false,
              lightGrey,
              mediumGreyBorder,
            ),
            SizedBox(height: 10),
            _buildPhotoSection("Add Photos", lightGrey, mediumGreyBorder, false),
            _buildPhotoSection("Add Photos of your Specialists", lightGrey, mediumGreyBorder,true),
            const SizedBox(height: 15),
            Align(alignment: Alignment.centerLeft,
              child: Text("Enter Number Of Barber",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16),),),
            _buildCardTextField(
                _numberController,
                "Number of Barber",
                lightGrey),
            const SizedBox(height: 20),
            // Manage Services
            ListTile(
              leading: const Icon(Icons.build, color: Colors.orange),
              title: const Text(
                "Manage Services",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Services(placeId: widget.placeId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                "Update",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTextField(
      TextEditingController controller,
      String hintText,
      Color bgColor, {
        int maxLines = 1,
        FocusNode? focusNode,
      }) {
    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContactNumberFields(Color bgColor) {
    List<Widget> fields = [];
    for (int i = 0; i < _contactControllers.length; i++) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: _buildCardTextField(
                  _contactControllers[i],
                  "Contact Number ${i + 1}",
                  bgColor,
                ),
              ),
              if (i == _contactControllers.length - 1 && _contactControllers.length < 5)
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.orange),
                  onPressed: () {
                    setState(() {
                      _contactControllers.add(TextEditingController());
                    });
                  },
                ),
              if (_contactControllers.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _contactControllers[i].dispose();
                      _contactControllers.removeAt(i);
                    });
                  },
                ),
            ],
          ),
        ),
      );
    }
    return fields;
  }

  Widget _buildTimeSection(
      String label,
      TimeOfDay? start,
      TimeOfDay? end,
      bool isWeekday,
      Color bgColor,
      Color borderColor,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectTime(context, true, isWeekday),
                style: OutlinedButton.styleFrom(
                  backgroundColor: bgColor,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  "Start: ${formatTime(start)}",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectTime(context, false, isWeekday),
                style: OutlinedButton.styleFrom(
                  backgroundColor: bgColor,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  "End: ${formatTime(end)}",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoSection(
      String title, Color bgColor, Color borderColor, bool isSpecialist) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        /// ✅ Listen to both ShopProfileDetails and RegisteredShops
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ShopProfileDetails')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            final shopDetailsExists = snapshot.hasData && snapshot.data!.exists;
            final shopDetailsData =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('RegisteredShops')
                  .doc(uid)
                  .snapshots(),
              builder: (context, regSnap) {
                final registeredData =
                    regSnap.data?.data() as Map<String, dynamic>? ?? {};

                // ✅ Use ShopProfileDetails images if doc exists, else fallback to RegisteredShops
                final images = List<String>.from(
                  shopDetailsExists
                      ? shopDetailsData[isSpecialist
                      ? 'specialistPhotos'
                      : 'shopPhotos'] ??
                      []
                      : registeredData[isSpecialist
                      ? 'specialistPhotos'
                      : 'shopPhotos'] ??
                      [],
                );

                final placeId = shopDetailsData['placeId'] ?? "";

                return SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length + 1,
                    itemBuilder: (context, index) {
                      if (index == images.length) {
                        // ➕ Add new photo container
                        return GestureDetector(
                          onTap: () async {
                            final picked =
                            await _picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              File file = File(picked.path);
                              var request = http.MultipartRequest(
                                  'POST', Uri.parse(imageKitUploadUrl));
                              request.headers['Authorization'] =
                              'Basic ${base64Encode(utf8.encode('$imageKitPrivateKey:'))}';
                              request.fields['fileName'] =
                                  file.path.split('/').last;
                              request.fields['useUniqueFileName'] = 'true';
                              request.files.add(await http.MultipartFile.fromPath(
                                  'file', file.path));

                              try {
                                final response = await request.send();
                                final responseData =
                                await response.stream.bytesToString();
                                final decoded = json.decode(responseData);

                                if (response.statusCode == 200) {
                                  final newUrl = decoded['url'];
                                  final fieldName = isSpecialist
                                      ? 'specialistPhotos'
                                      : 'shopPhotos';

                                  final updateData = {
                                    fieldName: FieldValue.arrayUnion([newUrl]),
                                  };

                                  if (shopDetailsExists) {
                                    // ✅ Save under ShopProfileDetails
                                    await FirebaseFirestore.instance
                                        .collection('ShopProfileDetails')
                                        .doc(uid)
                                        .set(updateData, SetOptions(merge: true));

                                    if (placeId.isNotEmpty) {
                                      await FirebaseFirestore.instance
                                          .collection('ShopProfileDetails')
                                          .doc(placeId)
                                          .set(updateData, SetOptions(merge: true));
                                    }
                                  } else {
                                    // ✅ Save under RegisteredShops if profile not built yet
                                    await FirebaseFirestore.instance
                                        .collection('RegisteredShops')
                                        .doc(uid)
                                        .set(updateData, SetOptions(merge: true));
                                  }
                                }
                              } catch (e) {
                                debugPrint("Upload error: $e");
                              }
                            }
                          },
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.add_a_photo,
                                  color: Colors.orange, size: 28),
                            ),
                          ),
                        );
                      }

                      // 🖼 Existing uploaded image with ❌ remove button
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: NetworkImage(images[index]),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  final fieldName = isSpecialist
                                      ? 'specialistPhotos'
                                      : 'shopPhotos';

                                  if (shopDetailsExists) {
                                    // remove from ShopProfileDetails
                                    await FirebaseFirestore.instance
                                        .collection('ShopProfileDetails')
                                        .doc(uid)
                                        .update({
                                      fieldName:
                                      FieldValue.arrayRemove([images[index]])
                                    });

                                    if (placeId.isNotEmpty) {
                                      await FirebaseFirestore.instance
                                          .collection('ShopProfileDetails')
                                          .doc(placeId)
                                          .update({
                                        fieldName: FieldValue.arrayRemove(
                                            [images[index]])
                                      });
                                    }
                                  } else {
                                    // remove from RegisteredShops
                                    await FirebaseFirestore.instance
                                        .collection('RegisteredShops')
                                        .doc(uid)
                                        .update({
                                      fieldName:
                                      FieldValue.arrayRemove([images[index]])
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _migrateImagesToShopProfileDetails(String uid, String placeId, bool isSpecialist) async {
    final regDoc = await FirebaseFirestore.instance
        .collection('RegisteredShops')
        .doc(uid)
        .get();

    if (regDoc.exists) {
      final registeredData = regDoc.data() ?? {};
      final fieldName = isSpecialist ? 'specialistPhotos' : 'shopPhotos';
      final images = List<String>.from(registeredData[fieldName] ?? []);

      if (images.isNotEmpty) {
        final updateData = {fieldName: images};

        // ✅ Create ShopProfileDetails with the existing RegisteredShops images
        await FirebaseFirestore.instance
            .collection('ShopProfileDetails')
            .doc(uid)
            .set(updateData, SetOptions(merge: true));

        if (placeId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('ShopProfileDetails')
              .doc(placeId)
              .set(updateData, SetOptions(merge: true));
        }
      }
    }
  }

}
