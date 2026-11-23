import 'package:flutter/material.dart';

/// Signed-in customer profile.
@immutable
class Customer {
  const Customer({
    required this.name,
    required this.email,
    required this.phone,
    required this.plan,
    required this.memberSince,
    required this.initials,
    this.companySlug,
  });

  final String name;
  final String email;
  final String phone;
  final String plan;
  final String memberSince;
  final String initials;
  final String? companySlug;

  String get firstName => name.split(' ').first;

  /// Backend payloads may use either camelCase or snake_case keys.
  /// The live API splits names into `firstName` / `lastName`.
  factory Customer.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    var name = pick(['name', 'fullName', 'full_name']);
    if (name.isEmpty) {
      final first = pick(['firstName', 'first_name']);
      final last = pick(['lastName', 'last_name']);
      name = ('$first $last').trim();
    }
    if (name.isEmpty) name = 'Customer';
    var initials = pick(['initials']);
    if (initials.isEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      initials = parts.length > 1
          ? (parts.first[0] + parts.last[0]).toUpperCase()
          : name.isNotEmpty
              ? name[0].toUpperCase()
              : '?';
    }
    final profileCustomer = json['customer'];
    final profileCustomerMap = profileCustomer is Map
        ? Map<String, dynamic>.from(profileCustomer)
        : const <String, dynamic>{};
    final company =
        json['company'] ??
        json['customerCompany'] ??
        profileCustomerMap['company'];
    final companyMap = company is Map
        ? Map<String, dynamic>.from(company)
        : const <String, dynamic>{};
    final companySlug = pick(
      ['companySlug', 'company_slug'],
      (companyMap['slug'] ??
              companyMap['companySlug'] ??
              (company is String ? company : ''))
          .toString(),
    );
    return Customer(
      name: name,
      email: pick(['email', 'emailAddress', 'email_address']),
      phone: pick(['phone', 'phoneNumber', 'phone_number', 'mobile']),
      plan: pick(['plan', 'membershipPlan', 'membership_plan'], 'Standard'),
      memberSince: pick(['memberSince', 'member_since', 'joinedOn'], ''),
      initials: initials,
      companySlug: companySlug.isEmpty ? null : companySlug,
    );
  }
}

/// Extracts a bearer token from the live SPECTERRA envelope:
/// `{ success, data: { user, tokens: { accessToken, refreshToken } } }`,
/// plus legacy shapes (`token`, `accessToken`, `data.token`).
String? extractAuthToken(dynamic decoded) {
  if (decoded == null) return null;
  if (decoded is String) return decoded.isEmpty ? null : decoded;
  if (decoded is! Map<String, dynamic>) return null;
  for (final key in ['token', 'accessToken', 'access_token', 'jwt']) {
    final value = decoded[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  // Live envelope nests tokens under data.tokens or top-level tokens.
  for (final key in ['tokens', 'tokenPair', 'auth']) {
    final nested = decoded[key];
    if (nested is Map<String, dynamic>) {
      final found = extractAuthToken(nested);
      if (found != null) return found;
    }
  }
  final data = decoded['data'];
  if (data is Map<String, dynamic>) return extractAuthToken(data);
  final user = decoded['user'];
  if (user is Map<String, dynamic>) {
    return extractAuthToken(user);
  }
  return null;
}

/// Extracts the refresh token from the live envelope (`data.tokens.refreshToken`).
String? extractRefreshToken(dynamic decoded) {
  if (decoded is! Map<String, dynamic>) return null;
  Map<String, dynamic>? tokens;
  final data = decoded['data'];
  if (data is Map<String, dynamic> && data['tokens'] is Map<String, dynamic>) {
    tokens = data['tokens'] as Map<String, dynamic>;
  } else if (decoded['tokens'] is Map<String, dynamic>) {
    tokens = decoded['tokens'] as Map<String, dynamic>;
  }
  final refresh = tokens?['refreshToken'] ?? tokens?['refresh_token'];
  if (refresh is String && refresh.isNotEmpty) return refresh;
  final nested = decoded['refreshToken'];
  if (nested is String && nested.isNotEmpty) return nested;
  return null;
}

/// Extracts the user object from the live envelope (`data.user`) plus
/// legacy shapes: the map itself, `data`, or `user`.
Map<String, dynamic>? extractUserMap(dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      final user = data['user'];
      if (user is Map<String, dynamic>) return user;
      // Register returns the user directly as `data` (no tokens yet).
      if (data.containsKey('email') || data.containsKey('firstName')) {
        return data;
      }
      // If data itself looks like a user (has a name/email), use it.
      if (data.containsKey('name') ||
          data.containsKey('email') ||
          data.containsKey('phone')) {
        return data;
      }
    }
    final user = decoded['user'];
    if (user is Map<String, dynamic>) return user;
    if (decoded.containsKey('name') ||
        decoded.containsKey('firstName') ||
        decoded.containsKey('email') ||
        decoded.containsKey('phone') ||
        decoded.containsKey('employeeId')) {
      return decoded;
    }
  }
  return null;
}


/// Saved installation / billing address (a backend "service location").
@immutable
class ServiceAddress {
  const ServiceAddress({
    required this.id,
    required this.label,
    required this.lines,
    required this.icon,
    this.isDefault = false,
    this.city,
    this.state,
    this.pincode,
    this.isActive = true,
    this.contactPerson,
    this.contactNumber,
    this.instructions,
  });

  final String id;
  final String label;
  final String lines;
  final IconData icon;
  final bool isDefault;
  final String? city;
  final String? state;
  final String? pincode;
  final bool isActive;
  final String? contactPerson;
  final String? contactNumber;
  final String? instructions;

  ServiceAddress copyWith({
    String? id,
    String? label,
    String? lines,
    IconData? icon,
    bool? isDefault,
    String? city,
    String? state,
    String? pincode,
    bool? isActive,
    String? contactPerson,
    String? contactNumber,
    String? instructions,
  }) =>
      ServiceAddress(
        id: id ?? this.id,
        label: label ?? this.label,
        lines: lines ?? this.lines,
        icon: icon ?? this.icon,
        isDefault: isDefault ?? this.isDefault,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        isActive: isActive ?? this.isActive,
        contactPerson: contactPerson ?? this.contactPerson,
        contactNumber: contactNumber ?? this.contactNumber,
        instructions: instructions ?? this.instructions,
      );

  /// Parses a backend service-location payload.
  factory ServiceAddress.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    final label = pick(['locationName', 'label', 'name', 'title'], 'Location');
    final address = pick(['address', 'lines', 'street']);
    final city = pick(['city']);
    final state = pick(['state']);
    final pincode = pick(['pincode', 'postalCode', 'zip']);
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (pincode.isNotEmpty) pincode,
    ];
    final lines = parts.isEmpty ? label : parts.join(', ');
    final activeRaw = json['isActive'] ?? json['active'];
    final isActive = activeRaw == null ? true : activeRaw == true;
    return ServiceAddress(
      id: pick(['id', '_id', 'locationId', 'serviceLocationId'], ''),
      label: label,
      lines: lines,
      icon: Icons.location_on_outlined,
      isDefault: json['isDefault'] == true,
      city: city.isEmpty ? null : city,
      state: state.isEmpty ? null : state,
      pincode: pincode.isEmpty ? null : pincode,
      isActive: isActive,
      contactPerson: pick(['contactPerson']).isEmpty ? null : pick(['contactPerson']),
      contactNumber: pick(['contactNumber', 'phone', 'mobile']).isEmpty
          ? null
          : pick(['contactNumber', 'phone', 'mobile']),
      instructions: pick(['instructions', 'notes']).isEmpty ? null : pick(['instructions', 'notes']),
    );
  }
}

/// Result wrapper used by the simulated repository layer.
@immutable
class AsyncStatus<T> {
  const AsyncStatus._({this.data, this.isLoading = false, this.error});

  const AsyncStatus.loading() : this._(isLoading: true);
  const AsyncStatus.success(T value) : this._(data: value);
  const AsyncStatus.failure(String message) : this._(error: message);

  final T? data;
  final bool isLoading;
  final String? error;

  bool get hasData => data != null;
}
