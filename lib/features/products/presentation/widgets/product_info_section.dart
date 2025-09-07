import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../../../common/theme/app_colors.dart';
import '../../data/models/product_model.dart';

class ProductInfoSection extends StatelessWidget {
  final ProductModel product;

  const ProductInfoSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand
          Text(
            product.brand,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 6),

          // Title
          Text(
            product.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 12),

          // Rating
          Row(
            children: [
              RatingBarIndicator(
                rating: product.rating,
                itemBuilder: (context, index) =>
                    const Icon(Icons.star, color: AppColors.starRating),
                itemCount: 5,
                itemSize: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${product.rating.toStringAsFixed(1)} (${product.reviews.isEmpty ? '0' : product.reviews.length.toString()} reviews)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Price
          Row(
            children: [
              Text(
                '\$${product.discountedPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              if (product.discountPercentage > 0) ...[
                const SizedBox(width: 12),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[500],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Stock status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: product.availabilityStatus == "In Stock"
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.errorLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              product.availabilityStatus.isNotEmpty
                  ? '${product.availabilityStatus} (${product.stock} available)'
                  : product.isInStock
                  ? 'In Stock (${product.stock} available)'
                  : 'Out of Stock',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: product.isInStock
                    ? AppColors.success
                    : AppColors.errorLight,
              ),
            ),
          ),

          // Shipping info
          if (product.shippingInformation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    product.shippingInformation,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],

          // SKU
          if (product.sku.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'SKU: ${product.sku}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}
