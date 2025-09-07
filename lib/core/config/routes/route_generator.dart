
import 'package:e_commerce_app/core/config/routes/route_name.dart';
import 'package:e_commerce_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:e_commerce_app/features/cart/presentation/screens/checkout_screen.dart';
import 'package:e_commerce_app/features/home/presentation/screens/home_screen.dart';
import 'package:e_commerce_app/features/main/presentation/screens/main_screen.dart';
import 'package:e_commerce_app/features/products/presentation/screens/product_detail_screen.dart';
import 'package:e_commerce_app/features/products/presentation/screens/products_screen.dart';
import 'package:e_commerce_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:e_commerce_app/features/wishlist/presentation/wishlist_screen.dart';
import 'package:flutter/material.dart';

import '../../../features/category/data/repositories/categories_repository.dart';
import '../../../features/category/presentation/category_screen.dart';
import '../../../features/notification/notification_screen.dart';
import '../../../features/products/data/models/product_model.dart';
import '../../../features/products/data/repositories/products_repository.dart';
import '../../../features/search/presentation/search_results_screen.dart';


class RouteConfig {
  RouteConfig._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final String? screenName = settings.name;
    final args = settings.arguments;

    switch (screenName) {
      case RoutesName.mainScreen:
        return MaterialPageRoute(
          builder: (_) => const MainScreen(),
          settings: settings,
        );

      case RoutesName.homeScreen:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      case RoutesName.productScreen:
        return MaterialPageRoute(
          builder: (_) => const ProductsScreen(),
          settings: settings,
        );

      case RoutesName.productDetailScreen:
        if (args is int) {
          return MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: args),
            settings: settings,
          );
        }
        return _errorRoute(
          'Invalid arguments for ProductDetailScreen. Expected int productId, got $args',
        );

      case RoutesName.categoryScreen:
        if (args is Map<String, dynamic> &&
            args.containsKey('categorySlug') &&
            args.containsKey('categoryName') &&
            args.containsKey('productsRepository')) {
          return MaterialPageRoute(
            builder: (_) => CategoryScreen(
              categorySlug: args['categorySlug'] as String,
              categoryName: args['categoryName'] as String,
              productsRepository: args['productsRepository'] as ProductsRepository,
              categoriesRepository: args['categoriesRepository'] as CategoriesRepository?,
            ),
            settings: settings,
          );
        }
        return _errorRoute(
          'Invalid arguments for CategoryScreen. Expected Map with categorySlug, categoryName, and productsRepository, got $args',
        );

      case RoutesName.categoryDetailScreen:
        if (args is Map<String, dynamic> &&
            args.containsKey('categorySlug') &&
            args.containsKey('categoryName') &&
            args.containsKey('productsRepository')) {
          return MaterialPageRoute(
            builder: (_) => CategoryScreen(
              categorySlug: args['categorySlug'] as String,
              categoryName: args['categoryName'] as String,
              productsRepository: args['productsRepository'] as ProductsRepository,
              categoriesRepository: args['categoriesRepository'] as CategoriesRepository?,
            ),
            settings: settings,
          );
        }
        return _errorRoute(
          'Invalid arguments for CategoryDetailScreen. Expected Map with categorySlug, categoryName, and productsRepository, got $args',
        );

      case RoutesName.notificationScreen:
        return MaterialPageRoute(
          builder: (_) => const NotificationScreen(),
          settings: settings,
        );

      case RoutesName.cartScreen:
        return MaterialPageRoute(
          builder: (_) => const CartScreen(),
          settings: settings,
        );

      case RoutesName.checkoutScreen:
        final summary = args as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CheckoutScreen(cartSummary: summary),
          settings: settings,
        );

      case RoutesName.wishlistScreen:
        return MaterialPageRoute(
          builder: (_) => const WishlistScreen(),
          settings: settings,
        );

      case RoutesName.profileScreen:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case RoutesName.searchResultsScreen:
        if (args is Map<String, dynamic> &&
            args.containsKey('searchQuery') &&
            args.containsKey('initialProducts')) {
          return MaterialPageRoute(
            builder: (_) => SearchResultsScreen(
              searchQuery: args['searchQuery'] as String,
              initialProducts: args['initialProducts'] as List<ProductModel>,
            ),
            settings: settings,
          );
        }
        return _errorRoute(
          'Invalid arguments for SearchResultsScreen. Expected Map with searchQuery and initialProducts, got $args',
        );

      default:
        return _errorRoute('No route defined for $screenName');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text(
            'Error: $message',
            style: const TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      ),
    );
  }
}
