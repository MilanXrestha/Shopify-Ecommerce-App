import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logger/logger.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/app_bar_back_button.dart';
import '../../../../common/widgets/error_display.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repositories/products_repository.dart';
import '../../products/presentation/screens/product_detail_screen.dart';
import '../../products/presentation/widgets/product_card.dart';
import '../../products/presentation/widgets/product_shimmer.dart';
import '../../search/widgets/filter_indicator.dart';
import '../../search/widgets/product_filter_bottom_sheet.dart';
import '../../search/widgets/product_filter_model.dart';
import '../data/models/category_model.dart';
import '../data/repositories/categories_repository.dart';

class CategoryScreen extends StatefulWidget {
  final String categorySlug;
  final String categoryName;
  final ProductsRepository productsRepository;
  final CategoriesRepository?
  categoriesRepository; // Optional for all categories view

  const CategoryScreen({
    super.key,
    required this.categorySlug,
    required this.categoryName,
    required this.productsRepository,
    this.categoriesRepository,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingInBackground = false;
  String? _error;
  String _searchQuery = ''; // Track search input
  final TextEditingController _searchController = TextEditingController();

  // Filter model for modular filtering
  late ProductFilterModel _filterModel = ProductFilterModel();
  bool _hasActiveFilters = false;
  int _loadProgress = 0;

  // Animation controller for list highlighting
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  // Mapping of category slugs to image assets
  final Map<String, String> _categoryImages = {
    'beauty': 'assets/images/categories/beauty.png',
    'fragrances': 'assets/images/categories/fragrances.png',
    'furniture': 'assets/images/categories/furniture.png',
    'groceries': 'assets/images/categories/groceries.png',
    'home-decoration': 'assets/images/categories/home_decoration.png',
    'kitchen-accessories': 'assets/images/categories/kitchen_accessories.png',
    'smartphones': 'assets/images/categories/smartphones.png',
    '': 'assets/images/categories/placeholder.png',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Setup scroll listener for pagination
    if (widget.categorySlug.isNotEmpty) {
      _scrollController.addListener(_onScroll);
    }

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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !widget.productsRepository.isCurrentlyLoading &&
        widget.productsRepository.hasMoreProducts.value &&
        !_isLoadingInBackground) {
      _loadMoreProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.categorySlug.isEmpty && widget.categoriesRepository != null) {
        // Load categories for "all categories" view
        await widget.categoriesRepository!.loadCategories();
      } else {
        // Apply filters for category view
        await _applyFilters(refresh: true);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      _logger.e('Error loading data: $e');
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
    widget.productsRepository.products.value = List.from(products);

    // Animate to show results changed
    _animationController.forward();
  }

  Future<void> _applyFilters({
    bool refresh = false,
    bool loadAllProducts = false,
  }) async {
    // Get currently loaded products
    final currentProducts = List<ProductModel>.from(
      widget.productsRepository.products.value,
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
      await widget.productsRepository.applyFiltersComprehensive(
        category: widget.categorySlug,
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

  Future<void> _loadMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
    });

    await widget.productsRepository.loadProducts();

    // Re-apply sort if needed
    if (_filterModel.sortOption != 'Popular') {
      final sortConfig =
      ProductFilterModel.sortMapping[_filterModel.sortOption]!;
      widget.productsRepository.setSorting(
        sortConfig['sortBy'],
        ascending: sortConfig['ascending'],
      );
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _showFilterModal() {
    // Use the modular filter bottom sheet
    ProductFilterBottomSheet.show(
      context: context,
      initialFilter: _filterModel,
      productsRepository: widget.productsRepository,
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

  void _clearAllFilters() {
    setState(() {
      _filterModel.clear();
      _hasActiveFilters = false;
      _isLoadingInBackground = true;
    });

    widget.productsRepository
        .applyFiltersComprehensive(category: widget.categorySlug)
        .then((_) {
      setState(() {
        _isLoadingInBackground = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
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
        actions: [
          if (widget.categorySlug.isEmpty &&
              widget.categoriesRepository != null)
            IconButton(
              icon: const Icon(Icons.search),
              color: Colors.black,
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: CategorySearchDelegate(
                    categories: widget.categoriesRepository!.categories.value,
                    productsRepository: widget.productsRepository,
                    categoryImages: _categoryImages,
                  ),
                );
              },
            ),
          if (widget.categorySlug.isNotEmpty)
            IconButton(
              color: Colors.black,
              icon: Stack(
                children: [
                  const Icon(Icons.filter_list),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _showFilterModal,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_hasActiveFilters && widget.categorySlug.isNotEmpty)
            FilterIndicator(
              filter: _filterModel,
              onClearFilters: _clearAllFilters,
            ),
          if (_isLoadingInBackground) _buildBackgroundLoadingIndicator(),
          Expanded(
              child: _error != null
                  ? ErrorDisplay(error: _error!, onRetry: _loadData)
                  : _isLoading && widget.categorySlug.isEmpty
                  ? _buildShimmerList()
                  : _buildContent()
          ),
        ],
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

  Widget _buildContent() {
    if (widget.categorySlug.isEmpty && widget.categoriesRepository != null) {
      return _buildCategoryList();
    }
    return _buildProductGrid();
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5, // Number of shimmer placeholders
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryList() {
    final categories = widget.categoriesRepository!.categories.value
        .where((category) => category.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (categories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryItem(category);
        },
      ),
    );
  }

  Widget _buildCategoryItem(CategoryModel category) {
    final imagePath =
        _categoryImages[category.slug] ??
            _categoryImages[''] ??
            'assets/images/categories/placeholder.png';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          _logger.d('Category tapped: ${category.name}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryScreen(
                categorySlug: category.slug,
                categoryName: category.name,
                productsRepository: widget.productsRepository,
              ),
            ),
          );
        },
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              // Semi-transparent overlay
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              // Centered category name
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return ValueListenableBuilder(
      valueListenable: widget.productsRepository.products,
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
              child: Container(
                decoration: BoxDecoration(color: _colorAnimation.value),
                child: MasonryGridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8.w),
                  gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
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
                      // Make cards more compact
                      imageHeight: 120,
                      contentPadding: const EdgeInsets.all(8),
                      onFavoriteToggle: () async {
                        await widget.productsRepository.toggleFavorite(product.id);
                      },
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(productId: product.id),
                          ),
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
      valueListenable: widget.productsRepository.hasMoreProducts,
      builder: (context, hasMore, child) {
        if (!hasMore) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder(
          valueListenable: widget.productsRepository.isLoading,
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
    } else {
      message = 'No products found in ${widget.categoryName}';
      icon = Icons.category_outlined;
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

class CategorySearchDelegate extends SearchDelegate<String> {
  final List<CategoryModel> categories;
  final ProductsRepository productsRepository;
  final Map<String, String> categoryImages;

  CategorySearchDelegate({
    required this.categories,
    required this.productsRepository,
    required this.categoryImages,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        color: Colors.black,
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      color: Colors.black,
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildCategorySearchList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildCategorySearchList(context);
  }

  Widget _buildCategorySearchList(BuildContext context) {
    final filteredCategories = categories
        .where(
          (category) =>
          category.name.toLowerCase().contains(query.toLowerCase()),
    )
        .toList();

    if (filteredCategories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        final imagePath =
            categoryImages[category.slug] ??
                categoryImages[''] ??
                'assets/images/categories/placeholder.png';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () {
              close(context, '');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryScreen(
                    categorySlug: category.slug,
                    categoryName: category.name,
                    productsRepository: productsRepository,
                  ),
                ),
              );
            },
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      imagePath,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}