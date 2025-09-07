import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../models/category_model.dart';

class CategoriesRepository {
  final ValueNotifier<List<CategoryModel>> categories =
      ValueNotifier<List<CategoryModel>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  final ApiClient _apiClient;
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();

  CategoriesRepository(this._apiClient, this._databaseHelper);

  // Method to get access to a ProductsRepository
  ProductsRepository getProductsRepository() {
    _logger.d('Creating a new ProductsRepository from CategoriesRepository');
    return ProductsRepository(_apiClient, _databaseHelper);
  }

  Future<void> loadCategories() async {
    _logger.i('Loading categories');
    isLoading.value = true;
    error.value = null;

    try {
      // Fetch categories from API
      final response = await _apiClient.get('/products/categories');
      _logger.d('Categories response received: $response');

      final List<dynamic> categoriesJson = response;
      _logger.d('Parsed ${categoriesJson.length} categories');

      // Convert JSON maps directly to CategoryModel (do NOT call .toString())
      final List<CategoryModel> remoteCategories = categoriesJson
          .map((category) => CategoryModel.fromJson(category))
          .toList();

      _logger.d(
        'Converted to ${remoteCategories.length} CategoryModel objects',
      );

      // Cache categories in SQLite
      _logger.d('Caching categories to database');
      for (var category in remoteCategories) {
        _logger.d(
          'Inserting category: name=${category.name}, slug=${category.slug}',
        );
        await _databaseHelper.insertCategory(category.toMap());
      }

      // Optional: debug database content
      await _databaseHelper.debugCategories();

      // Load all categories (including local ones) from database
      _logger.d('Loading all categories (including local ones) from database');
      final localCategoriesMap = await _databaseHelper.getCategories();
      final List<CategoryModel> allCategories = localCategoriesMap
          .map((map) => CategoryModel.fromDatabase(map))
          .toList();

      // Sort alphabetically
      allCategories.sort((a, b) => a.name.compareTo(b.name));

      _logger.i(
        'Categories loaded successfully. Total: ${allCategories.length}',
      );
      categories.value = allCategories;
    } catch (e) {
      _logger.e('Error loading categories: $e');
      error.value = e.toString();

      // Try to load from cache if network failed
      _logger.i('Attempting to load categories from cache');
      try {
        final cachedCategoriesMap = await _databaseHelper.getCategories();

        if (cachedCategoriesMap.isNotEmpty) {
          _logger.i(
            'Loaded ${cachedCategoriesMap.length} categories from cache',
          );
          final List<CategoryModel> cachedCategories = cachedCategoriesMap
              .map((map) => CategoryModel.fromDatabase(map))
              .toList();

          // Sort alphabetically
          cachedCategories.sort((a, b) => a.name.compareTo(b.name));

          categories.value = cachedCategories;
        } else {
          _logger.w('No cached categories found');
        }
      } catch (dbError) {
        _logger.e('Database error: $dbError');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addCustomCategory(String name) async {
    _logger.i('Adding custom category: $name');

    // Generate slug from name
    final slug = name.toLowerCase().replaceAll(' ', '-');

    // Format name consistently
    final formattedName = CategoryModel.formatCategoryName(slug);

    // Create CategoryModel
    final newCategory = CategoryModel(
      name: formattedName,
      slug: slug,
      isLocal: true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Save to database
    await _databaseHelper.insertCategory(newCategory.toMap());
    _logger.d(
      'Custom category added: name=${newCategory.name}, slug=${newCategory.slug}',
    );

    // Reload categories after adding
    await loadCategories();
    _logger.i('Categories reloaded after adding custom category');
  }

  // Helper method to get products by category slug
  Future<List<ProductModel>> getProductsByCategory(String categorySlug) async {
    final productsRepo = getProductsRepository();
    productsRepo.setCategory(categorySlug);
    await productsRepo.loadProducts(refresh: true);
    return productsRepo.products.value;
  }
}
