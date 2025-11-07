import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project_sem7/uiscreen/ProfileUpdate.dart';
import '../uiscreen/notification.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  final firestore = FirebaseFirestore.instance;
  final Set<String> processedBookings = {};

  String _getGreetingMessage(String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;

    if (hour >= 5 && hour < 12) {
      greeting = "Morning";
      emoji = "🌅";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Afternoon";
      emoji = "☀";
    } else if (hour >= 17 && hour < 21) {
      greeting = "Evening";
      emoji = "🌇";
    } else {
      greeting = "Night";
      emoji = "🌙";
    }
    return "$greeting, ${_capitalize(userName)} $emoji";
  }

  String _capitalize(String name) {
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<String?> _getShopOwnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final shopDoc =
    await firestore.collection("RegisteredShops").doc(user.uid).get();
    if (!shopDoc.exists) return null;

    return shopDoc.id;
  }

  Future<void> _updateBookingStatus(
      String docId, String bookingId, bool accepted) async {
    try {
      final bookingDocRef = firestore.collection("BookedSlots").doc(docId);
      final snapshot = await bookingDocRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final allowedUserIds = List<String>.from(data['allowedUserIds'] ?? []);

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      if (!allowedUserIds.contains(currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("You are not authorized to update this booking")),
        );
        return;
      }

      List bookings = List.from(data['bookings'] ?? []);
      int ownerBookingIndex =
      bookings.indexWhere((b) => (b['bookingId'] ?? "") == bookingId);

      if (ownerBookingIndex == -1) return;

      bookings[ownerBookingIndex]['status'] = accepted;
      final booking = Map<String, dynamic>.from(bookings[ownerBookingIndex]);

      await bookingDocRef.update({
        'bookings': bookings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => processedBookings.add(bookingId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text(accepted ? "Booking Accepted ✅" : "Booking Declined ❌")),
      );

      // Continue updating in user's document if accepted
      final userId = booking['userId'] as String;
      final userDocRef = firestore.collection("BookedSlots").doc(userId);

      final userSnapshot = await userDocRef.get();
      if (!userSnapshot.exists) return;

      final userData = userSnapshot.data()!;
      List userBookings = List.from(userData['bookings'] ?? []);

      int userBookingIndex =
      userBookings.indexWhere((b) => (b['bookingId'] ?? "") == bookingId);

      if (userBookingIndex != -1) {
        userBookings[userBookingIndex]['status'] = accepted;
        await userDocRef.update({
          'bookings': userBookings,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error updating booking status: $e");
    }
  }


  Future<void> _updateArrivalStatus(
      String docId, String bookingId, bool accepted) async {
    try {
      final bookingDocRef = firestore.collection("BookedSlots").doc(docId);
      final snapshot = await bookingDocRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final allowedUserIds = List<String>.from(data['allowedUserIds'] ?? []);

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      if (!allowedUserIds.contains(currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You are not authorized to update this booking"),
          ),
        );
        return;
      }

      // ✅ Update booking for owner
      List bookings = List.from(data['bookings'] ?? []);
      int ownerBookingIndex =
      bookings.indexWhere((b) => (b['bookingId'] ?? "") == bookingId);

      if (ownerBookingIndex == -1) return;

      bookings[ownerBookingIndex]['arrived'] = accepted;
      final booking = Map<String, dynamic>.from(bookings[ownerBookingIndex]);

      await bookingDocRef.update({
        'bookings': bookings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => processedBookings.add(bookingId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? "Customer has been visited ✅"
                : "Customer not on time ❌",
          ),
        ),
      );

      // ✅ Mirror update on customer side
      final userId = booking['userId'] as String;
      final userDocRef = firestore.collection("BookedSlots").doc(userId);

      final userSnapshot = await userDocRef.get();
      if (!userSnapshot.exists) return;

      final userData = userSnapshot.data()!;
      List userBookings = List.from(userData['bookings'] ?? []);

      int userBookingIndex =
      userBookings.indexWhere((b) => (b['bookingId'] ?? "") == bookingId);

      if (userBookingIndex != -1) {
        userBookings[userBookingIndex]['arrived'] = accepted;
        await userDocRef.update({
          'bookings': userBookings,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // ✅ Missed visits logic
      int missedCount = userData['missedCount'] ?? 0;
      const int maxMissed = 2;

      if (!accepted) {
        missedCount++;

        if (missedCount >= maxMissed) {
          // 🚫 Block account on 2nd miss
          await userDocRef.update({
            'missedCount': missedCount,
            'blocked': true,
          });

          await userDocRef.update({
            'title': "Account Blocked 🚫",
            'body':
            "Your account has been blocked because you missed $missedCount visits.",
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else if (missedCount == maxMissed - 1) {
          // ⚠️ Send final warning on 1st miss
          await userDocRef.update({'missedCount': missedCount});

          await userDocRef.update({
            'title': "Final Warning ⚠️",
            'body':
            "This is your last chance! If you miss another visit, your account will be blocked.",
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // ✅ Reset missed count if the user arrived
        await userDocRef.update({'missedCount': 0});
      }
    } catch (e) {
      debugPrint("Error updating booking status: $e");
    }
  }

  int _extractSlotStart(String? slot) {
    if (slot == null || slot.isEmpty) return 0;
    try {
      // Expect format like "8-9", "09-10"
      final parts = slot.split("-");
      return int.tryParse(parts[0].trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 30,
                  width: 30,
                  child: Image.asset(
                      "assets/images/WhatsApp_Image_2025-07-11_at_20.05.12_409f80dc-removebg-preview.png"),
                ),
                const SizedBox(width: 10),
                const Text(
                  "FreshCut",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Profileupdate()));
                  },
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ProfileDetail')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final userName = snapshot.data!['name'] ?? '';
                return Text(
                  _getGreetingMessage(userName),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                );
              },
            )
          ],
        ),
      ),
      body: FutureBuilder<String?>(
        future: _getShopOwnerUid(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No shop registered for this user"));
          }

          final ownerUid = snapshot.data!;
          return StreamBuilder<DocumentSnapshot>(
            stream:
            firestore.collection("BookedSlots").doc(ownerUid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.data() == null) {
                return const Center(child: Text("No bookings found"));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final bookings =
              (data['bookings'] as List<dynamic>? ?? []).reversed.toList();

              if (bookings.isEmpty) {
                return const Center(child: Text("No bookings available"));
              }

              final today = DateTime.now();
              final todayStr =
                  "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

              final todayAccepted = bookings.where((b) {
                final booking = b as Map<String, dynamic>;
                return booking['date'] == todayStr && booking['status'] == true;
              }).toList();

              todayAccepted.sort((a, b) =>
                  _extractSlotStart(a['slot']).compareTo(_extractSlotStart(b['slot'])));

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length + 1, // extra slot for summary
                      itemBuilder: (context, index) {
                        if (index == bookings.length) {
                          // 🔹 Today's Accepted Bookings (sorted correctly)
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Today's Accepted Bookings",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (todayAccepted.isEmpty)
                                const Text("No accepted bookings yet",
                                    style: TextStyle(color: Colors.grey)),
                              ...todayAccepted.map((b) {
                                final booking = b as Map<String, dynamic>;
                                final profile =
                                (booking['profile'] ?? {}) as Map<String, dynamic>;

                                return Card(
                                  color: Colors.white,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: const Icon(Icons.person,
                                        color: Colors.orange),
                                    title: Text(
                                      profile['name'] ?? "No Name",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(profile['mobile'] ?? "No Phone"),
                                        Text("Slot: ${booking['slot'] ?? "-"}"),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }

                        // 🔹 Other bookings section (unchanged)
                        final booking =
                        bookings[index] as Map<String, dynamic>;
                        final bookingId =
                            "${booking['slot']}-${booking['date']}-${booking['userId']}";
                        final profile =
                            booking['profile'] as Map<String, dynamic>? ?? {};
                        final services =
                            booking['services'] as List<dynamic>? ?? [];
                        final bool? status = booking['status'];
                        final bool? arrived = booking['arrived'];

                        final showAcceptDeclineButtons =
                            !processedBookings.contains(bookingId) &&
                                status == null;
                        final showArrivalButtons =
                            status == true && arrived == null;

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: profile['avatar'] != null
                                          ? NetworkImage(profile['avatar'])
                                          : const AssetImage(
                                          "assets/images/avatar1.png")
                                      as ImageProvider,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(profile['name'] ?? "No Name",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text(profile['mobile'] ?? "No Phone",
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                        Text(profile['email'] ?? "No Email",
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(booking['slot'] ?? "-",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.calendar_today,
                                        size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(booking['date'] ?? "-",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: services.map<Widget>((s) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                          "${s['name']} - ₹${s['price']}",
                                          style:
                                          const TextStyle(fontSize: 12)),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                Text("Total: ₹${booking['totalPrice'] ?? 0}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                if (showAcceptDeclineButtons) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _updateBookingStatus(
                                                  ownerUid,
                                                  booking['bookingId'],
                                                  true),
                                          child: const Text("Accept",
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _updateBookingStatus(
                                                  ownerUid,
                                                  booking['bookingId'],
                                                  false),
                                          child: const Text("Decline",
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (showArrivalButtons) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _updateArrivalStatus(
                                                  ownerUid, booking['bookingId'], true),
                                          child: const Text("Customer visited",
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _updateArrivalStatus(
                                                  ownerUid, booking['bookingId'], false),
                                          child: const Text("Not on time",
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (status != null) ...[
                                  Text(
                                    arrived == true
                                        ? "Customer has been visited ✅"
                                        : arrived == false
                                        ? "Customer not on time ❌"
                                        : status
                                        ? "Booking Accepted ✅"
                                        : "Booking Declined ❌",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: arrived == true
                                          ? Colors.green
                                          : arrived == false
                                          ? Colors.red
                                          : status
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
