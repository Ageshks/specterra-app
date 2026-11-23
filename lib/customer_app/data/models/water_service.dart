import 'package:flutter/material.dart';

/// A service offering that a customer can book.
@immutable
class WaterService {
  const WaterService({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.durationMinutes,
    required this.category,
    this.imageUrl,
    this.isActive = true,
    this.isPopular = false,
    this.includes = const <String>[],
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String? imageUrl;
  final int price;
  final int durationMinutes;
  final ServiceCategory category;
  final bool isActive;
  final bool isPopular;
  final List<String> includes;

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes min';
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
  }

  String get priceLabel => '₹${_formatPrice(price)}';

  static String _formatPrice(int value) {
    final parts = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write(',');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  factory WaterService.fromJson(Map<String, dynamic> json) {
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
        if (value is num) return value.round();
        if (value is String) {
          final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
          if (parsed != null) return parsed.round();
        }
      }
      return fallback;
    }

    String normalise(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final rawCategory = json['category'] ?? json['type'] ?? json['slug'] ?? json['categoryName'];
    String rawCategoryName;
    if (rawCategory is Map) {
      rawCategoryName = (rawCategory['name'] ?? rawCategory['title'] ?? rawCategory['label'] ?? '').toString();
    } else {
      rawCategoryName = rawCategory?.toString() ?? '';
    }

    ServiceCategory category = ServiceCategory.roService;
    final token = normalise(rawCategoryName);
    for (final c in ServiceCategory.values) {
      if (token.isEmpty) break;
      if (token.contains(normalise(c.name)) ||
          token == normalise(c.label) ||
          (normalise(c.label).contains(token) && token.isNotEmpty)) {
        category = c;
        break;
      }
    }

    final rawIncludes = json['includes'] ?? json['features'];
    final includes = rawIncludes is List
        ? rawIncludes.map((e) => e.toString()).toList()
        : const <String>[];

    final rawImage = json['image'] ?? json['imageUrl'] ?? json['image_url'];
    final imageUrl = (rawImage is String && rawImage.trim().isNotEmpty) ? rawImage.trim() : null;

    return WaterService(
      id: pick(['id', '_id', 'serviceId', 'slug'], 'svc_unknown'),
      name: pick(['name', 'title', 'serviceName'], 'Service'),
      description: pick(['description', 'details', 'summary']),
      icon: _iconFor(category),
      imageUrl: imageUrl,
      price: pickInt(['basePrice', 'base_price', 'price', 'amount', 'cost', 'rate']),
      durationMinutes: pickInt(['estimatedDuration', 'estimated_duration', 'durationMinutes', 'duration', 'durationMin'], 60),
      category: category,
      isActive: json['isActive'] == null ? true : json['isActive'] == true,
      isPopular: json['isPopular'] == true || json['popular'] == true,
      includes: includes,
    );
  }

  static IconData _iconFor(ServiceCategory category) => switch (category) {
        ServiceCategory.treatmentPlant => Icons.water_damage_outlined,
        ServiceCategory.roService => Icons.filter_alt_outlined,
        ServiceCategory.filters => Icons.layers_outlined,
        ServiceCategory.softener => Icons.opacity_outlined,
        ServiceCategory.uvSystem => Icons.light_mode_outlined,
        ServiceCategory.amc => Icons.workspace_premium_outlined,
      };
}

enum ServiceCategory {
  treatmentPlant('Treatment Plant'),
  roService('RO Service'),
  filters('Filters'),
  softener('Softener'),
  uvSystem('UV System'),
  amc('AMC Plans');

  const ServiceCategory(this.label);
  final String label;
}
