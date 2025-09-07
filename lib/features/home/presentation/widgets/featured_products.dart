import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../../core/app_scope.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../products/presentation/widgets/product_card.dart';

class FeaturedProducts extends StatefulWidget {
  final String title;
  final List<ProductModel> products;
  final bool showDiscount;

  const FeaturedProducts({
    super.key,
    required this.title,
    required this.products,
    this.showDiscount = false,
  });

  @override
  State<FeaturedProducts> createState() => _FeaturedProductsState();
}

class _FeaturedProductsState extends State<FeaturedProducts> {
  final Logger _logger = Logger();

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).productsRepository;

    if (widget.products.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(child: Text('No ${widget.title} products available')),
      );
    }

    _logger.d(
      'Building featured products section: ${widget.title} with ${widget.products.length} products',
    );

    return SizedBox(
      height: 335,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: widget.products.length,
        itemBuilder: (context, index) {
          final product = widget.products[index];
          return ProductCard(
            product: product,
            showDiscount: widget.showDiscount,
            showRating: true,
            showNewTag: false,
            imageHeight: 160,
            contentPadding: const EdgeInsets.all(12),
            onFavoriteToggle: () async {
              await repository.toggleFavorite(product.id);
            },
            onTap: () {
              _logger.d('Product tapped: ${product.title}');
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
    );
  }
}
