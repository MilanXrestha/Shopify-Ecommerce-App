import 'package:flutter/material.dart';
import '../../../../core/app_scope.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../products/presentation/widgets/product_card.dart';

class NewArrivals extends StatefulWidget {
  const NewArrivals({super.key});

  @override
  State<NewArrivals> createState() => _NewArrivalsState();
}

class _NewArrivalsState extends State<NewArrivals> {
  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).productsRepository;
    final newestProducts = repository.getNewestProducts(limit: 8);

    if (newestProducts.isEmpty) {
      return const SizedBox(
        height: 270,
        child: Center(child: Text("No new arrivals")),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: newestProducts.length,
        itemBuilder: (context, index) {
          final product = newestProducts[index];
          return ProductCard(
            product: product,
            showDiscount: false,
            showRating: false,
            showNewTag: true,
            imageHeight: 120,
            contentPadding: const EdgeInsets.all(8),
            onFavoriteToggle: () async {
              await repository.toggleFavorite(product.id);
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
    );
  }
}
