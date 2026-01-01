// providers/booking_provider.dart
import 'package:flutter/material.dart';
import '../models/mearge_barber_model.dart';

class BookingProvider extends ChangeNotifier {
  MergedBarber? _barber;
  List<Map<String, dynamic>> _selectedServices = [];
  DateTime? _selectedDate;
  String? _selectedSlot;
  int _totalPrice = 0;
  String? _selectedBarber;

  // Getters
  MergedBarber? get barber => _barber;
  List<Map<String, dynamic>> get selectedServices => _selectedServices;
  DateTime? get selectedDate => _selectedDate;
  String? get selectedSlot => _selectedSlot;
  int get totalPrice => _totalPrice;
  String? get selectedBabberId => _selectedBarber;


  // Setters
  void setBarber(MergedBarber barber) {
    _barber = barber;
    notifyListeners();
  }

  void setSelectedServices(List<Map<String, dynamic>> services) {
    _selectedServices = services;
    _calculateTotalPrice();
    notifyListeners();
  }

  void setDateTime(DateTime date, String slot) {
    _selectedDate = date;
    _selectedSlot = slot;
    notifyListeners();
  }

  void setSelectedBarberId(String barbername){
    _selectedBarber = barbername;
    notifyListeners();
  }

  void _calculateTotalPrice() {
    _totalPrice =
        _selectedServices.fold(0, (sum, s) => sum + (s['price'] as int));
  }

  int get totalServiceMinutes {
    return _selectedServices.fold(
      0,
          (sum, s) => sum + (s['timeMinutes'] is int ? s['timeMinutes'] as int : 0),
    );
  }

  bool get isBookingComplete =>
      _barber != null &&
          _selectedServices.isNotEmpty &&
          _selectedDate != null &&
          _selectedSlot != null &&
          _selectedBarber != null;

  void clearBooking() {
    _barber = null;
    _selectedServices = [];
    _selectedDate = null;
    _selectedSlot = null;
    _totalPrice = 0;
    _selectedBarber = null;
    notifyListeners();
  }

  /// 🔹 Important: initialize status as `null` (PENDING) so barber sees Accept/Decline
  Map<String, dynamic> getBookingData(String userId) {
    return {
      "userId": userId,
      "placeId": _barber!.placeId,          // make sure this matches your shop doc id (googlePlaceId)
      "shopName": _barber!.name,
      "shopAddress": _barber!.address,
      "services": _selectedServices,
      "totalPrice": _totalPrice,
      "date": _selectedDate!
          .toIso8601String()
          .split('T')[0],                   // YYYY-MM-DD
      "slot": _selectedSlot,
      "barbername" : _selectedBarber,
      "createdAt": DateTime.now().toIso8601String(),
    };
  }
}
