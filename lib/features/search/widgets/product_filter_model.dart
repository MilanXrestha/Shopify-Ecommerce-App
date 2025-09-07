// lib/features/products/data/models/product_filter_model.dart
import 'package:flutter/foundation.dart';

class ProductFilterModel {
  String sortOption;
  double? minPrice;
  double? maxPrice;
  String? selectedBrand;
  List<String>? selectedTags;
  double? minRating;
  String? availabilityStatus;

  // Mapping of UI sort options to repository sort options
  static final Map<String, Map<String, dynamic>> sortMapping = {
    'Popular': {'sortBy': 'popularity', 'ascending': false},
    'Price: Low to High': {'sortBy': 'price', 'ascending': true},
    'Price: High to Low': {'sortBy': 'price', 'ascending': false},
    'Rating: High to Low': {'sortBy': 'rating', 'ascending': false},
    'Discount: High to Low': {'sortBy': 'discount', 'ascending': false},
    'Newest First': {'sortBy': 'date', 'ascending': false},
    'Name: A-Z': {'sortBy': 'title', 'ascending': true},
    'Name: Z-A': {'sortBy': 'title', 'ascending': false},
  };

  ProductFilterModel({
    this.sortOption = 'Popular',
    this.minPrice,
    this.maxPrice,
    this.selectedBrand,
    this.selectedTags,
    this.minRating,
    this.availabilityStatus,
  });

  ProductFilterModel copyWith({
    String? sortOption,
    double? minPrice,
    double? maxPrice,
    String? selectedBrand,
    List<String>? selectedTags,
    double? minRating,
    String? availabilityStatus,
  }) {
    return ProductFilterModel(
      sortOption: sortOption ?? this.sortOption,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      selectedBrand: selectedBrand ?? this.selectedBrand,
      selectedTags: selectedTags ?? this.selectedTags,
      minRating: minRating ?? this.minRating,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
    );
  }

  Map<String, dynamic> toRepositoryParams() {
    final sortParams =
        sortMapping[sortOption] ?? {'sortBy': 'popularity', 'ascending': false};

    return {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'brand': selectedBrand,
      'tags': selectedTags,
      'minRating': minRating,
      'availabilityStatus': availabilityStatus,
      'sortBy': sortParams['sortBy'],
      'sortAscending': sortParams['ascending'],
    };
  }

  bool get hasActiveFilters =>
      minPrice != null ||
      maxPrice != null ||
      selectedBrand != null ||
      (selectedTags != null && selectedTags!.isNotEmpty) ||
      minRating != null ||
      availabilityStatus != null ||
      sortOption != 'Popular';

  void clear() {
    sortOption = 'Popular';
    minPrice = null;
    maxPrice = null;
    selectedBrand = null;
    selectedTags = null;
    minRating = null;
    availabilityStatus = null;
  }
}
