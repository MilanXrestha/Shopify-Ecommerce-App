import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../../core/app_scope.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../products/presentation/widgets/product_card.dart';

class BestDeals extends StatefulWidget {
  final VoidCallback onSeeAllTapped;

  const BestDeals({
    super.key,
    required this.onSeeAllTapped,
  });

  @override
  State<BestDeals> createState() => _BestDealsState();
}

class _BestDealsState extends State<BestDeals> {
  final Logger _logger = Logger();

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).productsRepository;
    final discountedProducts = repository.getTopDiscountedProducts();

    if (discountedProducts.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No discounted products available')),
      );
    }

    _logger.d(
      'Building best deals section with ${discountedProducts.length} products',
    );

    return SizedBox(
      height: 340,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: discountedProducts.length,
        itemBuilder: (context, index) {
          final product = discountedProducts[index];
          return ProductCard(
            product: product,
            showDiscount: true,
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
                  builder: (context) => ProductDetailScreen(productId: product.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}