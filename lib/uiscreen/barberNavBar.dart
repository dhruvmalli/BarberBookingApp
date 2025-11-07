import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_sem7/owner/owner_main_screen.dart';
import 'package:project_sem7/owner/shop_preview.dart';
import 'settings.dart';

class NavBar extends StatefulWidget {
  final int initialIndex;

  const NavBar({super.key, this.initialIndex = 0});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  late int _selectedIndex;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _uid = FirebaseAuth.instance.currentUser?.uid; // ✅ Get logged-in UID
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OwnerMainScreen(),
      _uid != null
          ? ShopPreview(uid: _uid!)
          : const Center(child: Text("Please login to see preview")),
      const Settings(),
    ];

    return Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey[700],
            onTap: _onNavTap,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.preview), label: "Preview"),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
            ],
            ),
        );
    }
}