import 'package:flutter/material.dart';
import 'package:project_sem7/booking/booked_slot.dart';
import '../shop_profile/edit_shop_profile.dart';
import '../shop_profile/shop_profile.dart';
import 'liked_shops.dart';
import 'location_and_barber_shop.dart';
import 'main_home_page.dart';
import 'my_booking_page.dart';
import 'settings.dart';

class BottomNavBar extends StatefulWidget {
  final int initialIndex;

  const BottomNavBar({super.key, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex;

  final List<Widget> _pages = const [
    MainHomePage(),
    BookedSlot(),
    LocationAndBarberShop(),
    LikedShops(),
    Settings(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey[700],
            onTap: _onNavTap,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Booked"),
              BottomNavigationBarItem(icon: Icon(Icons.location_on), label: "Near shop"),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Liked shop"),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
            ],
          ),
        ],
      ),

    );
  }
}
