import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project_sem7/uiscreen/Profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottom_nav_bar.dart';

class Signupowner extends StatefulWidget {
  const Signupowner({super.key});

  @override
  State<Signupowner> createState() => _SignupownerState();
}

class _SignupownerState extends State<Signupowner> with RouteAware {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();

  bool _isPasswordVisible = false;
  //bool _ownerRole = true;

  String? nameError;
  String? emailError;
  String? mobileError;
  String? passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  void validateFields() {
    setState(() {
      nameError = _nameController.text.isEmpty ? "Please enter your name" : null;
      emailError = _emailController.text.isEmpty
          ? "Please enter the email"
          : (!_emailController.text.contains("@gmail.com")
          ? "Please enter valid email"
          : null);
      mobileError = _mobileNumberController.text.isEmpty
          ? "Please enter your mobile number"
          : (!RegExp(r'^\d{10}$').hasMatch(_mobileNumberController.text)
          ? "Enter a valid 10-digit number"
          : null);
      passwordError = _passwordController.text.isEmpty
          ? "Please enter the password"
          : (_passwordController.text.length < 6
          ? "Password must be at least 6 characters"
          : (!RegExp(r'[A-Za-z]').hasMatch(_passwordController.text)
          ? "Password must contain a letter"
          : (!RegExp(r'\d').hasMatch(_passwordController.text)
          ? "Password must contain a number"
          : null)));
    });
  }

  // NEW METHOD: Save manual signup data to Firestore
  Future<void> _saveManualSignupToFirestore(String uid) async {
    try {
      final data = {
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileNumberController.text.trim(),
        'signupMethod': 'manual', // To differentiate from Google signup
        'timestamp': FieldValue.serverTimestamp(),
        'isProfileCompleted': false, // They need to complete profile next
        'ownerRole' : true,
      };

      // Save to OwnerSignupDetails collection
      await FirebaseFirestore.instance
          .collection('OwnerSignupDetails')
          .doc(uid)
          .set(data);

      print('Manual signup data saved to OwnerSignupDetails');
    } catch (e) {
      print('Error saving manual signup data: $e');
      // Still continue to profile page even if this fails
    }
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 80.h,),
              Padding(
                padding: const EdgeInsets.only(left: 23),
                child: Text(
                  "Create Owner Account",
                  style: TextStyle(fontSize: 45.sp, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 40.h),

              // Name
              CustomTextField(
                controller: _nameController,
                hint: "Enter Name",
                icon: Icons.person,
                errorMessage: nameError,
              ),
              SizedBox(height: 10.h),

              // Email
              CustomTextField(
                controller: _emailController,
                hint: "Enter Email",
                icon: Icons.email,
                errorMessage: emailError,
              ),
              SizedBox(height: 10.h),

              // Mobile
              CustomTextField(
                controller: _mobileNumberController,
                hint: "Enter Mobile Number",
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                errorMessage: mobileError,
              ),
              SizedBox(height: 10.h),

              // Password
              CustomTextField(
                controller: _passwordController,
                hint: "Enter Password",
                icon: Icons.lock,
                obscureText: !_isPasswordVisible,
                errorMessage: passwordError,
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  }),
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              SizedBox(
                height: 40.h,
                width: 320.w,
                child: ElevatedButton(
                  onPressed: () async {
                    validateFields();
                    if (nameError == null &&
                        emailError == null &&
                        mobileError == null &&
                        passwordError == null) {
                      try {
                        // Create Firebase Auth user
                        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        );

                        final String uid = userCredential.user?.uid ?? '';

                        // MODIFIED: Save manual signup data to CustomerSignupDetails
                        await _saveManualSignupToFirestore(uid);

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const Profile()),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Signup failed: ${e.message}")),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                  child: Text(
                    "Sign up",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable custom text field widget
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? errorMessage;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.errorMessage,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50.h,
      width: 320.w,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: errorMessage ?? hint,
          hintStyle: TextStyle(
            color: errorMessage != null ? Colors.red : Colors.grey,
          ),
          prefixIcon:
          Icon(icon, color: errorMessage != null ? Colors.red : Colors.black),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey.shade50,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: errorMessage != null ? Colors.red : Colors.grey),
            borderRadius: BorderRadius.circular(10.r),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: errorMessage != null ? Colors.red : Colors.black,
                width: 2.w),
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
      ),
    );
  }
}
