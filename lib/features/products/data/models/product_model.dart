import 'dart:convert';
import 'package:logger/logger.dart';

class Dimensions {
  final double width;
  final double height;
  final double depth;

  Dimensions({required this.width, required this.height, required this.depth});

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      width: ProductModel._parseDouble(json['width'], 0.0),
      height: ProductModel._parseDouble(json['height'], 0.0),
      depth: ProductModel._parseDouble(json['depth'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {'width': width, 'height': height, 'depth': depth};
  }
}

class Review {
  final int rating;
  final String comment;
  final DateTime date;
  final String reviewerName;
  final String reviewerEmail;

  Review({
    required this.rating,
    required this.comment,
    required this.date,
    required this.reviewerName,
    required this.reviewerEmail,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      reviewerName: json['reviewerName'] ?? 'Anonymous',
      reviewerEmail: json['reviewerEmail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'comment': comment,
      'date': date.toIso8601String(),
      'reviewerName': reviewerName,
      'reviewerEmail': reviewerEmail,
    };
  }
}

class ProductMeta {
  final DateTime createdAt;
  final DateTime updatedAt;
  final String barcode;
  final String qrCode;

  ProductMeta({
    required this.createdAt,
    required this.updatedAt,
    required this.barcode,
    required this.qrCode,
  });

  factory ProductMeta.fromJson(Map<String, dynamic> json) {
    return ProductMeta(
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      barcode: json['barcode'] ?? '',
      qrCode: json['qrCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'barcode': barcode,
      'qrCode': qrCode,
    };
  }
}

class ProductModel {
  final int id;
  final String title;
  final String description;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;
  final String brand;
  final String category;
  final String thumbnail;
  final List<String> images;


  final List<String> tags;
  final String sku;
  final double weight;
  final Dimensions? dimensions;
  final String warrantyInformation;
  final String shippingInformation;
  final String availabilityStatus;
  final List<Review> reviews;
  final String returnPolicy;
  final int minimumOrderQuantity;
  final ProductMeta? meta;

  static final Logger _logger = Logger();

  ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.stock,
    required this.brand,
    required this.category,
    required this.thumbnail,
    required this.images,
    this.tags = const [],
    this.sku = '',
    this.weight = 0.0,
    this.dimensions,
    this.warrantyInformation = '',
    this.shippingInformation = '',
    this.availabilityStatus = 'In Stock',
    this.reviews = const [],
    this.returnPolicy = '',
    this.minimumOrderQuantity = 1,
    this.meta,
  });

  // Calculate discounted price
  double get discountedPrice {
    return price - (price * discountPercentage / 100);
  }

  // Check if product is on sale
  bool get isOnSale => discountPercentage > 0;

  // Check if product is in stock
  bool get isInStock => stock > 0;

  // Get average rating from reviews (if available)
  double get averageReviewRating {
    if (reviews.isEmpty) return rating;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;
  }

  // Calculate shipping dimensions volume
  double get dimensionsVolume {
    if (dimensions == null) return 0.0;
    return dimensions!.width * dimensions!.height * dimensions!.depth;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    _logger.d('Parsing product: ${json['id']}');

    try {
      // Parse dimensions if available
      Dimensions? dimensions;
      if (json['dimensions'] != null) {
        try {
          dimensions = Dimensions.fromJson(json['dimensions']);
        } catch (e) {
          _logger.e('Error parsing dimensions: $e');
        }
      }

      // Parse reviews if available
      List<Review> reviews = [];
      if (json['reviews'] != null && json['reviews'] is List) {
        try {
          reviews = (json['reviews'] as List)
              .map((reviewJson) => Review.fromJson(reviewJson))
              .toList();
        } catch (e) {
          _logger.e('Error parsing reviews: $e');
        }
      }

      // Parse meta if available
      ProductMeta? meta;
      if (json['meta'] != null) {
        try {
          meta = ProductMeta.fromJson(json['meta']);
        } catch (e) {
          _logger.e('Error parsing meta: $e');
        }
      }

      return ProductModel(
        id: json['id'],
        title: json['title'] ?? 'Unknown',
        description: json['description'] ?? '',
        price: _parseDouble(json['price'], 0.0),
        discountPercentage: _parseDouble(json['discountPercentage'], 0.0),
        rating: _parseDouble(json['rating'], 0.0),
        stock: json['stock'] ?? 0,
        brand: json['brand'] ?? 'Unknown',
        category: json['category'] ?? 'Unknown',
        thumbnail: json['thumbnail'] ?? '',
        images: _parseStringList(json['images']),
        tags: _parseStringList(json['tags']),
        sku: json['sku'] ?? '',
        weight: _parseDouble(json['weight'], 0.0),
        dimensions: dimensions,
        warrantyInformation: json['warrantyInformation'] ?? '',
        shippingInformation: json['shippingInformation'] ?? '',
        availabilityStatus: json['availabilityStatus'] ?? 'In Stock',
        reviews: reviews,
        returnPolicy: json['returnPolicy'] ?? '',
        minimumOrderQuantity: json['minimumOrderQuantity'] ?? 1,
        meta: meta,
      );
    } catch (e) {
      _logger.e('Error parsing product: $e');
      rethrow;
    }
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'discountPercentage': discountPercentage,
      'rating': rating,
      'stock': stock,
      'brand': brand,
      'category': category,
      'thumbnail': thumbnail,
      'images': images,
      'tags': tags,
      'sku': sku,
      'weight': weight,
      'dimensions': dimensions?.toJson(),
      'warrantyInformation': warrantyInformation,
      'shippingInformation': shippingInformation,
      'availabilityStatus': availabilityStatus,
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'returnPolicy': returnPolicy,
      'minimumOrderQuantity': minimumOrderQuantity,
      'meta': meta?.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory ProductModel.fromDatabase(Map<String, dynamic> map) {
    try {
      List<String> parseImages() {
        try {
          if (map['images'] == null) return [];
          return List<String>.from(json.decode(map['images']));
        } catch (e) {
          _logger.e('Error parsing images from database: $e');
          return [];
        }
      }

      List<String> parseTags() {
        try {
          if (map['tags'] == null) return [];
          return List<String>.from(json.decode(map['tags']));
        } catch (e) {
          _logger.e('Error parsing tags from database: $e');
          return [];
        }
      }

      Dimensions? parseDimensions() {
        try {
          if (map['dimensions'] == null) return null;
          final dimensionsMap = json.decode(map['dimensions']);
          return Dimensions.fromJson(dimensionsMap);
        } catch (e) {
          _logger.e('Error parsing dimensions from database: $e');
          return null;
        }
      }

      List<Review> parseReviews() {
        try {
          if (map['reviews'] == null) return [];
          final reviewsList = json.decode(map['reviews']) as List;
          return reviewsList.map((r) => Review.fromJson(r)).toList();
        } catch (e) {
          _logger.e('Error parsing reviews from database: $e');
          return [];
        }
      }

      ProductMeta? parseMeta() {
        try {
          if (map['meta'] == null) return null;
          final metaMap = json.decode(map['meta']);
          return ProductMeta.fromJson(metaMap);
        } catch (e) {
          _logger.e('Error parsing meta from database: $e');
          return null;
        }
      }

      return ProductModel(
        id: map['id'],
        title: map['title'] ?? 'Unknown',
        description: map['description'] ?? '',
        price: map['price'] ?? 0.0,
        discountPercentage: map['discountPercentage'] ?? 0.0,
        rating: map['rating'] ?? 0.0,
        stock: map['stock'] ?? 0,
        brand: map['brand'] ?? 'Unknown',
        category: map['category'] ?? 'Unknown',
        thumbnail: map['thumbnail'] ?? '',
        images: parseImages(),
        tags: parseTags(),
        sku: map['sku'] ?? '',
        weight: map['weight'] ?? 0.0,
        dimensions: parseDimensions(),
        warrantyInformation: map['warrantyInformation'] ?? '',
        shippingInformation: map['shippingInformation'] ?? '',
        availabilityStatus: map['availabilityStatus'] ?? 'In Stock',
        reviews: parseReviews(),
        returnPolicy: map['returnPolicy'] ?? '',
        minimumOrderQuantity: map['minimumOrderQuantity'] ?? 1,
        meta: parseMeta(),
      );
    } catch (e) {
      _logger.e('Error parsing product from database: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'discountPercentage': discountPercentage,
      'rating': rating,
      'stock': stock,
      'brand': brand,
      'category': category,
      'thumbnail': thumbnail,
      'images': json.encode(images),
      'tags': json.encode(tags),
      'sku': sku,
      'weight': weight,
      'dimensions': dimensions != null
          ? json.encode(dimensions!.toJson())
          : null,
      'warrantyInformation': warrantyInformation,
      'shippingInformation': shippingInformation,
      'availabilityStatus': availabilityStatus,
      'reviews': reviews.isNotEmpty
          ? json.encode(reviews.map((r) => r.toJson()).toList())
          : null,
      'returnPolicy': returnPolicy,
      'minimumOrderQuantity': minimumOrderQuantity,
      'meta': meta != null ? json.encode(meta!.toJson()) : null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
