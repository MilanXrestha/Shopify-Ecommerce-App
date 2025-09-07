class AppConstants {
  AppConstants._(); // Private constructor

  // App info
  static const String appName = 'Shopify';
  static const String appVersion = '1.0.0';

  // Network
  static const String defaultBaseUrl = 'https://dummyjson.com';

  // Pagination
  static const int defaultPageSize = 20;

  // Search
  static const int searchDebounceTime = 600; // milliseconds

  // Cart
  static const double defaultTaxRate = 0.13; // 13% tax

  // Database
  static const String databaseName = 'ecommerce.db';
  static const int databaseVersion = 1;

  // Shared Preferences Keys
  static const String prefKeyBaseUrl = 'base_url';
  static const String prefKeyDarkMode = 'isDarkMode';
  static const String prefKeyUserOnboarded = 'user_onboarded';

  // Analytics Events
  static const String eventAppOpen = 'app_open';
  static const String eventProductView = 'product_view';
  static const String eventAddToCart = 'add_to_cart';
  static const String eventRemoveFromCart = 'remove_from_cart';
  static const String eventSearchQuery = 'search_query';
  static const String eventCategorySelect = 'category_select';
}
