import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/error_display.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/config/routes/route_name.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/products_repository.dart';
import '../widgets/product_bottom_bar.dart';
import '../widgets/product_detail_tabs.dart';
import '../widgets/product_detail_widgets.dart';
import '../widgets/product_image_carousel.dart';
import '../widgets/product_info_section.dart';
import '../widgets/product_selectors.dart';
import '../widgets/product_similar_items.dart';
import '../widgets/product_tags.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final Logger _logger = Logger();
  late ProductsRepository _productsRepository;
  ProductModel? _product;
  bool _isLoading = true;
  String? _error;
  bool _isFavorite = false;
  int _quantity = 1;
  String? _selectedSize;
  Color? _selectedColor;
  String? _selectedStorage;
  List<ProductModel> _similarProducts = [];
  bool _isAddingToCart = false;

  // Sample colors for demonstration
  final List<Color> _availableColors = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.grey,
  ];

  // Sample sizes for demonstration
  final List<String> _availableSizes = ['S', 'M', 'L', 'XL', 'XXL'];

  // Sample storage options for electronics
  final List<String> _storageOptions = ['64GB', '128GB', '256GB', '512GB'];

  // Lists of categories for conditional display
  final List<String> _clothingCategories = [
    'mens-shirts',
    'womens-dresses',
    'mens-shoes',
    'womens-shoes',
    'tops',
    'womens-clothes',
    'mens-clothes',
  ];

  final List<String> _colorOnlyCategories = [
    'smartphones',
    'laptops',
    'automotive',
    'motorcycle',
    'furniture',
    'home-decoration',
    'sunglasses',
  ];

  final List<String> _electronicsCategories = [
    'smartphones',
    'laptops',
    'tablets',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appScope = AppScope.of(context);
    _productsRepository = appScope.productsRepository;
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final product = await _productsRepository.getProductById(
        widget.productId,
      );
      if (product == null) {
        throw Exception('Product not found');
      }

      final isFav = await _productsRepository.isFavorite(widget.productId);
      final similarProducts = await _productsRepository.getSimilarProducts(
        product,
        limit: 10,
      );

      setState(() {
        _product = product;
        _isFavorite = isFav;
        _similarProducts = similarProducts;
        _isLoading = false;

        // Set quantity to 1
        _quantity = 1;

        // Set default selections based on product category
        final category = product.category.toLowerCase();

        // Set default size for clothing items
        if (_clothingCategories.contains(category) &&
            _availableSizes.isNotEmpty) {
          _selectedSize = _availableSizes[0];
        }

        // Set default color for products that have color options
        if ((_clothingCategories.contains(category) ||
                _colorOnlyCategories.contains(category)) &&
            _availableColors.isNotEmpty) {
          _selectedColor = _availableColors[0];
        }

        // Set default storage for electronics
        if (_electronicsCategories.contains(category) &&
            _storageOptions.isNotEmpty) {
          _selectedStorage = _storageOptions[1]; // Default to 128GB
        }
      });

      _logger.d('Product viewed: ${product.title}');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _logger.e('Error loading product: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await _productsRepository.toggleFavorite(widget.productId);
      setState(() {
        _isFavorite = !_isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _logger.e('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToCart() async {
    if (_product != null) {
      setState(() {
        _isAddingToCart = true;
      });

      try {
        final cartRepository = AppScope.of(context).cartRepository;
        await cartRepository.addToCart(
          product: _product!,
          quantity: _quantity,
          selectedSize: _selectedSize,
          selectedColor: _selectedColor != null
              ? _getColorName(_selectedColor!)
              : null,
          selectedStorage: _selectedStorage,
        );

        setState(() {
          _isAddingToCart = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${_product!.title} to cart'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () {
                Navigator.pushNamed(context, RoutesName.cartScreen);
              },
            ),
          ),
        );
      } catch (e) {
        setState(() {
          _isAddingToCart = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getColorName(Color color) {
    if (color == Colors.black) return 'Black';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.red) return 'Red';
    if (color == Colors.green) return 'Green';
    if (color == Colors.grey) return 'Grey';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: ProductAppBar(
        product: _product,
        isLoading: _isLoading,
        isFavorite: _isFavorite,
        onToggleFavorite: _toggleFavorite,
      ),
      body: _buildBody(),
      bottomNavigationBar: _product != null && !_isLoading
          ? ProductBottomBar(
              product: _product!,
              quantity: _quantity,
              isAddingToCart: _isAddingToCart,
              onAddToCart: _addToCart,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_error != null) {
      return ErrorDisplay(error: _error!, onRetry: _loadProduct);
    }

    if (_product == null) {
      return const Center(child: Text('Product not found'));
    }

    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: statusBarHeight + appBarHeight),

        // Image carousel
        ProductImageCarousel(product: _product!),

        // Product information
        ProductInfoSection(product: _product!),

        // Selectors
        ProductSelectors(
          product: _product!,
          availableColors: _availableColors,
          availableSizes: _availableSizes,
          storageOptions: _storageOptions,
          clothingCategories: _clothingCategories,
          colorOnlyCategories: _colorOnlyCategories,
          electronicsCategories: _electronicsCategories,
          selectedColor: _selectedColor,
          selectedSize: _selectedSize,
          selectedStorage: _selectedStorage,
          quantity: _quantity,
          onColorSelected: (color) => setState(() => _selectedColor = color),
          onSizeSelected: (size) => setState(() => _selectedSize = size),
          onStorageSelected: (storage) =>
              setState(() => _selectedStorage = storage),
          onQuantityChanged: (value) => setState(() => _quantity = value),
        ),

        // Product details tabs
        ProductDetailTabs(product: _product!),

        // Tags
        if (_product!.tags.isNotEmpty) ProductTags(tags: _product!.tags),

        // Similar products
        if (_similarProducts.isNotEmpty)
          ProductSimilarItems(similarProducts: _similarProducts),

        // Bottom spacing
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.45,
              color: Colors.white,
            ),

            // Product info placeholders
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand
                  Container(width: 100, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  // Title
                  Container(
                    width: double.infinity,
                    height: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  // Rating
                  Container(width: 120, height: 20, color: Colors.white),
                  const SizedBox(height: 16),
                  // Price
                  Container(width: 150, height: 30, color: Colors.white),
                  const SizedBox(height: 16),
                  // Stock
                  Container(width: 100, height: 20, color: Colors.white),
                ],
              ),
            ),

            // Selectors placeholder
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 80, height: 20, color: Colors.white),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
