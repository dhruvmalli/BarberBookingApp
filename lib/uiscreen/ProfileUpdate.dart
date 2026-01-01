import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project_sem7/Notification%20Services/NotificationServicesCustomer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'StartingPage.dart';

class Profileupdate extends StatefulWidget {
  const Profileupdate({super.key});

  @override
  State<Profileupdate> createState() => _ProfileupdateState();
}

class _ProfileupdateState extends State<Profileupdate> {
  int _selectedAvatarIndex = 0;
  bool _showAvatarSelector = false;
  String? _userEmail;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobilenoController = TextEditingController();
  Notificationservicescustomer notificationservicescustomer = Notificationservicescustomer();

  final List<String> _avatars = [
    'assets/images/avatar1.png',
    'assets/images/avatar2.png',
    'assets/images/avatar3.png',
    'assets/images/avatar4.png',
    'assets/images/avatar5.png',
    'assets/images/avatar6.png',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
    _loadSelectedAvatar();
    _fetchProfileData();
  }

  Future<void> _fetchUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
      });
    }
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAvatarIndex = prefs.getInt('selectedAvatarIndex') ?? 0;
    });
  }

  Future<void> _saveSelectedAvatar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedAvatarIndex', index);
  }

  Future<void> _fetchProfileData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('ProfileDetail').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _mobilenoController.text = data['mobile'] ?? '';
        final avatarUrl = data['avatar'] ?? '';
        final avatarIndex = _avatars.indexOf(avatarUrl);
        if (avatarIndex != -1) {
          setState(() {
            _selectedAvatarIndex = avatarIndex;
          });
        }
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = {
      'name': _nameController.text.trim(),
      'mobile': _mobilenoController.text.trim(),
      'email': _userEmail ?? '',
      'avatar': _avatars[_selectedAvatarIndex],
      'timestamp': FieldValue.serverTimestamp(),
    };

    final firestore = FirebaseFirestore.instance;

    try {
      // Use batch to update both collections at once
      final batch = firestore.batch();

      final profileRef = firestore.collection('ProfileDetail').doc(uid);

      batch.update(profileRef, data);

      await batch.commit();

      // Save locally in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _nameController.text.trim());
      await prefs.setInt('selectedAvatarIndex', _selectedAvatarIndex);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(onPressed: (){
            Navigator.pop(context);
          }, icon: Icon(Icons.arrow_back,color: Colors.black)),
          backgroundColor: Colors.white,
          title: const Text("Profile", style: TextStyle(color: Colors.black)),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 30.h),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAvatarSelector = !_showAvatarSelector;
                    });
                  },
                  child: Center(
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF6EC6FF),
                      radius: 60.r,
                      backgroundImage: AssetImage(_avatars[_selectedAvatarIndex]),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                if (_showAvatarSelector)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _avatars.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                      ),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAvatarIndex = index;
                              _showAvatarSelector = false;
                            });
                            _saveSelectedAvatar(index);
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF6EC6FF),
                                radius: 40.r,
                                backgroundImage: AssetImage(_avatars[index]),
                              ),
                              if (_selectedAvatarIndex == index)
                                Container(
                                  width: 80.r,
                                  height: 80.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.orange, width: 3.w),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 30.h),
                _buildTextField(_nameController, "Enter Name", Icons.person),
                SizedBox(height: 10.h),
                _buildTextField(_mobilenoController, "Enter Mobile No", Icons.phone, isPhone: true),
                SizedBox(height: 10.h),
                _buildDisabledEmailField(),
                SizedBox(height: 40.h),
                SizedBox(
                  height: 40.h,
                  width: 320.w,
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                    child: Text(
                      "Update",
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(height: 40.h, width: 320.w,
                child: ElevatedButton(onPressed: () async {
                  notificationservicescustomer.removeTokenOnLogout();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_logged_in', false);
                  await prefs.setString('user_type', 'customer');
                  Navigator.push(context, MaterialPageRoute(builder: (context) => Startingpage()));
                },style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                ),
                    child: Text("Sign Out", style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold),)),)
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPhone = false}) {
    return SizedBox(
      height: 50.h,
      width: 320.w,
      child: TextFormField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return isPhone ? "Please enter your mobile number" : "Please enter your name";
          }
          if (isPhone && !RegExp(r'^\d{10}$').hasMatch(value.trim())) {
            return "Mobile number must be 10 digits";
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: Icon(icon, color: Colors.black),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(10.r),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black, width: 2.w),
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledEmailField() {
    return Container(
      height: 50.h,
      width: 320.w,
      child: TextFormField(
        initialValue: _userEmail ?? "",
        enabled: false,
        readOnly: true,
        style: TextStyle(fontSize: 15.sp, color: Colors.black),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.email, color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9.r))),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(9.r)),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 10.w),
        ),
      ),
    );
  }
}
