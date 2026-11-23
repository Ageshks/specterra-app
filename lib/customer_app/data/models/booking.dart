import 'package:flutter/material.dart';
import 'product.dart';

/// Lifecycle of a booked service, ordered from request to completion.
enum BookingStatus {
  upcoming('Upcoming'),
  assigned('Technician Assigned'),
  enRoute('On the Way'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;

  bool get isActive =>
      this == BookingStatus.assigned ||
      this == BookingStatus.enRoute ||
      this == BookingStatus.inProgress;

  Color get foregroundColor => switch (this) {
    BookingStatus.upcoming => const Color(0xFF1B6FC4),
    BookingStatus.assigned => const Color(0xFF7A4FC0),
    BookingStatus.enRoute => const Color(0xFFA86A08),
    BookingStatus.inProgress => const Color(0xFF0F766E),
    BookingStatus.completed => const Color(0xFF2C7A4B),
    BookingStatus.cancelled => const Color(0xFFC0392B),
  };

  Color get backgroundColor => switch (this) {
    BookingStatus.upcoming => const Color(0xFFE4F0FB),
    BookingStatus.assigned => const Color(0xFFF0E9FB),
    BookingStatus.enRoute => const Color(0xFFFDF1DC),
    BookingStatus.inProgress => const Color(0xFFE0F2F0),
    BookingStatus.completed => const Color(0xFFE4F3E9),
    BookingStatus.cancelled => const Color(0xFFFDECEA),
  };
}

/// One step of the live tracking timeline.
@immutable
class TrackingStep {
  const TrackingStep({
    required this.title,
    required this.timestamp,
    this.isDone = false,
    this.isCurrent = false,
    this.note,
  });

  final String title;
  final String timestamp;
  final bool isDone;
  final bool isCurrent;
  final String? note;
}

/// Field technician assigned to a booking.
@immutable
class Technician {
  const Technician({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.rating,
    required this.experienceYears,
    required this.initials,
    this.vehicle = 'Swift White • KA 05 AB 1234',
  });

  final String id;
  final String name;
  final String role;
  final String phone;
  final double rating;
  final int experienceYears;
  final String initials;
  final String vehicle;
}

/// A confirmed or historical service appointment.
@immutable
class Booking {
  const Booking({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.serviceIcon,
    required this.scheduledAt,
    required this.address,
    required this.status,
    required this.amount,
    required this.customerName,
    this.technician,
    this.trackingSteps = const <TrackingStep>[],
    this.notes = '',
    this.contactNumber = '',
    this.bookingProducts = const <BookingProductLine>[],
  });

  final String id;
  final String serviceId;
  final String serviceName;
  final IconData serviceIcon;
  final DateTime scheduledAt;
  final String address;
  final BookingStatus status;
  final int amount;
  final String customerName;
  final Technician? technician;
  final List<TrackingStep> trackingSteps;
  final String notes;
  final String contactNumber;
  final List<BookingProductLine> bookingProducts;

  bool get isUpcoming =>
      status == BookingStatus.upcoming ||
      status == BookingStatus.assigned ||
      status == BookingStatus.enRoute;

  /// Parses the live `GET /bookings` payload. Accepts camelCase/snake_case
  /// keys and tolerant status strings; unknown rows fa
  factory Booking.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    int pickInt(List<String> keys, [int fallback = 0]) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = double.tryParse(
            value.replaceAll(RegExp(r'[^0-9.-]'), ''),
          )?.round();
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    final rawStatus = pick(['status', 'state']).toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');
    BookingStatus status = BookingStatus.upcoming;
    if (rawStatus.contains('cancel')) {
      status = BookingStatus.cancelled;
    } else if (rawStatus.contains('complet') || rawStatus.contains('done')) {
      status = BookingStatus.completed;
    } else if (rawStatus.contains('progress') || rawStatus.contains('ongoing')) {
      status = BookingStatus.inProgress;
    } else if (rawStatus.contains('enroute') ||
        rawStatus.contains('ontheway') ||
        rawStatus.contains('dispatched')) {
      status = BookingStatus.enRoute;
    } else if (rawStatus.contains('assign') || rawStatus.contains('confirm') || rawStatus.contains('request')) {
      status = BookingStatus.assigned;
    }

    // A manager's assignment is authoritative over the customer's originally
    // requested slot. The API can return the assignment either flattened on
    // the booking or nested under its work order.
    final workOrderValue = json['workOrder'] ?? json['work_order'];
    final workOrder = workOrderValue is Map
        ? Map<String, dynamic>.from(workOrderValue)
        : const <String, dynamic>{};
    dynamic scheduleValue(List<String> keys) {
      for (final key in keys) {
        final value = json[key] ?? workOrder[key];
        if (value != null && value.toString().trim().isNotEmpty) return value;
      }
      return null;
    }

    DateTime scheduledAt = DateTime.now();
    final timeValue =
        (scheduleValue([
          'scheduledStartTime',
          'scheduled_start_time',
          'preferredTime',
          'preferred_time',
          'time',
        ]) ??
                '')
            .toString();
    final scheduleDate = scheduleValue([
      'scheduledDate',
      'scheduled_date',
      'scheduledAt',
      'scheduled_at',
      'preferredDate',
      'preferred_date',
      'date',
      'slot',
      'createdAt',
    ]);
    if (scheduleDate is String && scheduleDate.isNotEmpty) {
      final parsed = DateTime.tryParse(scheduleDate);
      if (parsed != null) scheduledAt = parsed;
    }
    if (timeValue.isNotEmpty) {
      final parts = timeValue.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          scheduledAt = DateTime(
            scheduledAt.year,
            scheduledAt.month,
            scheduledAt.day,
            h,
            m,
          );
        }
      }
    }

    final service = json['service'];
    Map<String, dynamic>? serviceMap;
    if (service is Map<String, dynamic>) serviceMap = service;
    final serviceName = serviceMap != null
        ? (serviceMap['name']?.toString() ?? '')
        : pick(['serviceName', 'service_name', 'serviceTitle']);

    final serviceLocation = json['serviceLocation'] ?? json['service_location'] ?? json['location'];
    Map<String, dynamic>? locationMap;
    if (serviceLocation is Map<String, dynamic>) locationMap = serviceLocation;

    String address = pick(['address', 'serviceAddress', 'location', 'addressLine']);
    if (address.isEmpty && locationMap != null) {
      final parts = <String>[
        if ((locationMap['address'] ?? '').toString().trim().isNotEmpty) locationMap['address'].toString().trim(),
        if ((locationMap['city'] ?? '').toString().trim().isNotEmpty) locationMap['city'].toString().trim(),
        if ((locationMap['state'] ?? '').toString().trim().isNotEmpty) locationMap['state'].toString().trim(),
        if ((locationMap['pincode'] ?? '').toString().trim().isNotEmpty) locationMap['pincode'].toString().trim(),
      ];
      address = parts.join(', ');
      if (address.isEmpty) address = (locationMap['locationName'] ?? locationMap['name'] ?? '').toString();
    }

    final customer = json['customer'];
    Map<String, dynamic>? customerMap;
    if (customer is Map<String, dynamic>) customerMap = customer;
    final user = customerMap != null ? customerMap['user'] : null;
    Map<String, dynamic>? userMap;
    if (user is Map<String, dynamic>) userMap = user;

    String customerName = pick(['customerName', 'customer_name', 'name']);
    if (customerName.isEmpty && userMap != null) {
      final first = (userMap['firstName'] ?? userMap['first_name'] ?? '').toString();
      final last = (userMap['lastName'] ?? userMap['last_name'] ?? '').toString();
      customerName = ('$first $last').trim();
    }

    String contactNumber = pick(['contactNumber', 'contact_number', 'phone', 'mobile']);
    if (contactNumber.isEmpty && userMap != null) {
      contactNumber = (userMap['phone'] ?? userMap['phoneNumber'] ?? '').toString();
    }

    final hasTotalAmount =
        json.containsKey('totalAmount') || json.containsKey('total_amount');
    int amount = pickInt([
      'totalAmount',
      'total_amount',
      'amount',
      'total',
      'price',
      'cost',
    ]);
    if (!hasTotalAmount && amount == 0 && serviceMap != null) {
      final servicePrice = serviceMap['basePrice'] ?? serviceMap['base_price'] ?? serviceMap['price'] ?? serviceMap['amount'];
      if (servicePrice is num) amount = servicePrice.toInt();
      if (servicePrice is String) {
        amount =
            double.tryParse(
              servicePrice.replaceAll(RegExp(r'[^0-9.-]'), ''),
            )?.round() ??
            0;
      }
    }

    final tech = json['technician'] ?? json['engineer'] ?? json['staff'];
    Technician? technician;
    if (tech is Map<String, dynamic>) {
      final tName = (tech['name'] ?? tech['fullName'] ?? '').toString();
      technician = Technician(
        id: (tech['id'] ?? '').toString(),
        name: tName.isEmpty ? 'Technician' : tName,
        role: (tech['role'] ?? 'Service Technician').toString(),
        phone: (tech['phone'] ?? '').toString(),
        rating: (tech['rating'] is num) ? (tech['rating'] as num).toDouble() : 0,
        experienceYears: (tech['experienceYears'] is num) ? (tech['experienceYears'] as num).toInt() : 0,
        initials: tName.isEmpty ? 'T' : tName.trim()[0].toUpperCase(),
      );
    }
    final rawBookingProducts =
        json['bookingProducts'] ?? json['booking_products'];
    final bookingProducts = rawBookingProducts is List
        ? rawBookingProducts
              .whereType<Map>()
              .map(
                (item) => BookingProductLine.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <BookingProductLine>[];
    return Booking(
      id: pick(['id', '_id', 'bookingId', 'booking_id']),
      serviceId: pick(['serviceId', 'service_id', 'service']),
      serviceName: serviceName.isEmpty ? 'Service' : serviceName,
      serviceIcon: Icons.filter_alt_outlined,
      scheduledAt: scheduledAt,
      address: address.isEmpty ? '—' : address,
      status: status,
      amount: amount,
      customerName: customerName.isEmpty ? 'Customer' : customerName,
      technician: technician,
      notes: pick(['notes', 'note', 'remarks']),
      contactNumber: contactNumber,
      bookingProducts: bookingProducts,
    );
  }
}
