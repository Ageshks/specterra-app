import 'package:flutter/foundation.dart';

/// A product available to add to a customer service booking.
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.photos = const <String>[],
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final List<String> photos;

  factory Product.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return fallback;
    }

    int pickPrice(dynamic value) {
      if (value is num) return value.round();
      if (value is String) {
        return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''))
                ?.round() ??
            0;
      }
      return 0;
    }

    final rawPhotos = json['photos'];
    final photos = rawPhotos is List
        ? rawPhotos
              .map((photo) {
                if (photo is String) return photo.trim();
                if (photo is Map) {
                  return (photo['url'] ??
                          photo['imageUrl'] ??
                          photo['image_url'] ??
                          '')
                      .toString()
                      .trim();
                }
                return '';
              })
              .where((url) => url.isNotEmpty)
              .toList()
        : const <String>[];

    return Product(
      id: pick(['id', '_id', 'productId']),
      name: pick(['name', 'title'], 'Product'),
      description: pick(['description']),
      price: pickPrice(json['price']),
      photos: photos,
    );
  }
}

/// A selected product quantity, serialized without client-side pricing.
@immutable
class ProductSelection {
  const ProductSelection({required this.productId, required this.quantity})
    : assert(quantity > 0);

  final String productId;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}

/// Price snapshot returned by the backend for a booked product.
@immutable
class BookingProductLine {
  const BookingProductLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final int lineTotal;

  factory BookingProductLine.fromJson(Map<String, dynamic> json) {
    int amount(dynamic value) {
      if (value is num) return value.round();
      if (value is String) {
        return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''))
                ?.round() ??
            0;
      }
      return 0;
    }

    final product = json['product'];
    final productMap = product is Map
        ? Map<String, dynamic>.from(product)
        : const <String, dynamic>{};
    final rawQuantity = json['quantity'];
    final quantity = rawQuantity is num
        ? rawQuantity.toInt()
        : int.tryParse(rawQuantity?.toString() ?? '') ?? 0;
    final unitPrice = amount(
      json['unitPrice'] ?? json['unit_price'] ?? json['price'],
    );
    final rawLineTotal =
        json['lineTotal'] ??
        json['line_total'] ??
        json['total'] ??
        json['totalPrice'];
    return BookingProductLine(
      name: (json['productName'] ??
              json['name'] ??
              productMap['name'] ??
              'Product')
          .toString(),
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: rawLineTotal == null
          ? unitPrice * quantity
          : amount(rawLineTotal),
    );
  }
}
