import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/config/routes/route_name.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repositories/products_repository.dart';
import '../../products/presentation/screens/product_detail_screen.dart';
import '../../products/presentation/widgets/product_card.dart';

class WishlistScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProducts;

  const WishlistScreen({super.key, this.onNavigateToProducts});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late ProductsRepository _productsRepository;
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final appScope = AppScope.of(context);
      _productsRepository = appScope.productsRepository;
      _loadFavorites(); // Trigger initial load
      _isInitialized = true;
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _productsRepository.getFavoriteProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading favorites: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToCart() {
    Navigator.pushNamed(context, RoutesName.cartScreen);
  }

  void _navigateToShop() {
    if (widget.onNavigateToProducts != null) {
      // We're in bottom nav - use callback to switch to ProductsScreen tab
      widget.onNavigateToProducts?.call();
    } else {
      // Create a smooth transition back to main screen with products tab
      Navigator.pushNamed(
        context,
        RoutesName.mainScreen,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Material(
          color: Colors.white,
          elevation: 1,
          child: AppBar(
            title: const Text(
              'My Wishlist',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              ValueListenableBuilder(
                valueListenable: AppScope.of(context).cartRepository.cartItems,
                builder: (context, cartItems, _) {
                  final itemCount = cartItems.fold<int>(
                    0,
                        (sum, item) => sum + item.quantity,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: _navigateToCart,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: SvgPicture.asset(
                                'assets/icons/svg/ic_cart.svg',
                                width: 22,
                                height: 22,
                                color: Colors.black,
                              ),
                            ),
                            if (itemCount > 0)
                              Positioned(
                                top: -5,
                                right: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryDark,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      itemCount > 99 ? '99+' : itemCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: ValueListenableBuilder<List<ProductModel>>(
        valueListenable: _productsRepository.favorites,
        builder: (context, favoriteProducts, _) {
          return _buildBody(favoriteProducts);
        },
      ),
    );
  }

  Widget _buildBody(List<ProductModel> favoriteProducts) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (favoriteProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'Your wishlist is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Add items you love to your wishlist',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _navigateToShop,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                backgroundColor: AppColors.primaryLight,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue Shopping',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppColors.primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: MasonryGridView.count(
          crossAxisCount: 2,
          itemCount: favoriteProducts.length,
          itemBuilder: (context, index) {
            final product = favoriteProducts[index];
            return ProductCard(
              product: product,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(productId: product.id),
                  ),
                );
              },
              onFavoriteToggle: () async {
                await _productsRepository.toggleFavorite(product.id);
              },
              showRating: true,
              showDiscount: true,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: 10,
          itemBuilder: (context, index) {
            return Container(
              height: 220 + (index % 2) * 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        ),
      ),
    );
  }
}