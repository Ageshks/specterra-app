import '../data/models/booking.dart';
import '../data/models/customer.dart';
import '../data/models/supporting_models.dart';
import '../data/models/water_service.dart';
import '../data/specterra_repository.dart';

/// Authentication phase of the customer journey.
enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

/// Immutable snapshot of everything the UI renders.
class AppData {
  const AppData({
    this.customer,
    this.services = const <WaterService>[],
    this.bookings = const <Booking>[],
    this.notifications = const <AppNotification>[],
    this.reports = const <WaterReport>[],
    this.checkups = const <CheckupAppointment>[],
    this.addresses = const <ServiceAddress>[],
    this.isLoadingData = false,
    this.dataError,
  });

  final Customer? customer;
  final List<WaterService> services;
  final List<Booking> bookings;
  final List<AppNotification> notifications;
  final List<WaterReport> reports;
  final List<CheckupAppointment> checkups;
  final List<ServiceAddress> addresses;
  final bool isLoadingData;
  final String? dataError;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  Booking? get activeBooking {
    for (final booking in bookings) {
      if (booking.isUpcoming) return booking;
    }
    return bookings.isEmpty ? null : bookings.first;
  }

  WaterReport? get latestReport => reports.isEmpty ? null : reports.first;

  AppData copyWith({
    Customer? customer,
    List<WaterService>? services,
    List<Booking>? bookings,
    List<AppNotification>? notifications,
    List<WaterReport>? reports,
    List<CheckupAppointment>? checkups,
    List<ServiceAddress>? addresses,
    bool? isLoadingData,
    String? dataError,
    bool clearError = false,
    bool clearCustomer = false,
  }) {
    return AppData(
      customer: clearCustomer ? null : (customer ?? this.customer),
      services: services ?? this.services,
      bookings: bookings ?? this.bookings,
      notifications: notifications ?? this.notifications,
      reports: reports ?? this.reports,
      checkups: checkups ?? this.checkups,
      addresses: addresses ?? this.addresses,
      isLoadingData: isLoadingData ?? this.isLoadingData,
      dataError: clearError ? null : (dataError ?? this.dataError),
    );
  }
}

/// Raised by [SpecterraRepository] when a call fails.
class DataFailure implements Exception {
  const DataFailure(this.message);
  final String message;
}
