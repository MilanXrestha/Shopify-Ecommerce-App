import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logger/logger.dart';
import '../../../../common/constants/app_constants.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/app_bar_back_button.dart';
import '../../../../common/widgets/error_display.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/config/routes/route_name.dart';
import '../../../category/data/repositories/categories_repository.dart';
import '../../../category/presentation/category_screen.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../../search/presentation/search_results_screen.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/best_deal.dart';
import '../widgets/category_grid.dart';
import '../widgets/featured_products.dart';
import '../widgets/home_shimmer.dart';
import '../widgets/new_arrivals.dart';
import '../../../products/data/repositories/products_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late ProductsRepository _productsRepository;
  late CategoriesRepository _categoriesRepository;
  bool _isLoading = true;
  String? _error;
  final Logger _logger = Logger();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _searchBoxKey = GlobalKey();
  Timer? _debounce;
  List<ProductModel> _searchResults = [];
  bool _isSearchLoading = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      Duration(milliseconds: AppConstants.searchDebounceTime),
      () async {
        if (_searchController.text.isNotEmpty) {
          _logger.d('Debounced search triggered: ${_searchController.text}');
          setState(() {
            _isSearchLoading = true;
            _searchError = null;
          });
          try {
            final results = await _productsRepository.searchProducts(
              _searchController.text,
            );
            if (!mounted) return;
            setState(() {
              _searchResults = results;
              _isSearchLoading = false;
            });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _searchError = e.toString();
              _isSearchLoading = false;
            });
          }
        } else {
          _productsRepository.clearSearch();
          setState(() {
            _searchResults = [];
            _searchError = null;
            _isSearchLoading = false;
          });
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appScope = AppScope.of(context);
    _productsRepository = appScope.productsRepository;
    _categoriesRepository = appScope.categoriesRepository;
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      _unfocusSearch();
    }
  }

  void _unfocusSearch() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      _searchController.clear();
      _productsRepository.clearSearch();
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearchLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _productsRepository.loadProducts(refresh: true),
        _categoriesRepository.loadCategories(),
      ]);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _navigateToAllCategories() {
    _unfocusSearch();
    _logger.d("See all categories tapped");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryScreen(
          categorySlug: "",
          categoryName: "Categories",
          productsRepository: _productsRepository,
          categoriesRepository: _categoriesRepository,
        ),
      ),
    );
  }

  void _navigateToNewArrivals() {
    _unfocusSearch();
    _logger.d("See all new arrivals tapped");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              "New Arrivals",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
            // Use standard IconButton instead of custom AppBarBackButton
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
            ),
            itemCount: _productsRepository.getNewestProducts(limit: 20).length,
            itemBuilder: (context, index) {
              final product = _productsRepository.getNewestProducts(
                limit: 20,
              )[index];
              return ProductCard(
                product: product,
                showDiscount: false,
                showRating: true,
                showNewTag: true,
                // Use smaller image height and padding for grid
                imageHeight: 120,
                contentPadding: const EdgeInsets.all(8),
                onFavoriteToggle: () async {
                  await _productsRepository.toggleFavorite(product.id);
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailScreen(productId: product.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToAllDeals() {
    _unfocusSearch();
    _logger.d("See all deals tapped");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              "Best Deals",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
            ),
            itemCount: _productsRepository
                .getTopDiscountedProducts(limit: 20)
                .length,
            itemBuilder: (context, index) {
              final product = _productsRepository.getTopDiscountedProducts(
                limit: 20,
              )[index];
              return ProductCard(
                product: product,
                showDiscount: true,
                showRating: true,
                imageHeight: 120,
                contentPadding: const EdgeInsets.all(8),
                onFavoriteToggle: () async {
                  await _productsRepository.toggleFavorite(product.id);
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailScreen(productId: product.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToAllFeatured() {
    _unfocusSearch();
    _logger.d("See all featured products tapped");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              "Featured Products",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
            ),
            itemCount: _productsRepository
                .getTopRatedProducts(limit: 20)
                .length,
            itemBuilder: (context, index) {
              final product = _productsRepository.getTopRatedProducts(
                limit: 20,
              )[index];
              return ProductCard(
                product: product,
                showDiscount: true,
                showRating: true,
                imageHeight: 120,
                contentPadding: const EdgeInsets.all(8),
                onFavoriteToggle: () async {
                  await _productsRepository.toggleFavorite(product.id);
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailScreen(productId: product.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    _unfocusSearch();
    _logger.d("Profile image tapped");
    Navigator.pushNamed(context, RoutesName.profileScreen);
  }

  void _navigateToNotifications() {
    _unfocusSearch();
    _logger.d("Notification tapped");
    Navigator.pushNamed(context, RoutesName.notificationScreen);
  }

  void _navigateToCart() {
    _unfocusSearch();
    _logger.d("Cart tapped");
    Navigator.pushNamed(context, RoutesName.cartScreen);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: _unfocusSearch,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                _buildBody(),
                if (_searchController.text.isNotEmpty) _buildModalBarrier(),
                if (_searchController.text.isNotEmpty)
                  _buildSearchResultsOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalBarrier() {
    final RenderBox? searchBox =
        _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final searchBoxPosition =
        searchBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final searchBoxHeight = searchBox?.size.height ?? 50.0;

    return Positioned(
      top: searchBoxPosition.dy + searchBoxHeight + 8,
      left: 0,
      right: 0,
      bottom: 0,
      child: ModalBarrier(
        color: Colors.black.withOpacity(0.3),
        dismissible: true,
        onDismiss: _unfocusSearch,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const HomeShimmer();
    }

    if (_error != null) return ErrorDisplay(error: _error!, onRetry: _loadData);

    return ValueListenableBuilder(
      valueListenable: _productsRepository.products,
      builder: (context, products, child) {
        return RefreshIndicator(
          onRefresh: () {
            _unfocusSearch();
            return _loadData();
          },
          child: ListView(
            key: const PageStorageKey('home_list'),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchBox(),
              const SizedBox(height: 24),
              BannerCarousel(productsRepository: _productsRepository),
              const SizedBox(height: 28),
              _buildSectionTitle(
                "Categories",
                onSeeAll: _navigateToAllCategories,
              ),
              const SizedBox(height: 12),
              CategoryGrid(categoriesRepository: _categoriesRepository),
              const SizedBox(height: 12),
              _buildSectionTitle(
                "New Arrivals",
                onSeeAll: _navigateToNewArrivals,
              ),
              const SizedBox(height: 12),
              const NewArrivals(),
              const SizedBox(height: 12),
              _buildSectionTitle(
                "Featured Products",
                onSeeAll: _navigateToAllFeatured,
              ),
              const SizedBox(height: 12),
              FeaturedProducts(
                title: 'Top Rated',
                products: _productsRepository.getTopRatedProducts(),
              ),
              const SizedBox(height: 12),
              _buildSectionTitle("Best Deals", onSeeAll: _navigateToAllDeals),
              const SizedBox(height: 12),
              BestDeals(onSeeAllTapped: _navigateToAllDeals),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final appScope = AppScope.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [



          Row(
            children: [
              GestureDetector(
                onTap: _navigateToProfile,
                child: ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: appScope.userProfile,
                  builder: (context, profile, _) {
                    final avatarUrl = profile?['avatarUrl'];

                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? FileImage(File(avatarUrl))
                            : const CachedNetworkImageProvider(
                          'https://i.imgur.com/2iw4qeP_d.jpeg',
                        ) as ImageProvider,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: appScope.userProfile,
                builder: (context, profile, _) {
                  final name = profile?['name'] ?? 'Milan';
                  final firstName = name.split(' ').first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, $firstName",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            "Welcome back!",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),



          Row(
            children: [
              const SizedBox(width: 12),
              _buildActionIcon(
                svgPath: 'assets/icons/svg/ic_notification.svg',
                showBadge: true,
                onTap: _navigateToNotifications,
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder(
                valueListenable: AppScope.of(context).cartRepository.cartItems,
                builder: (context, cartItems, _) {
                  final itemCount = cartItems.fold<int>(
                    0,
                    (sum, item) => sum + item.quantity,
                  );
                  return _buildActionIcon(
                    svgPath: 'assets/icons/svg/ic_cart.svg',
                    showBadge: cartItems.isNotEmpty,
                    badgeCount: itemCount,
                    onTap: _navigateToCart,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required String svgPath,
    bool showBadge = false,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SvgPicture.asset(
              svgPath,
              width: 22,
              height: 22,
              color: Colors.grey[800],
            ),
          ),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                height: 16,
                width: 16,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    badgeCount > 0 ? badgeCount.toString() : "",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      key: _searchBoxKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.backgroundDark.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: "Search products...",
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                'assets/icons/svg/ic_search.svg',
                width: 20,
                height: 20,
                color: Colors.grey[600],
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _productsRepository.clearSearch();
                      setState(() {
                        _searchResults = [];
                        _searchError = null;
                        _isSearchLoading = false;
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onSubmitted: (value) async {
            if (value.isNotEmpty) {
              _unfocusSearch();
              final searchResults = await _productsRepository.searchProducts(
                value,
              );
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsScreen(
                    searchQuery: value,
                    initialProducts: searchResults,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildSearchResultsOverlay() {
    final RenderBox? searchBox =
        _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final searchBoxPosition =
        searchBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final searchBoxWidth =
        searchBox?.size.width ?? MediaQuery.of(context).size.width - 32;

    return Positioned(
      top: searchBoxPosition.dy + 18,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: searchBoxWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isSearchLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _searchError != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorDisplay(
                    error: _searchError!,
                    onRetry: _onSearchChanged,
                  ),
                )
              : _searchResults.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "No results found",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ValueListenableBuilder<List<ProductModel>>(
                  valueListenable: _productsRepository.favorites,
                  builder: (context, favorites, _) {
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        final isFavorite = favorites.any(
                          (p) => p.id == product.id,
                        );
                        return ListTile(
                          leading: CachedNetworkImage(
                            imageUrl: product.thumbnail,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              width: 50,
                              height: 50,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              width: 50,
                              height: 50,
                              child: const Icon(Icons.error),
                            ),
                          ),
                          title: Text(
                            product.title,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '\$${product.discountedPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () async {
                              await _productsRepository.toggleFavorite(
                                product.id,
                              );
                            },
                          ),
                          onTap: () {
                            _unfocusSearch();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailScreen(productId: product.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 20,
                width: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Row(
                children: const [
                  Text(
                    "See All",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
