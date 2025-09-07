import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/constants/app_constants.dart';
import '../common/theme/app_theme.dart';
import '../core/config/routes/route_name.dart';
import '../core/app_scope.dart';
import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';
import '../features/category/data/repositories/categories_repository.dart';
import '../features/products/data/repositories/products_repository.dart';
import '../features/cart/data/repositories/cart_repository.dart';
import 'config/routes/route_generator.dart';

class EcommerceApp extends StatefulWidget {
  const EcommerceApp({super.key});

  @override
  EcommerceAppState createState() => EcommerceAppState();
}

class EcommerceAppState extends State<EcommerceApp> {
  bool _isDarkMode = false;
  bool _isInitialized = false;
  AppScope? _appScope;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load theme preference
      final prefs = await SharedPreferences.getInstance();
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;

      // Initialize database
      final databaseHelper = DatabaseHelper();
      await databaseHelper.initDatabase();

      // Get base URL from SharedPreferences or use default
      final baseUrl =
          prefs.getString('base_url') ?? AppConstants.defaultBaseUrl;

      // Initialize API client
      final apiClient = ApiClient(baseUrl: baseUrl);

      // Initialize repositories
      final productsRepository = ProductsRepository(apiClient, databaseHelper);
      final cartRepository = CartRepository(databaseHelper, productsRepository);
      final categoriesRepository = CategoriesRepository(
        apiClient,
        databaseHelper,
      );

      // Create and initialize userProfile ValueNotifier
      final userProfile = ValueNotifier<Map<String, dynamic>?>(null);
      final profileData = await databaseHelper.getUserProfile();
      userProfile.value = profileData;

      // Create AppScope
      _appScope = AppScope(
        apiClient: apiClient,
        databaseHelper: databaseHelper,
        sharedPreferences: prefs,
        baseUrl: baseUrl,
        productsRepository: productsRepository,
        cartRepository: cartRepository,
        categoriesRepository: categoriesRepository,
        userProfile: userProfile,
        // Use the created userProfile
        child: Container(),
      );

      // Update state
      if (mounted) {
        setState(() {
          _isDarkMode = isDarkMode;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing app: $e');
      // Show error state if needed
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _toggleTheme() async {
    if (_appScope == null) return;

    final newThemeMode = !_isDarkMode;

    // Save theme preference
    await _appScope!.sharedPreferences.setBool('isDarkMode', newThemeMode);

    setState(() {
      _isDarkMode = newThemeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen until initialization is complete
    if (!_isInitialized || _appScope == null) {
      return ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/png/Shopify.png',
                      width: 200.w,
                      height: 200.h,
                    ),
                    SizedBox(height: 24.h),
                    CircularProgressIndicator.adaptive(),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return AppScope(
          apiClient: _appScope!.apiClient,
          databaseHelper: _appScope!.databaseHelper,
          sharedPreferences: _appScope!.sharedPreferences,
          baseUrl: _appScope!.baseUrl,
          productsRepository: _appScope!.productsRepository,
          cartRepository: _appScope!.cartRepository,
          categoriesRepository: _appScope!.categoriesRepository,
          userProfile: _appScope!.userProfile,
          child: MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: RoutesName.mainScreen,
            onGenerateRoute: RouteConfig.generateRoute,
          ),
        );
      },
    );
  }
}
