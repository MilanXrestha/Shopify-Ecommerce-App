import 'package:flutter/material.dart';
import '../../../../../common/theme/app_colors.dart';
import '../../data/models/product_model.dart';

class ProductBottomBar extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final bool isAddingToCart;
  final VoidCallback onAddToCart;

  const ProductBottomBar({
    super.key,
    required this.product,
    required this.quantity,
    required this.isAddingToCart,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Total price
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '\$${(product.discountedPrice * quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),

            // Add to cart button
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: product.isInStock && !isAddingToCart
                    ? onAddToCart
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: isAddingToCart
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  product.isInStock ? 'Add to Cart' : 'Out of Stock',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}