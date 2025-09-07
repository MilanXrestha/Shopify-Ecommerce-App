import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../category/data/models/category_model.dart';
import '../../../category/data/repositories/categories_repository.dart';
import '../../../category/presentation/category_screen.dart';

class CategoryGrid extends StatelessWidget {
  final CategoriesRepository categoriesRepository;
  final Logger _logger = Logger();

  // Category images mapping - similar to CategoryScreen
  final Map<String, String> _categoryImages = {
    'beauty': 'assets/images/categories/beauty.png',
    'fragrances': 'assets/images/categories/fragrances.png',
    'furniture': 'assets/images/categories/furniture.png',
    'groceries': 'assets/images/categories/groceries.png',
    'home-decoration': 'assets/images/categories/home_decoration.png',
    'kitchen-accessories': 'assets/images/categories/kitchen_accessories.png',
    'smartphones': 'assets/images/categories/smartphones.png',
    'laptops': 'assets/images/categories/laptops.png',
    'skincare': 'assets/images/categories/skincare.png',
    'tops': 'assets/images/categories/tops.png',
    'womens-dresses': 'assets/images/categories/womens_dresses.png',
    'womens-shoes': 'assets/images/categories/womens_shoes.png',
    'mens-shirts': 'assets/images/categories/mens_shirts.png',
    'mens-shoes': 'assets/images/categories/mens_shoes.png',
    'mens-watches': 'assets/images/categories/mens_watches.png',
    'womens-watches': 'assets/images/categories/womens_watches.png',
    'womens-jewellery': 'assets/images/categories/womens_jewellery.png',
    'sunglasses': 'assets/images/categories/sunglasses.png',
    'automotive': 'assets/images/categories/automotive.png',
    'motorcycle': 'assets/images/categories/motorcycle.png',
    'lighting': 'assets/images/categories/lighting.png',
    '': 'assets/images/categories/placeholder.png',
  };

  CategoryGrid({super.key, required this.categoriesRepository});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CategoryModel>>(
      valueListenable: categoriesRepository.categories,
      builder: (context, categories, child) {
        if (categories.isEmpty) {
          return _buildEmptyState(context);
        }

        _logger.d(
          'Building category grid with ${categories.length} categories',
        );

        // Show only first 6 categories on home screen
        final displayedCategories = categories.take(6).toList();

        return SizedBox(
          height: 110, // Reduced height to minimize gap
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: displayedCategories.length,
            itemBuilder: (context, index) {
              final category = displayedCategories[index];

              _logger.d(
                'Category at index $index: ${category.name}, ${category.slug}',
              );

              return CategoryCard(
                name: category.name,
                slug: category.slug,
                index: index,
                imagePath: _getImagePath(category.slug),
                onTap: () {
                  _logger.d('Category tapped: ${category.name}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryScreen(
                        categorySlug: category.slug,
                        categoryName: category.name,
                        productsRepository: categoriesRepository
                            .getProductsRepository(),
                        categoriesRepository: categoriesRepository,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _getImagePath(String slug) {
    return _categoryImages[slug] ??
        _categoryImages[''] ??
        'assets/images/categories/placeholder.png';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 90, // Reduced to match compact design
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, color: Colors.grey[400], size: 24),
            const SizedBox(height: 6),
            Text(
              'No categories available',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatefulWidget {
  final String name;
  final String slug;
  final String imagePath;
  final VoidCallback onTap;
  final int index;

  const CategoryCard({
    super.key,
    required this.name,
    required this.slug,
    required this.imagePath,
    required this.onTap,
    required this.index,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: 90, // Slightly reduced width for compact look
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevent vertical overflow
            children: [
              // Image Container
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 70, // Reduced from 85
                  height: 70, // Reduced from 85
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 24, // Smaller icon
                          ),
                        ),
                      ),
                      // Semi-transparent overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.25),
                              // Slightly lighter
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6), // Reduced from 8
              // Category Name
              SizedBox(
                height: 28, // Reduced from 36 for 1-2 lines
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11, // Reduced from 12
                      color: Colors.grey[800],
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
}
