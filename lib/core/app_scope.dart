import 'package:e_commerce_app/features/category/data/repositories/categories_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import 'network/api_client.dart';
import '../features/products/data/repositories/products_repository.dart';
import '../features/cart/data/repositories/cart_repository.dart';

class AppScope extends InheritedWidget {
  final ApiClient apiClient;
  final DatabaseHelper databaseHelper;
  final SharedPreferences sharedPreferences;
  final String baseUrl;
  final ProductsRepository productsRepository;
  final CategoriesRepository categoriesRepository;
  final CartRepository cartRepository;
  // Add the userProfile ValueNotifier as a class field
  final ValueNotifier<Map<String, dynamic>?> userProfile;

  const AppScope({
    super.key,
    required super.child,
    required this.apiClient,
    required this.databaseHelper,
    required this.sharedPreferences,
    required this.baseUrl,
    required this.productsRepository,
    required this.categoriesRepository,
    required this.cartRepository,
    required this.userProfile,
  });

  // Method to load user profile
  Future<void> loadUserProfile() async {
    final profile = await databaseHelper.getUserProfile();
    userProfile.value = profile;
  }

  // Factory method to initialize all dependencies
  static Future<AppScope> initialize() async {
    // Initialize shared preferences
    final sharedPreferences = await SharedPreferences.getInstance();

    // Get base URL from SharedPreferences or use default
    final baseUrl =
        sharedPreferences.getString('base_url') ?? 'https://dummyjson.com';

    // Initialize API client
    final apiClient = ApiClient(baseUrl: baseUrl);

    // Initialize database
    final databaseHelper = DatabaseHelper();
    await databaseHelper.initDatabase();

    // Initialize repositories
    final productsRepository = ProductsRepository(apiClient, databaseHelper);
    final categoriesRepository = CategoriesRepository(apiClient, databaseHelper);
    final cartRepository = CartRepository(databaseHelper, productsRepository);

    // Create the userProfile ValueNotifier
    final userProfile = ValueNotifier<Map<String, dynamic>?>(null);

    // Create the AppScope instance
    final appScope = AppScope(
      apiClient: apiClient,
      databaseHelper: databaseHelper,
      sharedPreferences: sharedPreferences,
      baseUrl: baseUrl,
      productsRepository: productsRepository,
      cartRepository: cartRepository,
      categoriesRepository: categoriesRepository,
      userProfile: userProfile, // Pass the userProfile
      child: Container(), // This will be replaced
    );

    // Load user profile data immediately
    await appScope.loadUserProfile();

    return appScope;
  }

  // Access method for widgets
  static AppScope of(BuildContext context) {
    final AppScope? result = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(result != null, 'No AppScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return baseUrl != oldWidget.baseUrl ||
        productsRepository != oldWidget.productsRepository ||
        cartRepository != oldWidget.cartRepository ||
        userProfile != oldWidget.userProfile; // Add userProfile to the comparison
  }
}