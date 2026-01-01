import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mearge_barber_model.dart';
import '../providers/booking_provider.dart';
import 'review_summary.dart';

class BookNowPage extends StatefulWidget {
  final MergedBarber barber;

  const BookNowPage({super.key, required this.barber});

  @override
  State<BookNowPage> createState() => _BookNowPageState();
}

class _BookNowPageState extends State<BookNowPage> {
  late List<Map<String, dynamic>> services;
  late List<Map<String, dynamic>> barbersname;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int selectedTimeIndex = -1;
  List<String> timeSlots = [];
  Set<String> bookedSlots = {}; // Already booked slots
  Map<String, dynamic>? selectedBarber;

  late String? monFriStart;
  late String? monFriEnd;
  late String? satSunStart;
  late String? satSunEnd;

  String _getImagePath(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return "assets/images/image1.jpg";
    }
    return "assets/images/$fileName";
  }

  String _mapServiceToImage(String name) {
    switch (name.toLowerCase()) {
      case "haircut":
        return "image3.jpg";
      case "shave":
        return "image2.jpg";
      case "trim":
        return "image5.jpeg";
      case "facial":
        return "image4.jpg";
      case "hair spa":
        return "image6.jpeg";
      default:
        return "image1.jpg";
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize services
    final rawServices = widget.barber.services ?? [];
    services = rawServices.map((s) {
      final serviceName = s["service"]?.toString() ?? "";
      final priceValue = s["price"]?.toString() ?? "0";
      final timeValue = s["time"]?.toString() ?? "0";

      return {
        "name": serviceName,
        "price": int.tryParse(priceValue) ?? 0,
        "time": timeValue,           // <--- FIXED HERE
        "selected": false,
        "image": _mapServiceToImage(serviceName),
      };
    }).toList();

    final rawBarber = widget.barber.barbers ?? [];
    barbersname = rawBarber.map((q) {
      final barberName = q["name"]?.toString() ?? "";
      final barberPhoneNumber = q["number"]?.toString() ?? "";

      return{
        "name": barberName,
        "number": barberPhoneNumber
      };
    }).cast<Map<String, dynamic>>().toList();

    // Working hours
    monFriStart = widget.barber.monFriStart;
    monFriEnd = widget.barber.monFriEnd;
    satSunStart = widget.barber.satSunStart;
    satSunEnd = widget.barber.satSunEnd;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().setBarber(widget.barber);
    });
  }

  TimeOfDay _parseTime(String time) {
    final df = DateFormat.jm(); // "h:mm a"
    final dt = df.parse(time);
    return TimeOfDay.fromDateTime(dt);
  }

  int _extractMinutes(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match != null) {
      return int.parse(match.group(0)!);
    }
    return 0;
  }

  int _getTotalServiceMinutes() {
    int total = 0;

    for (var s in services.where((e) => e["selected"] == true)) {
      final minutes = _extractMinutes(s["time"].toString());
      debugPrint("Service time: ${s["time"]} → $minutes");
      total += minutes;
    }

    debugPrint("Total minutes: $total");
    return total;
  }

  /// Fetch already booked slots for the selected barber & date
  Future<void> _fetchBookedSlots(DateTime day) async {
    if (selectedBarber == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("BookedSlots")
          .doc(widget.barber.ownerUid)
          .get();

      if (!snapshot.exists) {
        setState(() => bookedSlots = {});
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);

      final dateStr = DateFormat('yyyy-MM-dd').format(day);

      final Set<String> blocked = {};

      for (var booking in bookings) {
        if (booking['date'] == dateStr &&
            booking['barbername'] == selectedBarber!["name"]) {
          blocked.add(booking['slot']);
        }
      }

      setState(() {
        bookedSlots = blocked;
      });

      debugPrint("🚫 Booked slots: $bookedSlots");

    } catch (e) {
      debugPrint("❌ Error fetching booked slots: $e");
    }
  }

  Future<void> _generateTimeSlots(DateTime day) async {
    final totalMinutes = _getTotalServiceMinutes();

    if (selectedBarber == null || totalMinutes == 0) {
      setState(() {
        timeSlots = [];
        selectedTimeIndex = -1;
      });
      return;
    }

    await _fetchBookedSlots(day); // 👈 fetch first

    List<String> slots = [];

    bool isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    String? startStr = isWeekend ? satSunStart : monFriStart;
    String? endStr = isWeekend ? satSunEnd : monFriEnd;
    if (startStr == null || endStr == null) return;

    TimeOfDay start = _parseTime(startStr);
    TimeOfDay end = _parseTime(endStr);

    DateTime startDateTime =
    DateTime(day.year, day.month, day.day, start.hour, start.minute);

    DateTime endDateTime =
    DateTime(day.year, day.month, day.day, end.hour, end.minute);

    DateTime now = DateTime.now();
    DateTime slotStart = startDateTime;

    while (true) {
      DateTime slotEnd = slotStart.add(Duration(minutes: totalMinutes));
      if (slotEnd.isAfter(endDateTime)) break;

      if (isSameDay(day, now) && slotStart.isBefore(now)) {
        slotStart = slotEnd;
        continue;
      }

      final slot =
          "${DateFormat.jm().format(slotStart)} - ${DateFormat.jm().format(slotEnd)}";

      slots.add(slot);
      slotStart = slotEnd;
    }

    setState(() {
      timeSlots = slots;
      selectedTimeIndex = -1;
    });
  }

  Future<void> _updateSelectedServices() async {
    final selected = services
        .where((s) => s["selected"] == true)
        .map((s) => {
      "name": s["name"],
      "price": s["price"],
      "time": s["time"],
    }).toList();



    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one service"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDay == null || selectedTimeIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select date and time"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedSlot = timeSlots[selectedTimeIndex];
    if (bookedSlots.contains(selectedSlot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This slot is already booked! Choose another."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<BookingProvider>();
    provider.setSelectedServices(selected);
    provider.setDateTime(_selectedDay!, selectedSlot);
    provider.setSelectedBarberId(selectedBarber!["name"]);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSummary(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        title: const Text("Book Service"),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SERVICES SECTION
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Text(
                      "Select Services",
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Column(
                      children: services.map((service) {
                        int index = services.indexOf(service);
                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          child: Card(
                            color: const Color(0xFFFFFAF2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: EdgeInsets.all(10.w),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Image.asset(
                                      _getImagePath(service["image"]),
                                      height: 60.w,
                                      width: 60.w,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          service["name"],
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          "₹${service["price"]}",
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          "${service["time"]}",
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    activeColor: Colors.orange,
                                    value: service["selected"] ?? false,
                                    onChanged: (value) {
                                      setState(() {
                                        service["selected"] = value ?? false;
                                      });

                                      if (_selectedDay != null) {
                                        _generateTimeSlots(_selectedDay!);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // DATE SELECTION
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Text(
                      "Select Date",
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: TableCalendar<dynamic>(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        weekendTextStyle: const TextStyle(color: Colors.red),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                  ),

                  // TIME SLOTS
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select Barber",
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: barbersname.map((barber) {
                            final isSelected = selectedBarber?["name"] == barber["name"];

                            return ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  selectedBarber = barber;
                                });

                                // regenerate slots only if date exists
                                if (_selectedDay != null) {
                                  _generateTimeSlots(_selectedDay!);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                isSelected ? Colors.orange : Colors.orange.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    barber["name"].toString(),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    barber["number"].toString(),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  if (timeSlots.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      child: Text(
                        "No slots available for this day.",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 60.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        itemCount: timeSlots.length,
                        itemBuilder: (context, index) {
                          final slot = timeSlots[index];
                          final isBooked = bookedSlots.contains(slot);

                          return GestureDetector(
                            onTap: isBooked
                                ? null
                                : () {
                              setState(() {
                                selectedTimeIndex = index;
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              height: 50.h,
                              width: 150.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isBooked
                                    ? Colors.grey
                                    : selectedTimeIndex == index
                                    ? Colors.orange
                                    : Colors.white,
                                border: Border.all(
                                  color: isBooked ? Colors.grey : Colors.orange,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(25.r),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  color: isBooked
                                      ? Colors.white
                                      : selectedTimeIndex == index
                                      ? Colors.white
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ),

          // Continue Button
          Container(
            padding: EdgeInsets.all(16.w),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                onPressed: _updateSelectedServices,
                child: Text(
                  "Apply",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
