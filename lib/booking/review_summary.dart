import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project_sem7/Notification%20Services/NotificationServicesCustomer.dart';
import 'package:project_sem7/Notification%20Services/NotificationServicesOwner.dart';
import 'package:project_sem7/models/shop_profile_model.dart';
import 'package:project_sem7/uiscreen/main_home_page.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/booking_provider.dart';
import '../widgets/bottom_action_button.dart';

class ReviewSummary extends StatefulWidget {
  const ReviewSummary({super.key});

  @override
  State<ReviewSummary> createState() => _ReviewSummaryState();
}

class _ReviewSummaryState extends State<ReviewSummary> {
  Notificationservicescustomer notificationservicescustomer = Notificationservicescustomer();
  bool _isLoading = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    notificationservicescustomer.firebaseInit(context);
    notificationservicescustomer.setupInteractMessage(context);
  }

  Future<void> _confirmBooking() async {
    final provider = context.read<BookingProvider>();
    final user = FirebaseAuth.instance.currentUser;
    notificationservicescustomer.getDeviceToken().then((value){

    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    if (!provider.isBookingComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking data is incomplete")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bookingData = provider.getBookingData(user.uid);
      final firestore = FirebaseFirestore.instance;

      // Fetch user profile
      final userDoc =
      await firestore.collection("ProfileDetail").doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final userProfile = {
        "name": userData['name'] ?? "No Name",
        "email": userData['email'] ?? user.email ?? "No Email",
        "mobile": userData['mobile'] ?? "No Phone",
        "deviceToken": userData['deviceToken'] ?? "No Device Token"
      };

      // 👇 Create allowedUserIds with both customer & barber
      final allowedUserIds = [user.uid, provider.barber!.ownerUid];

      // 👇 Generate unique bookingId
      final bookingId =
          "${user.uid}_${bookingData['placeId']}_${bookingData['slot']}_${bookingData['date']}";

      // Booking map for barber doc
      final bookingForBarber = {
        ...bookingData,
        "profile": userProfile,
        "status": null, // pending by default
        "allowedUserIds": allowedUserIds,
        "bookingId": bookingId, // ✅ added bookingId
      };

      // Booking map for user doc
      final bookingForUser = {
        ...bookingData,
        "status": null, // pending by default
        "allowedUserIds": allowedUserIds,
        "bookingId": bookingId, // ✅ added bookingId
      };

      // Save under Barber's document
      await firestore
          .collection("BookedSlots")
          .doc(provider.barber!.ownerUid)
          .set({
        "ownerUid": provider.barber!.ownerUid,
        "shopName": provider.barber!.name,
        "bookings": FieldValue.arrayUnion([bookingForBarber]),
        "allowedUserIds": allowedUserIds, // 👈 added here
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save under User's document
      await firestore.collection("BookedSlots").doc(user.uid).set({
        "userId": user.uid,
        "user": userProfile,
        "bookings": FieldValue.arrayUnion([bookingForUser]),
        "allowedUserIds": allowedUserIds, // 👈 added here
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      provider.clearBooking();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking confirmed successfully!"),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print("❌ Error confirming booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to confirm booking. Please try again."),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        if (!provider.isBookingComplete) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                "Review Summary",
                style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            ),
            body: const Center(
              child: Text(
                  "No booking data found. Please go back and complete your booking."),
            ),
          );
        }

        final barber = provider.barber!;
        final selectedBarber = provider.selectedBabberId;
        final services = provider.selectedServices;
        final selectedDate = provider.selectedDate!;
        final selectedSlot = provider.selectedSlot!;
        final totalPrice = provider.totalPrice;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Review Summary",
              style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barber/Salon Details Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                                title: "Salon Name",
                                value: barber.name ?? "Unknown Salon"),
                            _DetailRow(
                                title: "Address",
                                value: barber.address ?? "No address provided"),
                            _DetailRow(
                                title: "Name",
                                value: selectedBarber.toString()),
                            _DetailRow(
                                title: "Booking Date",
                                value: DateFormat('MMMM dd, yyyy')
                                    .format(selectedDate)),
                            _DetailRow(
                                title: "Booking Slot", value: selectedSlot),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Services Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ...services.map((service) => _PriceRow(
                              service: service['name'],
                              price: "₹${service['price']}",
                            )),
                            const Divider(thickness: 1),
                            _PriceRow(
                                service: "Total",
                                price: "₹$totalPrice",
                                isTotal: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 252), // space for bottom button
                    ],
                  ),
                ),
              ),

              // Fixed bottom button
              BottomActionButton(
                text: _isLoading ? "Booking..." : "Book Now",
                onPressed: _isLoading ? () {} : () => _confirmBooking(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Reusable row for details
class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable row for services with prices
class _PriceRow extends StatelessWidget {
  final String service;
  final String price;
  final bool isTotal;

  const _PriceRow({
    required this.service,
    required this.price,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            service,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
