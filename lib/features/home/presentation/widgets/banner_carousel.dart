import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/app_scope.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';

class BannerCarousel extends StatefulWidget {
  final ProductsRepository productsRepository;

  const BannerCarousel({super.key, required this.productsRepository});

  @override
  BannerCarouselState createState() => BannerCarouselState();
}

class BannerCarouselState extends State<BannerCarousel> {
  final Logger _logger = Logger();
  late PageController _pageController;
  List<ProductModel> _bannerProducts = [];
  int _currentPage = 0;
  Timer? _timer;
  bool _isLoading = true; // Added to track initial loading state

  final List<List<Color>> bannerGradients = [
    [Colors.blue.shade50, Colors.blue.shade100],
    [Colors.orange.shade50, Colors.orange.shade100],
    [Colors.green.shade50, Colors.green.shade100],
    [Colors.pink.shade50, Colors.pink.shade100],
    [Colors.grey.shade200, Colors.grey.shade300],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeBanners(); // Replaced _setupBanners with async initialization

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_bannerProducts.isEmpty) return;

      _currentPage = (_currentPage + 1) % _bannerProducts.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    widget.productsRepository.products.removeListener(_updateBanners);
    super.dispose();
  }

  // Initialize banners with async to avoid context issues
  Future<void> _initializeBanners() async {
    widget.productsRepository.products.addListener(_updateBanners);
    await _updateBanners();
  }

  Future<void> _updateBanners() async {
    setState(() {
      _isLoading = true; // Set loading state
    });

    final allProducts = widget.productsRepository.products.value;
    _logger.d('ProductsRepository products count: ${allProducts.length}');

    if (allProducts.isEmpty) {
      // Load cached banners when products are empty (offline mode)
      final cachedBanners = await _loadCachedBanners();
      setState(() {
        _bannerProducts = cachedBanners;
        _isLoading = false;
      });
      if (cachedBanners.isNotEmpty) {
        _logger.d('Loaded ${cachedBanners.length} banners from cache: ${_bannerProducts.map((p) => p.title).toList()}');
      } else {
        _logger.d('No products or cached banners available');
        // Attempt to fetch products as a fallback
        try {
          await widget.productsRepository.loadProducts(refresh: true);
        } catch (e) {
          _logger.e('Failed to refresh products: $e');
        }
      }
      return;
    }

    // Sort products by score
    final scoredProducts = List<ProductModel>.from(allProducts);
    scoredProducts.sort((a, b) {
      final aScore = (a.rating * 0.8) + (a.discountPercentage * 0.4);
      final bScore = (b.rating * 0.8) + (b.discountPercentage * 0.4);
      return bScore.compareTo(aScore);
    });

    // Select top 5 products
    final newBannerProducts = scoredProducts.take(5).toList();

    setState(() {
      _bannerProducts = newBannerProducts;
      _isLoading = false;
    });

    // Cache the selected banner products
    await _cacheBanners(newBannerProducts);

    _logger.d('Banner products updated: ${_bannerProducts.map((p) => p.title).toList()}');
  }

  // Load banners from SQLite
  Future<List<ProductModel>> _loadCachedBanners() async {
    try {
      final appScope = AppScope.of(context);
      final db = await appScope.databaseHelper.database;
      final List<Map<String, dynamic>> bannerMaps = await db.query('banners');
      _logger.d('Fetched ${bannerMaps.length} banners from database');

      return bannerMaps.map((map) => ProductModel.fromDatabase(map)).toList();
    } catch (e) {
      _logger.e('Error loading cached banners: $e');
      return [];
    }
  }

  // Cache banners to SQLite
  Future<void> _cacheBanners(List<ProductModel> banners) async {
    try {
      final appScope = AppScope.of(context);
      final db = await appScope.databaseHelper.database;

      // Clear existing banners
      await db.delete('banners');
      _logger.d('Cleared existing banners from database');

      // Insert new banners
      for (var product in banners) {
        await db.insert(
          'banners',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      _logger.d('Cached ${banners.length} banners to SQLite');
    } catch (e) {
      _logger.e('Error caching banners: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _bannerProducts.isEmpty) {
      return _buildLoadingPlaceholder();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _bannerProducts.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                final product = _bannerProducts[index];
                final gradientColors = bannerGradients[index % bannerGradients.length];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildBannerItem(product, gradientColors),
                );
              },
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _buildIndicators(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerItem(ProductModel product, List<Color> gradientColors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.discountPercentage > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Row(
                        children: [
                          Text(
                            '\$${product.discountedPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (product.discountPercentage > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '\$${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(productId: product.id),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'SHOP NOW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: CachedNetworkImage(
                  imageUrl: product.thumbnail,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey[400],
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIndicators() {
    return List.generate(_bannerProducts.length, (index) {
      bool isActive = _currentPage == index;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 7,
        width: isActive ? 20 : 7,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.withOpacity(0.3),
        ),
      );
    });
  }

  Widget _buildLoadingPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}