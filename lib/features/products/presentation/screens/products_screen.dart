import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:logger/logger.dart';
import '../../../../common/constants/app_constants.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/config/routes/route_name.dart';
import '../../../category/data/repositories/categories_repository.dart';
import '../../../search/widgets/filter_indicator.dart';
import '../../../search/widgets/product_filter_bottom_sheet.dart';
import '../../../search/widgets/product_filter_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/products_repository.dart';
import '../widgets/product_card.dart';
import '../widgets/product_shimmer.dart';
import '../../../search/presentation/search_results_screen.dart';
import '../../../../common/widgets/error_display.dart';

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;

  const ProductsScreen({super.key, this.initialCategory});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late ProductsRepository _productsRepository;
  late CategoriesRepository _categoriesRepository;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _searchBoxKey = GlobalKey();
  final Logger _logger = Logger();
  Timer? _debounce;
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingInBackground =
      false; // For background loading during filtering
  bool _highlightList = false; // For subtle animation when filtering
  String? _error;

  // Filter model for modular filtering
  late ProductFilterModel _filterModel = ProductFilterModel();
  bool _hasActiveFilters = false;

  // Search state
  List<ProductModel> _searchResults = [];
  bool _isSearchLoading = false;
  String? _searchError;
  int _loadProgress = 0;

  // Animation controller for list highlighting
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);

    // Setup animation controller for highlighting
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _colorAnimation =
        ColorTween(
          begin: Colors.transparent,
          end: AppColors.primaryLight.withOpacity(0.08),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appScope = AppScope.of(context);
    _productsRepository = ProductsRepository(
      appScope.apiClient,
      appScope.databaseHelper,
    );
    _categoriesRepository = CategoriesRepository(
      appScope.apiClient,
      appScope.databaseHelper,
    );

    _loadData();
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _categoriesRepository.loadCategories();

      if (_selectedCategory != null) {
        // Apply initial filters with category
        await _applyFilters(refresh: true);
      } else {
        // Load products with any current filters
        await _applyFilters(refresh: true);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      _logger.e('Error loading data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // Apply client-side filtering immediately for a responsive experience
  void _applyClientSideFiltering(List<ProductModel> products) {
    if (products.isEmpty) return;

    // Apply filters in-memory
    if (_filterModel.minPrice != null) {
      products.removeWhere((p) => p.discountedPrice < _filterModel.minPrice!);
    }

    if (_filterModel.maxPrice != null) {
      products.removeWhere((p) => p.discountedPrice > _filterModel.maxPrice!);
    }

    if (_filterModel.selectedBrand != null &&
        _filterModel.selectedBrand!.isNotEmpty) {
      products.removeWhere(
        (p) =>
            p.brand.toLowerCase() != _filterModel.selectedBrand!.toLowerCase(),
      );
    }

    if (_filterModel.minRating != null) {
      products.removeWhere((p) => p.rating < _filterModel.minRating!);
    }

    if (_filterModel.availabilityStatus != null) {
      products.removeWhere(
        (p) => p.availabilityStatus != _filterModel.availabilityStatus,
      );
    }

    if (_filterModel.selectedTags != null &&
        _filterModel.selectedTags!.isNotEmpty) {
      products.removeWhere(
        (p) => !_filterModel.selectedTags!.any(
          (tag) =>
              p.tags.any((t) => t.toLowerCase().contains(tag.toLowerCase())),
        ),
      );
    }

    // Apply sorting
    if (_filterModel.sortOption != 'Popular') {
      final sortConfig =
          ProductFilterModel.sortMapping[_filterModel.sortOption]!;
      final sortBy = sortConfig['sortBy'];
      final ascending = sortConfig['ascending'];

      switch (sortBy) {
        case 'price':
          products.sort(
            (a, b) => ascending
                ? a.price.compareTo(b.price)
                : b.price.compareTo(a.price),
          );
          break;
        case 'rating':
          products.sort(
            (a, b) => ascending
                ? a.rating.compareTo(b.rating)
                : b.rating.compareTo(a.rating),
          );
          break;
        case 'discount':
          products.sort(
            (a, b) => ascending
                ? a.discountPercentage.compareTo(b.discountPercentage)
                : b.discountPercentage.compareTo(a.discountPercentage),
          );
          break;
        case 'date':
          products.sort((a, b) {
            final aDate =
                a.meta?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.meta?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
          });
          break;
        case 'title':
          products.sort(
            (a, b) => ascending
                ? a.title.compareTo(b.title)
                : b.title.compareTo(a.title),
          );
          break;
        case 'popularity':
        default:
          products.sort((a, b) {
            final aScore = a.rating * 20 + (a.discountPercentage > 0 ? 10 : 0);
            final bScore = b.rating * 20 + (b.discountPercentage > 0 ? 10 : 0);
            return ascending
                ? aScore.compareTo(bScore)
                : bScore.compareTo(aScore);
          });
          break;
      }
    }

    // Update repository with filtered results immediately
    _productsRepository.products.value = List.from(products);

    // Animate to show results changed
    _animationController.forward();
  }

  Future<void> _applyFilters({
    bool refresh = false,
    bool loadAllProducts = false,
  }) async {
    // Get currently loaded products
    final currentProducts = List<ProductModel>.from(
      _productsRepository.products.value,
    );

    // 1. Apply client-side filtering immediately for responsive UX
    if (!refresh && currentProducts.isNotEmpty) {
      _applyClientSideFiltering(currentProducts);
    }

    // 2. Only show full loading indicator if we have no initial results
    if (currentProducts.isEmpty || refresh) {
      setState(() {
        _isLoading = true;
      });
    } else {
      // Show that background loading is happening
      setState(() {
        _isLoadingInBackground = true;
      });
    }

    // 3. Apply server-side filtering in the background
    try {
      await _productsRepository.applyFiltersComprehensive(
        category: _selectedCategory,
        minPrice: _filterModel.minPrice,
        maxPrice: _filterModel.maxPrice,
        brand: _filterModel.selectedBrand,
        tags: _filterModel.selectedTags,
        minRating: _filterModel.minRating,
        availabilityStatus: _filterModel.availabilityStatus,
        sortBy:
            ProductFilterModel.sortMapping[_filterModel.sortOption]?['sortBy'],
        sortAscending: ProductFilterModel
            .sortMapping[_filterModel.sortOption]?['ascending'],
        loadAllProducts: loadAllProducts,
        onProgress: (count, total) {
          // Only update progress if we're loading all products
          if (loadAllProducts) {
            setState(() {
              _loadProgress = count;
            });
          }
        },
        applyImmediately:
            !refresh, // Apply immediately for filtering, not for refresh
      );
    } catch (e) {
      _logger.e('Error applying filters: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      // Update UI state regardless of result
      setState(() {
        _isLoading = false;
        _isLoadingInBackground = false;
        _hasActiveFilters = _filterModel.hasActiveFilters;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_productsRepository.isCurrentlyLoading &&
        _productsRepository.hasMoreProducts.value &&
        !_isLoadingInBackground) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
    });

    await _productsRepository.loadProducts();

    // Re-apply sort if needed
    if (_filterModel.sortOption != 'Popular') {
      final sortConfig =
          ProductFilterModel.sortMapping[_filterModel.sortOption]!;
      _productsRepository.setSorting(
        sortConfig['sortBy'],
        ascending: sortConfig['ascending'],
      );
    }

    setState(() {
      _isLoadingMore = false;
    });
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

  void _showFilterModal() {
    _unfocusSearch();

    // Use the modular filter bottom sheet
    ProductFilterBottomSheet.show(
      context: context,
      initialFilter: _filterModel,
      productsRepository: _productsRepository,
    ).then((result) {
      if (result != null) {
        // Update filter model
        setState(() {
          _filterModel = result;
          _hasActiveFilters = result.hasActiveFilters;
        });

        // Determine if we need to load all products for comprehensive results
        final needsAllProducts =
            result.sortOption == 'Price: High to Low' ||
            result.sortOption == 'Price: Low to High' ||
            result.minPrice != null ||
            result.maxPrice != null;

        // Apply the filters with instant results
        _applyFilters(loadAllProducts: needsAllProducts);
      }
    });
  }

  Future<void> _setCategory(String? category) async {
    if (_selectedCategory == category) return;

    setState(() {
      _selectedCategory = category;
      _isLoading = true;
      _error = null;
    });

    try {
      // Apply filters with the new category
      await _applyFilters(refresh: true);

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      _logger.e('Error setting category: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _filterModel.clear();
      _hasActiveFilters = false;
      _isLoadingInBackground = true;
    });

    // Clear category if we're not on the category screen
    if (widget.initialCategory == null) {
      _selectedCategory = null;
    }

    _productsRepository.clearAllFilters();
    setState(() {
      _isLoadingInBackground = false;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: GestureDetector(
        onTap: _unfocusSearch,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildSearchBox(),
                  _buildCategoryTabs(),
                  if (_hasActiveFilters)
                    FilterIndicator(
                      filter: _filterModel,
                      onClearFilters: _clearAllFilters,
                    ),
                  if (_isLoadingInBackground)
                    _buildBackgroundLoadingIndicator(),
                  Expanded(
                    child: _error != null
                        ? ErrorDisplay(error: _error!, onRetry: _loadData)
                        : _buildProductGrid(),
                  ),
                ],
              ),
              if (_searchController.text.isNotEmpty) _buildModalBarrier(),
              if (_searchController.text.isNotEmpty)
                _buildSearchResultsOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12.w,
            height: 12.h,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            _loadProgress > 0
                ? 'Loading more products... ($_loadProgress)'
                : 'Updating results...',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Explore Our Collection",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Row(
            children: [
              ValueListenableBuilder(
                valueListenable: _productsRepository.favorites,
                builder: (context, favorites, _) {
                  return _buildActionIcon(
                    svgPath: 'assets/icons/svg/ic_wishlist.svg',
                    showBadge: favorites.isNotEmpty,
                    badgeCount: favorites.length,
                    onTap: () {
                      _unfocusSearch();
                      Navigator.pushNamed(
                        context,
                        RoutesName.wishlistScreen,
                      ).then((_) => setState(() {})); // Refresh on return
                    },
                  );
                },
              ),
              SizedBox(width: 12.w),

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
                    onTap: () {
                      _unfocusSearch();
                      Navigator.pushNamed(context, RoutesName.cartScreen);
                    },
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
    IconData? icon,
    String? svgPath,
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
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8.r,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SvgPicture.asset(
              svgPath ?? 'assets/images/placeholder.svg',
              width: 22.w,
              height: 22.h,
              color: Colors.grey[800],
            ),
          ),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                height: 16.w,
                width: 16.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 4.r,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? "99+" : badgeCount.toString(),
                    style: TextStyle(
                      fontSize: badgeCount > 99 ? 8.sp : 10.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.backgroundDark.withOpacity(0.1),
                    blurRadius: 10.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: "Search products...",
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: SvgPicture.asset(
                      'assets/icons/svg/ic_search.svg',
                      width: 20.w,
                      height: 20.h,
                      color: Colors.grey[600],
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/svg/ic_clear.svg',
                            width: 20.w,
                            height: 20.h,
                            color: Colors.grey[600],
                          ),
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
                  contentPadding: EdgeInsets.symmetric(vertical: 15.h),
                ),
                onSubmitted: (value) async {
                  if (value.isNotEmpty) {
                    _unfocusSearch();
                    final searchResults = await _productsRepository
                        .searchProducts(value);
                    if (!mounted) return;
                    Navigator.pushNamed(
                      context,
                      RoutesName.searchResultsScreen,
                      arguments: {
                        'searchQuery': value,
                        'initialProducts': searchResults,
                      },
                    );
                  }
                },
              ),
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              height: 50.h,
              width: 50.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.backgroundDark.withOpacity(0.1),
                    blurRadius: 10.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/svg/ic_filter.svg',
                    width: 22.w,
                    height: 22.h,
                    color: _hasActiveFilters
                        ? AppColors.primaryDark
                        : AppColors.backgroundDark,
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: searchBoxWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: _isSearchLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                    ),
                  ),
                )
              : _searchError != null
              ? Padding(
                  padding: EdgeInsets.all(16.w),
                  child: ErrorDisplay(
                    error: _searchError!,
                    onRetry: _onSearchChanged,
                  ),
                )
              : _searchResults.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    "No results found",
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(8.w),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return ValueListenableBuilder(
                      valueListenable: _productsRepository.favorites,
                      builder: (context, favorites, _) {
                        final isFavorite = favorites.any(
                          (fav) => fav.id == product.id,
                        );
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: CachedNetworkImage(
                              imageUrl: product.thumbnail,
                              width: 50.w,
                              height: 50.h,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                                width: 50.w,
                                height: 50.h,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                width: 50.w,
                                height: 50.h,
                                child: const Icon(Icons.error),
                              ),
                            ),
                          ),
                          title: Text(
                            product.title,
                            style: TextStyle(fontSize: 14.sp),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: product.isOnSale
                                      ? Colors.grey
                                      : Theme.of(context).colorScheme.primary,
                                  decoration: product.isOnSale
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (product.isOnSale) ...[
                                SizedBox(width: 4.w),
                                Text(
                                  '\$${product.discountedPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                              size: 20.sp,
                            ),
                            onPressed: () async {
                              await _productsRepository.toggleFavorite(
                                product.id,
                              );
                              setState(() {});
                            },
                          ),
                          onTap: () {
                            _unfocusSearch();
                            Navigator.pushNamed(
                              context,
                              RoutesName.productDetailScreen,
                              arguments: product.id,
                            ).then((_) => setState(() {}));
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

  Widget _buildCategoryTabs() {
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: ValueListenableBuilder(
        valueListenable: _categoriesRepository.categories,
        builder: (context, categories, child) {
          if (categories.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            height: 50.h,
            color: Colors.transparent,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildCategoryTab(null, 'All');
                }
                final category = categories[index - 1];
                return _buildCategoryTab(category.slug, category.name);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryTab(String? categorySlug, String name) {
    final isSelected = categorySlug == _selectedCategory;
    return GestureDetector(
      onTap: () => _setCategory(categorySlug),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryLight.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 4.r,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return ValueListenableBuilder<List<ProductModel>>(
      valueListenable: _productsRepository.products,
      builder: (context, products, child) {
        if (_isLoading) {
          return const ProductShimmer();
        }

        if (products.isEmpty) {
          return _buildEmptyState();
        }

        return AnimatedBuilder(
          animation: _colorAnimation,
          builder: (context, child) {
            return RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryLight,
              child: Container(
                decoration: BoxDecoration(color: _colorAnimation.value),
                child: MasonryGridView.count(
                  controller: _scrollController,
                  crossAxisCount: 2,
                  itemCount: products.length + 1,
                  itemBuilder: (context, index) {
                    if (index == products.length) {
                      return _buildLoadMoreIndicator();
                    }

                    final product = products[index];
                    return ProductCard(
                      product: product,
                      showRating: true,
                      showDiscount: true,
                      onFavoriteToggle: () async {
                        await _productsRepository.toggleFavorite(product.id);
                      },
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          RoutesName.productDetailScreen,
                          arguments: product.id,
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return ValueListenableBuilder(
      valueListenable: _productsRepository.hasMoreProducts,
      builder: (context, hasMore, child) {
        if (!hasMore) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder(
          valueListenable: _productsRepository.isLoading,
          builder: (context, isLoading, child) {
            return Container(
              padding: EdgeInsets.all(16.w),
              alignment: Alignment.center,
              child: isLoading || _isLoadingMore
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                    )
                  : SizedBox(height: 50.h),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    if (_hasActiveFilters) {
      message = 'No products match your filters';
      icon = Icons.filter_list;
    } else if (_selectedCategory != null) {
      message = 'No products available in this category';
      icon = Icons.category_outlined;
    } else {
      message = 'No products available';
      icon = Icons.shopping_bag_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          _hasActiveFilters
              ? ElevatedButton(
                  onPressed: _clearAllFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Clear Filters',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
