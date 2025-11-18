import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project_sem7/Services.dart';
import 'package:project_sem7/uiscreen/DashboardScreen.dart';
import 'package:project_sem7/uiscreen/ForgetPassword.dart';
import 'package:project_sem7/uiscreen/NavBar.bart.dart';
import 'package:project_sem7/uiscreen/Signupowner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottom_nav_bar.dart';

class Loginowner extends StatefulWidget {
  const Loginowner({super.key});

  @override
  State<Loginowner> createState() => _LoginStateowner();
}

class _LoginStateowner extends State<Loginowner> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? emailError;
  String? passwordError;
  String? _authErrorMessage;

  void validateFields() {
    setState(() {
      emailError = _emailController.text.isEmpty
          ? "Please enter your email"
          : (!_emailController.text.contains("@gmail.com")
          ? "Please enter valid email"
          : null);
      passwordError = _passwordController.text.isEmpty
          ? "Please enter your password"
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 80.h),
              Padding(
                padding: EdgeInsets.only(left: 23.w),
                child: Text(
                  "Login to your Account",
                  style: TextStyle(
                      fontSize: 45.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ),
              SizedBox(height: 40.h),

              // Email
              CustomTextField(
                controller: _emailController,
                hint: "Enter Email",
                icon: Icons.email,
                errorMessage: emailError,
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
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.black,
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.only(left: 200.w),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Forgetpassword()),
                    );
                  },
                  child: Text(
                    "Forget Password?",
                    style:
                    TextStyle(color: Colors.orange, fontSize: 15.sp),
                  ),
                ),
              ),

              if (_authErrorMessage != null)
                Padding(
                  padding: EdgeInsets.only(top: 15.h),
                  child: Text(
                    _authErrorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14.sp),
                  ),
                ),

              SizedBox(height: 40.h),

              // Login Button
              SizedBox(
                height: 40.h,
                width: 320.w,
                child: ElevatedButton(
                  onPressed: () async {
                    validateFields();
                    if (emailError == null && passwordError == null) {
                      try {
                        UserCredential userCredential =
                        await FirebaseAuth.instance
                            .signInWithEmailAndPassword(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        );

                        final user = userCredential.user;
                        if (user == null) {
                          setState(() => _authErrorMessage =
                          "Login failed. Please try again.");
                          return;
                        }

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_logged_in', true);
                        await prefs.setString('user_type', 'owner');

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const NavBar(),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String message = '';
                        if (e.code == 'invalid-credential' ||
                            e.code == 'wrong-password') {
                          message = "Wrong email or password.";
                        } else if (e.code == 'user-not-found') {
                          message = "User not found.";
                        } else {
                          message = 'Login failed: ${e.message}';
                        }
                        setState(() => _authErrorMessage = message);
                      } catch (e) {
                        setState(() => _authErrorMessage =
                        'An error occurred. Please try again.');
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
                    "Login",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const Signupowner()));
                },
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: "Don't have an account?",
                        style: TextStyle(
                            fontSize: 14.sp, color: Colors.black)),
                    TextSpan(
                        text: " Sign Up",
                        style: TextStyle(
                            color: Colors.orange, fontSize: 14.sp)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomTextField (same as Signup)
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
