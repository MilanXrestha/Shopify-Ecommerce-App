import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../common/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/product_model.dart';

class ProductsRepository {
  // State notifiers
  final ValueNotifier<List<ProductModel>> products =
      ValueNotifier<List<ProductModel>>([]);
  final ValueNotifier<List<ProductModel>> favorites =
      ValueNotifier<List<ProductModel>>([]);
  final ValueNotifier<List<ProductModel>> cartItems =
      ValueNotifier<List<ProductModel>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> hasMoreProducts = ValueNotifier<bool>(true);

  // Pagination state
  int _currentPage = 0;
  final int _pageSize = AppConstants.defaultPageSize;
  bool _hasMoreItems = true;

  // Filtering state
  String? _currentSearchQuery;
  String? _currentCategory;
  double? _minPrice;
  double? _maxPrice;
  String? _currentBrand;
  List<String>? _currentTags;
  String? _sortBy;
  bool _sortAscending = true;
  String? _availabilityStatus;
  double? _minRating;

  // Persisted filter state
  Map<String, dynamic> _lastAppliedFilters = {};

  // Dependencies
  final ApiClient _apiClient;
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();

  // Constructor
  ProductsRepository(this._apiClient, this._databaseHelper) {
    _logger.i('ProductsRepository initialized');
    _loadFavorites();
  }

  // Load favorites initially
  Future<void> _loadFavorites() async {
    try {
      final favProducts = await getFavoriteProducts();
      favorites.value = favProducts;
    } catch (e) {
      _logger.e('Error loading initial favorites: $e');
    }
  }

  // Load products with pagination
  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      _logger.i('Refreshing products data');
      _currentPage = 0;
      _hasMoreItems = true;
      hasMoreProducts.value = true;
      products.value = [];
    }

    if (!_hasMoreItems || isLoading.value) {
      _logger.d(
        'Skipping product load: hasMoreItems=$_hasMoreItems, isLoading=${isLoading.value}',
      );
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      final skip = _currentPage * _pageSize;

      _logger.i(
        'Loading products: page=$_currentPage, skip=$skip, search=$_currentSearchQuery, category=$_currentCategory',
      );

      dynamic response;

      // Build query parameters
      final Map<String, dynamic> queryParams = {
        'limit': _pageSize,
        'skip': skip,
      };

      // Add price filters if set
      if (_minPrice != null) queryParams['minPrice'] = _minPrice;
      if (_maxPrice != null) queryParams['maxPrice'] = _maxPrice;

      // Add brand filter if set
      if (_currentBrand != null && _currentBrand!.isNotEmpty) {
        queryParams['brand'] = _currentBrand;
      }

      // Add availability filter if set
      if (_availabilityStatus != null) {
        queryParams['availabilityStatus'] = _availabilityStatus;
      }

      // Add rating filter if set
      if (_minRating != null) {
        queryParams['minRating'] = _minRating;
      }

      // Add sort parameters if set
      if (_sortBy != null) {
        queryParams['sortBy'] = _sortBy;
        queryParams['sortOrder'] = _sortAscending ? 'asc' : 'desc';
      }

      // Handle search query
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        response = await _apiClient.get(
          '/products/search',
          queryParameters: {...queryParams, 'q': _currentSearchQuery},
        );
      }
      // Handle category filter
      else if (_currentCategory != null && _currentCategory!.isNotEmpty) {
        response = await _apiClient.get(
          '/products/category/$_currentCategory',
          queryParameters: queryParams,
        );
      }
      // Handle tag filter
      else if (_currentTags != null && _currentTags!.isNotEmpty) {
        // DummyJSON might not support direct tag filtering, so we'll do it client-side
        response = await _apiClient.get(
          '/products',
          queryParameters: queryParams,
        );
      }
      // Standard product listing
      else {
        response = await _apiClient.get(
          '/products',
          queryParameters: queryParams,
        );
      }

      _logger.d('API response received: $response');

      if (response == null) {
        throw ServerException('Empty response from server');
      }

      if (!(response is Map) || !response.containsKey('products')) {
        _logger.e('Invalid response format: $response');
        throw ServerException(
          'Invalid response format: missing products field',
        );
      }

      final List<dynamic> productsJson = response['products'];
      final int? total = response['total'];

      _logger.d(
        'Parsed ${productsJson.length} products from response (total: $total)',
      );

      final List<ProductModel> newProducts = [];

      for (var productJson in productsJson) {
        try {
          final product = ProductModel.fromJson(productJson);

          // Apply tag filtering if needed (client-side)
          if (_currentTags != null && _currentTags!.isNotEmpty) {
            bool containsTag = _currentTags!.any(
              (tag) => product.tags.any(
                (productTag) =>
                    productTag.toLowerCase().contains(tag.toLowerCase()),
              ),
            );

            if (!containsTag) continue;
          }

          newProducts.add(product);
        } catch (e) {
          _logger.e('Error parsing product: $e, data: $productJson');
        }
      }

      _logger.i('Successfully parsed ${newProducts.length} products');

      _logger.d('Caching ${newProducts.length} products to database');
      for (var product in newProducts) {
        await _databaseHelper.insertProduct(product.toMap());
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_sync_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      if (newProducts.length < _pageSize ||
          (total != null && (skip + newProducts.length) >= total)) {
        _logger.d('Reached end of products list');
        _hasMoreItems = false;
        hasMoreProducts.value = false;
      }

      if (refresh) {
        products.value = newProducts;
      } else {
        products.value = [...products.value, ...newProducts];
      }

      _logger.i(
        'Products loaded successfully. Total: ${products.value.length}',
      );

      _currentPage++;
    } catch (e) {
      _logger.e('Error loading products: $e');
      error.value = e.toString();

      if (products.value.isEmpty) {
        _logger.i('Attempting to load products from cache');
        try {
          final cachedProducts = await _databaseHelper.getProducts(
            limit: _pageSize,
            offset: _currentPage * _pageSize,
            search: _currentSearchQuery,
            category: _currentCategory,
          );

          if (cachedProducts.isNotEmpty) {
            _logger.i('Loaded ${cachedProducts.length} products from cache');
            final List<ProductModel> mappedProducts = [];

            for (var productMap in cachedProducts) {
              try {
                final product = ProductModel.fromDatabase(productMap);
                bool shouldInclude = true;

                // Apply client-side filters
                if (_minPrice != null && product.discountedPrice < _minPrice!) {
                  shouldInclude = false;
                }

                if (_maxPrice != null && product.discountedPrice > _maxPrice!) {
                  shouldInclude = false;
                }

                if (_currentBrand != null &&
                    _currentBrand!.isNotEmpty &&
                    product.brand.toLowerCase() !=
                        _currentBrand!.toLowerCase()) {
                  shouldInclude = false;
                }

                if (_minRating != null && product.rating < _minRating!) {
                  shouldInclude = false;
                }

                if (_availabilityStatus != null &&
                    product.availabilityStatus != _availabilityStatus) {
                  shouldInclude = false;
                }

                if (_currentTags != null && _currentTags!.isNotEmpty) {
                  bool containsTag = _currentTags!.any(
                    (tag) => product.tags.any(
                      (productTag) =>
                          productTag.toLowerCase().contains(tag.toLowerCase()),
                    ),
                  );

                  if (!containsTag) shouldInclude = false;
                }

                if (shouldInclude) {
                  mappedProducts.add(product);
                }
              } catch (e) {
                _logger.e('Error parsing cached product: $e');
              }
            }

            // Apply sorting to cached products
            if (_sortBy != null) {
              _applySorting(mappedProducts);
            }

            products.value = mappedProducts;
            _logger.i(
              'Set products value with ${mappedProducts.length} cached products',
            );
          } else {
            _logger.w('No cached products found');
          }
        } catch (dbError) {
          _logger.e('Database error: $dbError');
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Apply sorting to a list of products
  void _applySorting(List<ProductModel> productsList) {
    if (_sortBy == null) return;

    switch (_sortBy) {
      case 'price':
        productsList.sort(
          (a, b) => _sortAscending
              ? a.price.compareTo(b.price)
              : b.price.compareTo(a.price),
        );
        break;
      case 'discountedPrice':
        productsList.sort(
          (a, b) => _sortAscending
              ? a.discountedPrice.compareTo(b.discountedPrice)
              : b.discountedPrice.compareTo(a.discountedPrice),
        );
        break;
      case 'rating':
        productsList.sort(
          (a, b) => _sortAscending
              ? a.rating.compareTo(b.rating)
              : b.rating.compareTo(a.rating),
        );
        break;
      case 'discount':
        productsList.sort(
          (a, b) => _sortAscending
              ? a.discountPercentage.compareTo(b.discountPercentage)
              : b.discountPercentage.compareTo(a.discountPercentage),
        );
        break;
      case 'stock':
        productsList.sort(
          (a, b) => _sortAscending
              ? a.stock.compareTo(b.stock)
              : b.stock.compareTo(a.stock),
        );
        break;
      case 'date':
        productsList.sort((a, b) {
          final aDate =
              a.meta?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.meta?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return _sortAscending
              ? aDate.compareTo(bDate)
              : bDate.compareTo(aDate);
        });
        break;
      case 'title':
        productsList.sort(
          (a, b) => _sortAscending
              ? a.title.compareTo(b.title)
              : b.title.compareTo(a.title),
        );
        break;
      case 'popularity':
      default:
        productsList.sort((a, b) {
          final aScore = a.rating * 20 + (a.discountPercentage > 0 ? 10 : 0);
          final bScore = b.rating * 20 + (b.discountPercentage > 0 ? 10 : 0);
          return _sortAscending
              ? aScore.compareTo(bScore)
              : bScore.compareTo(aScore);
        });
        break;
    }
  }

  // Set sorting options
  void setSorting(String sortBy, {bool ascending = true}) {
    _sortBy = sortBy;
    _sortAscending = ascending;

    // Apply sorting to current products
    if (products.value.isNotEmpty) {
      List<ProductModel> sortedProducts = List.from(products.value);
      _applySorting(sortedProducts);
      products.value = sortedProducts;
    }
  }

  // Isolated search method
  Future<List<ProductModel>> searchProducts(
    String query, {
    int limit = 20,
    int skip = 0,
  }) async {
    _logger.i(
      'Searching products with query: $query, limit: $limit, skip: $skip',
    );

    try {
      final response = await _apiClient.get(
        '/products/search',
        queryParameters: {'q': query, 'limit': limit, 'skip': skip},
      );

      _logger.d('Search API response received: $response');

      if (response == null) {
        throw ServerException('Empty response from server');
      }

      if (!(response is Map) || !response.containsKey('products')) {
        _logger.e('Invalid response format: $response');
        throw ServerException(
          'Invalid response format: missing products field',
        );
      }

      final List<dynamic> productsJson = response['products'];
      final List<ProductModel> searchResults = [];

      for (var productJson in productsJson) {
        try {
          final product = ProductModel.fromJson(productJson);
          searchResults.add(product);
        } catch (e) {
          _logger.e('Error parsing search product: $e, data: $productJson');
        }
      }

      _logger.i('Successfully parsed ${searchResults.length} search results');

      for (var product in searchResults) {
        await _databaseHelper.insertProduct(product.toMap());
      }

      return searchResults;
    } catch (e) {
      _logger.e('Error searching products: $e');

      try {
        final cachedProducts = await _databaseHelper.getProducts(
          limit: limit,
          offset: skip,
          search: query,
        );

        if (cachedProducts.isNotEmpty) {
          _logger.i(
            'Loaded ${cachedProducts.length} search results from cache',
          );
          final List<ProductModel> mappedProducts = [];

          for (var productMap in cachedProducts) {
            try {
              final product = ProductModel.fromDatabase(productMap);
              mappedProducts.add(product);
            } catch (e) {
              _logger.e('Error parsing cached product: $e');
            }
          }

          return mappedProducts;
        } else {
          _logger.w('No cached search results found');
          rethrow;
        }
      } catch (dbError) {
        _logger.e('Database error: $dbError');
        rethrow;
      }
    }
  }

  // Apply advanced filtering with all possible filters
  Future<void> applyFilters({
    double? minPrice,
    double? maxPrice,
    String? brand,
    String? category,
    List<String>? tags,
    double? minRating,
    String? availabilityStatus,
    String? sortBy,
    bool? sortAscending,
  }) async {
    _logger.i(
      'Applying advanced filters: minPrice=$minPrice, maxPrice=$maxPrice, '
      'brand=$brand, category=$category, tags=$tags, minRating=$minRating, '
      'availabilityStatus=$availabilityStatus, sortBy=$sortBy, sortAscending=$sortAscending',
    );

    // Store all filter parameters
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _currentBrand = brand;
    _currentCategory = category;
    _currentTags = tags;
    _minRating = minRating;
    _availabilityStatus = availabilityStatus;

    // Set sort parameters if provided
    if (sortBy != null) {
      _sortBy = sortBy;
    }

    if (sortAscending != null) {
      _sortAscending = sortAscending;
    }

    // Clear search when applying filters
    _currentSearchQuery = null;

    // Reset pagination
    _currentPage = 0;
    _hasMoreItems = true;
    hasMoreProducts.value = true;

    // Store last applied filters for later use
    _lastAppliedFilters = {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'brand': brand,
      'category': category,
      'tags': tags,
      'minRating': minRating,
      'availabilityStatus': availabilityStatus,
      'sortBy': sortBy,
      'sortAscending': sortAscending,
    };

    // Load products with new filters
    await loadProducts(refresh: true);

    _logger.d('Filtered to ${products.value.length} products');
  }

  // Filter products by category
  void setCategory(String category) {
    if (_currentCategory != category) {
      _logger.i('Setting category filter: $category');
      _currentCategory = category;
      _currentSearchQuery = null;
      _minPrice = null;
      _maxPrice = null;
      _currentBrand = null;
      _currentTags = null;
      _minRating = null;
      _availabilityStatus = null;
      loadProducts(refresh: true);
    }
  }

  // Clear category filter
  void clearCategory() {
    if (_currentCategory != null) {
      _logger.i('Clearing category filter');
      _currentCategory = null;
      loadProducts(refresh: true);
    }
  }

  // Search products
  void search(String query) {
    if (_currentSearchQuery != query) {
      _logger.i('Setting search query: $query');
      _currentSearchQuery = query;
      _currentCategory = null;
      _minPrice = null;
      _maxPrice = null;
      _currentBrand = null;
      _currentTags = null;
      _minRating = null;
      _availabilityStatus = null;
      loadProducts(refresh: true);
    }
  }

  // Clear search
  void clearSearch() {
    if (_currentSearchQuery != null) {
      _logger.i('Clearing search query');
      _currentSearchQuery = null;
      loadProducts(refresh: true);
    }
  }

  // Clear all filters
  void clearAllFilters() {
    _logger.i('Clearing all filters');
    _currentCategory = null;
    _currentSearchQuery = null;
    _minPrice = null;
    _maxPrice = null;
    _currentBrand = null;
    _currentTags = null;
    _minRating = null;
    _availabilityStatus = null;
    _sortBy = null;
    _sortAscending = true;
    _lastAppliedFilters = {};
    loadProducts(refresh: true);
  }

  // Get product details by ID
  Future<ProductModel?> getProductById(int id) async {
    _logger.i('Getting product details for id: $id');
    try {
      final response = await _apiClient.get('/products/$id');
      _logger.d('Product details fetched from API');

      if (response == null) {
        throw ServerException('Empty response from server');
      }

      final product = ProductModel.fromJson(response);

      await _databaseHelper.insertProduct(product.toMap());
      _logger.d('Product details cached to database');

      return product;
    } catch (e) {
      _logger.w('Error fetching product details from API: $e');
      _logger.i('Attempting to load product from cache');

      try {
        final productMap = await _databaseHelper.getProduct(id);
        if (productMap != null) {
          _logger.i('Product details loaded from cache');
          return ProductModel.fromDatabase(productMap);
        }
      } catch (dbError) {
        _logger.e('Database error when fetching product: $dbError');
      }

      _logger.e('Product not found in cache');
      rethrow;
    }
  }

  // Get products with similar characteristics to the given product
  Future<List<ProductModel>> getSimilarProducts(
    ProductModel product, {
    int limit = 5,
  }) async {
    _logger.i('Getting similar products for product ID: ${product.id}');

    try {
      // Use existing products if available to avoid API call
      if (products.value.isNotEmpty) {
        final List<ProductModel> similarProducts = [];
        final List<ProductModel> allProducts = List.from(products.value);

        // Remove the current product from the list
        allProducts.removeWhere((p) => p.id == product.id);

        // First, try to find products in the same category
        final sameCategory = allProducts
            .where((p) => p.category == product.category)
            .toList();

        // Calculate similarity scores
        final scoredProducts = sameCategory.map((p) {
          int score = 0;

          // Same brand
          if (p.brand == product.brand) score += 10;

          // Similar price range (+/- 30%)
          if (p.price >= product.price * 0.7 && p.price <= product.price * 1.3)
            score += 5;

          // Similar rating (+/- 1 star)
          if ((p.rating - product.rating).abs() <= 1.0) score += 3;

          // Common tags
          for (final tag in p.tags) {
            if (product.tags.contains(tag)) score += 2;
          }

          return {'product': p, 'score': score};
        }).toList();

        // Sort by similarity score
        scoredProducts.sort(
          (a, b) => (b['score'] as int).compareTo(a['score'] as int),
        );

        // Get top matches
        for (final scored in scoredProducts.take(limit)) {
          similarProducts.add(scored['product'] as ProductModel);
        }

        // If we still need more items, add products from other categories
        if (similarProducts.length < limit) {
          final otherProducts = allProducts
              .where((p) => p.category != product.category)
              .toList();

          // Calculate similarity for other category products
          final otherScored = otherProducts.map((p) {
            int score = 0;

            // Similar price range
            if (p.price >= product.price * 0.7 &&
                p.price <= product.price * 1.3)
              score += 5;

            // Similar rating
            if ((p.rating - product.rating).abs() <= 1.0) score += 3;

            // Common tags
            for (final tag in p.tags) {
              if (product.tags.contains(tag)) score += 2;
            }

            return {'product': p, 'score': score};
          }).toList();

          otherScored.sort(
            (a, b) => (b['score'] as int).compareTo(a['score'] as int),
          );

          // Add remaining products to reach the limit
          for (final scored in otherScored.take(
            limit - similarProducts.length,
          )) {
            similarProducts.add(scored['product'] as ProductModel);
          }
        }

        _logger.i('Found ${similarProducts.length} similar products');
        return similarProducts;
      }
      // If no products are loaded, fetch from API
      else {
        final response = await _apiClient.get(
          '/products/category/${product.category}',
          queryParameters: {
            'limit': limit + 1,
          }, // +1 to account for the current product
        );

        if (response == null) {
          throw ServerException('Empty response from server');
        }

        if (!(response is Map) || !response.containsKey('products')) {
          throw ServerException('Invalid response format');
        }

        final List<dynamic> productsJson = response['products'];
        final List<ProductModel> similarProducts = [];

        for (final productJson in productsJson) {
          try {
            final p = ProductModel.fromJson(productJson);
            if (p.id != product.id) {
              similarProducts.add(p);
              if (similarProducts.length >= limit) break;
            }
          } catch (e) {
            _logger.e('Error parsing similar product: $e');
          }
        }

        _logger.i('Found ${similarProducts.length} similar products from API');
        return similarProducts;
      }
    } catch (e) {
      _logger.e('Error getting similar products: $e');
      return [];
    }
  }

  // Get top-rated products for featured section
  List<ProductModel> getTopRatedProducts({int limit = 5}) {
    if (products.value.isEmpty) {
      _logger.w('No products available for getTopRatedProducts');
      return [];
    }

    try {
      // First try to sort by the average review rating
      final sortedProducts = List<ProductModel>.from(products.value)
        ..sort((a, b) {
          // Use average review rating if available, otherwise fall back to product rating
          final aRating = a.reviews.isNotEmpty
              ? a.averageReviewRating
              : a.rating;
          final bRating = b.reviews.isNotEmpty
              ? b.averageReviewRating
              : b.rating;
          return bRating.compareTo(aRating);
        });

      final result = sortedProducts.take(limit).toList();
      _logger.d(
        'Returning top $limit rated products from ${products.value.length} total',
      );
      return result;
    } catch (e) {
      _logger.e('Error getting top rated products: $e');

      // Fallback to basic rating if there's an error
      final sortedProducts = List<ProductModel>.from(products.value)
        ..sort((a, b) => b.rating.compareTo(a.rating));

      return sortedProducts.take(limit).toList();
    }
  }

  // Get products with highest discount for sales section
  List<ProductModel> getTopDiscountedProducts({int limit = 5}) {
    if (products.value.isEmpty) {
      _logger.w('No products available for getTopDiscountedProducts');
      return [];
    }

    try {
      // Sort by discount percentage and then by price to get the best deals
      final sortedProducts = List<ProductModel>.from(products.value)
        ..sort((a, b) {
          // First compare by discount percentage
          final discountComparison = b.discountPercentage.compareTo(
            a.discountPercentage,
          );

          // If discount percentages are equal, compare by original price
          if (discountComparison == 0) {
            return b.price.compareTo(a.price);
          }

          return discountComparison;
        });

      // Only include products with actual discounts
      final discountedProducts = sortedProducts
          .where((product) => product.discountPercentage > 0)
          .take(limit)
          .toList();

      _logger.d('Returning top $limit discounted products');
      return discountedProducts;
    } catch (e) {
      _logger.e('Error getting top discounted products: $e');

      // Simple fallback
      final sortedProducts = List<ProductModel>.from(products.value)
        ..sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));

      return sortedProducts.take(limit).toList();
    }
  }

  // Get most recent products (newest arrivals)
  List<ProductModel> getNewestProducts({int limit = 5}) {
    if (products.value.isEmpty) {
      _logger.w('No products available for getNewestProducts');
      return [];
    }

    try {
      // Create a copy of the products list
      List<ProductModel> sortedProducts = List.from(products.value);

      // Sort by createdAt date in descending order (newest first)
      sortedProducts.sort((a, b) {
        // Handle cases where meta might be null
        DateTime aDate =
            a.meta?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime bDate =
            b.meta?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        // Sort in descending order (newest first)
        return bDate.compareTo(aDate);
      });

      _logger.d('Returning $limit newest products based on creation date');

      // If we have a small number of products, return all of them
      if (sortedProducts.length <= limit) {
        return sortedProducts;
      }

      // Otherwise, return the most recent ones
      return sortedProducts.take(limit).toList();
    } catch (e) {
      _logger.e('Error getting newest products: $e');

      // Fallback to original implementation if sorting fails
      _logger.d('Falling back to default product order for newest products');
      return products.value.take(limit).toList();
    }
  }

  // Get products by brand
  List<ProductModel> getProductsByBrand(String brand, {int limit = 10}) {
    if (products.value.isEmpty) {
      _logger.w('No products available for getProductsByBrand');
      return [];
    }

    try {
      final filteredProducts = products.value
          .where(
            (product) => product.brand.toLowerCase() == brand.toLowerCase(),
          )
          .toList();

      // Sort by popularity within the brand
      filteredProducts.sort((a, b) {
        final aScore = a.rating * 15 + (a.discountPercentage > 0 ? 10 : 0);
        final bScore = b.rating * 15 + (b.discountPercentage > 0 ? 10 : 0);
        return bScore.compareTo(aScore);
      });

      _logger.d('Found ${filteredProducts.length} products for brand: $brand');
      return filteredProducts.take(limit).toList();
    } catch (e) {
      _logger.e('Error getting products by brand: $e');

      // Simple fallback
      return products.value
          .where(
            (product) => product.brand.toLowerCase() == brand.toLowerCase(),
          )
          .take(limit)
          .toList();
    }
  }

  // Get products by tags
  List<ProductModel> getProductsByTags(List<String> tags, {int limit = 10}) {
    if (products.value.isEmpty) {
      _logger.w('No products available for getProductsByTags');
      return [];
    }

    try {
      // Find products that contain any of the specified tags
      final filteredProducts = products.value
          .where(
            (product) => tags.any(
              (tag) => product.tags.any(
                (productTag) =>
                    productTag.toLowerCase().contains(tag.toLowerCase()),
              ),
            ),
          )
          .toList();

      _logger.d('Found ${filteredProducts.length} products for tags: $tags');
      return filteredProducts.take(limit).toList();
    } catch (e) {
      _logger.e('Error getting products by tags: $e');
      return [];
    }
  }

  // Add a product to favorites
  Future<void> toggleFavorite(int productId) async {
    _logger.i('Toggling favorite for product ID: $productId');
    try {
      await _databaseHelper.toggleFavorite(productId);
      _logger.d('Favorite toggled successfully');

      // Update favorites list
      final favProducts = await getFavoriteProducts();
      favorites.value = favProducts;
    } catch (e) {
      _logger.e('Error toggling favorite: $e');
      rethrow;
    }
  }

  // Check if a product is in favorites
  Future<bool> isFavorite(int productId) async {
    try {
      final result = await _databaseHelper.isFavorite(productId);
      _logger.d('Product $productId favorite status: $result');
      return result;
    } catch (e) {
      _logger.e('Error checking favorite status: $e');
      return false;
    }
  }

  // Get all favorite products
  Future<List<ProductModel>> getFavoriteProducts() async {
    _logger.i('Getting favorite products');
    try {
      final favoritesMap = await _databaseHelper.getFavorites();
      final List<ProductModel> favoriteProducts = [];

      for (var map in favoritesMap) {
        try {
          final product = ProductModel.fromDatabase(map);
          favoriteProducts.add(product);
        } catch (e) {
          _logger.e('Error parsing favorite product: $e');
        }
      }

      _logger.d('Retrieved ${favoriteProducts.length} favorite products');
      return favoriteProducts;
    } catch (e) {
      _logger.e('Error getting favorite products: $e');
      return [];
    }
  }

  // Get all unique tags across all products
  List<String> getAllTags() {
    if (products.value.isEmpty) {
      return [];
    }

    try {
      final Set<String> allTags = {};

      for (var product in products.value) {
        for (var tag in product.tags) {
          allTags.add(tag);
        }
      }

      final List<String> sortedTags = allTags.toList()..sort();
      _logger.d('Found ${sortedTags.length} unique tags');
      return sortedTags;
    } catch (e) {
      _logger.e('Error getting all tags: $e');
      return [];
    }
  }

  // Get product price range for filtering
  Map<String, double> getPriceRange() {
    if (products.value.isEmpty) {
      return {'min': 0, 'max': 1000};
    }

    try {
      double minPrice = double.infinity;
      double maxPrice = 0;

      for (var product in products.value) {
        final price = product.discountedPrice;
        if (price < minPrice) {
          minPrice = price;
        }
        if (price > maxPrice) {
          maxPrice = price;
        }
      }

      _logger.d('Price range: min=$minPrice, max=$maxPrice');
      return {'min': minPrice, 'max': maxPrice};
    } catch (e) {
      _logger.e('Error calculating price range: $e');
      return {'min': 0, 'max': 1000};
    }
  }

  // Get all unique brands for filtering
  List<String> getUniqueBrands() {
    if (products.value.isEmpty) {
      return [];
    }

    try {
      final Set<String> brands = {};

      for (var product in products.value) {
        if (product.brand.isNotEmpty) {
          brands.add(product.brand);
        }
      }

      final List<String> sortedBrands = brands.toList()..sort();
      _logger.d('Found ${sortedBrands.length} unique brands');
      return sortedBrands;
    } catch (e) {
      _logger.e('Error getting unique brands: $e');
      return [];
    }
  }

  // Get availability statuses
  List<String> getAvailabilityStatuses() {
    if (products.value.isEmpty) {
      return ['In Stock', 'Out of Stock', 'Pre-order'];
    }

    try {
      final Set<String> statuses = {};

      for (var product in products.value) {
        if (product.availabilityStatus.isNotEmpty) {
          statuses.add(product.availabilityStatus);
        }
      }

      final List<String> sortedStatuses = statuses.toList()..sort();
      _logger.d('Found ${sortedStatuses.length} availability statuses');
      return sortedStatuses;
    } catch (e) {
      _logger.e('Error getting availability statuses: $e');
      return ['In Stock', 'Out of Stock', 'Pre-order'];
    }
  }

  // Get count of products
  int get productCount => products.value.length;

  // Check if products are loaded
  bool get hasProducts => products.value.isNotEmpty;

  // Get current loading state
  bool get isCurrentlyLoading => isLoading.value;

  // Get last applied filters
  Map<String, dynamic> getLastFilters() => _lastAppliedFilters;

  // Add to the ProductsRepository class

  // Load all products before applying filters
  Future<void> loadAllProductsForFiltering({
    required Function(int count, int total) onProgress,
    int maxPages = 10, // Safety limit to prevent infinite loading
  }) async {
    if (!hasMoreProducts.value) {
      return; // Already loaded all products
    }

    final initialCount = products.value.length;
    int loadedPages = 0;

    try {
      // Save current filters
      final savedCategory = _currentCategory;
      final savedSearch = _currentSearchQuery;
      final savedMinPrice = _minPrice;
      final savedMaxPrice = _maxPrice;
      final savedBrand = _currentBrand;
      final savedTags = _currentTags;
      final savedRating = _minRating;
      final savedAvailability = _availabilityStatus;
      final savedSortBy = _sortBy;
      final savedSortAscending = _sortAscending;

      // Clear filters temporarily to load all products
      _currentCategory = savedCategory;
      _currentSearchQuery = null;
      _minPrice = null;
      _maxPrice = null;
      _currentBrand = null;
      _currentTags = null;
      _minRating = null;
      _availabilityStatus = null;

      // Reset pagination
      int originalPage = _currentPage;
      _currentPage = 0;
      _hasMoreItems = true;
      hasMoreProducts.value = true;

      // Store original products to restore if needed
      final originalProducts = List<ProductModel>.from(products.value);

      // Load first page
      await loadProducts(refresh: true);
      loadedPages++;

      // Report progress
      onProgress(products.value.length, -1); // -1 means unknown total

      // Load remaining pages
      while (_hasMoreItems && loadedPages < maxPages) {
        await loadProducts();
        loadedPages++;

        // Report progress
        onProgress(products.value.length, -1);
      }

      _logger.i('Loaded all available products: ${products.value.length}');

      // Restore filters
      _currentCategory = savedCategory;
      _currentSearchQuery = savedSearch;
      _minPrice = savedMinPrice;
      _maxPrice = savedMaxPrice;
      _currentBrand = savedBrand;
      _currentTags = savedTags;
      _minRating = savedRating;
      _availabilityStatus = savedAvailability;
      _sortBy = savedSortBy;
      _sortAscending = savedSortAscending;

      // Apply client-side filtering
      _applyClientSideFiltering();
    } catch (e) {
      _logger.e('Error loading all products: $e');
      throw e;
    }
  }

  // Apply filters on the client side after loading all products
  void _applyClientSideFiltering() {
    if (products.value.isEmpty) return;

    List<ProductModel> filteredProducts = List.from(products.value);

    // Apply filters
    if (_minPrice != null) {
      filteredProducts = filteredProducts
          .where((p) => p.discountedPrice >= _minPrice!)
          .toList();
    }

    if (_maxPrice != null) {
      filteredProducts = filteredProducts
          .where((p) => p.discountedPrice <= _maxPrice!)
          .toList();
    }

    if (_currentBrand != null && _currentBrand!.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((p) => p.brand.toLowerCase() == _currentBrand!.toLowerCase())
          .toList();
    }

    if (_minRating != null) {
      filteredProducts = filteredProducts
          .where((p) => p.rating >= _minRating!)
          .toList();
    }

    if (_availabilityStatus != null) {
      filteredProducts = filteredProducts
          .where((p) => p.availabilityStatus == _availabilityStatus)
          .toList();
    }

    if (_currentTags != null && _currentTags!.isNotEmpty) {
      filteredProducts = filteredProducts
          .where(
            (p) => _currentTags!.any(
              (tag) => p.tags.any(
                (t) => t.toLowerCase().contains(tag.toLowerCase()),
              ),
            ),
          )
          .toList();
    }

    // Apply sorting
    _applySorting(filteredProducts);

    // Update the products value notifier
    products.value = filteredProducts;
  }

  // For use in debug panel
  String get debugInfo {
    return 'Products: ${products.value.length}\n'
        'Page: $_currentPage\n'
        'Has more: $_hasMoreItems\n'
        'Search: $_currentSearchQuery\n'
        'Category: $_currentCategory\n'
        'Price: $_minPrice - $_maxPrice\n'
        'Brand: $_currentBrand\n'
        'Tags: $_currentTags\n'
        'Min Rating: $_minRating\n'
        'Availability: $_availabilityStatus\n'
        'Sort By: $_sortBy (${_sortAscending ? 'Ascending' : 'Descending'})\n'
        'Last Filters: $_lastAppliedFilters';
  }

  // Add a parameter to apply filtering immediately
  Future<void> applyFiltersComprehensive({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? brand,
    List<String>? tags,
    double? minRating,
    String? availabilityStatus,
    String? sortBy,
    bool? sortAscending,
    bool loadAllProducts = false,
    Function(int count, int total)? onProgress,
    bool applyImmediately = false, // New parameter
  }) async {
    // Store filter parameters
    _currentCategory = category;
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _currentBrand = brand;
    _currentTags = tags;
    _minRating = minRating;
    _availabilityStatus = availabilityStatus;

    // Set sort parameters if provided
    if (sortBy != null) {
      _sortBy = sortBy;
    }

    if (sortAscending != null) {
      _sortAscending = sortAscending;
    }

    // If we need to apply filtering immediately to current dataset
    if (applyImmediately && products.value.isNotEmpty) {
      _applyClientSideFiltering();
    }

    // Reset pagination for a fresh query
    _currentPage = 0;
    _hasMoreItems = true;
    hasMoreProducts.value = true;

    // Clear search when applying filters
    _currentSearchQuery = null;

    // If we need to load all products for accurate filtering
    if (loadAllProducts) {
      await loadAllProductsForFiltering(
        onProgress: onProgress ?? ((count, total) {}),
      );
    } else {
      // Standard API filtering
      await loadProducts(refresh: true);
    }

    _logger.d('Filtered to ${products.value.length} products');

    // Store last applied filters
    _lastAppliedFilters = {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'brand': brand,
      'category': category,
      'tags': tags,
      'minRating': minRating,
      'availabilityStatus': availabilityStatus,
      'sortBy': sortBy,
      'sortAscending': sortAscending,
    };
  }
}
