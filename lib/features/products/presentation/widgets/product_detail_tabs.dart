import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../../../../common/theme/app_colors.dart';
import '../../data/models/product_model.dart';

class ProductDetailTabs extends StatefulWidget {
  final ProductModel product;

  const ProductDetailTabs({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailTabs> createState() => _ProductDetailTabsState();
}

class _ProductDetailTabsState extends State<ProductDetailTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppColors.primaryLight,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Description'),
              Tab(text: 'Specifications'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),

        // CONDITIONAL LOGIC HERE - add space only for specifications tab
        if (_currentTabIndex == 1) // Specifications tab
          _buildSpecificationsTab()
        else if (_currentTabIndex == 0) // Description tab
          _buildDescriptionTab()
        else // Reviews tab
          _buildReviewsTab()
      ],
    );
  }

  Widget _buildDescriptionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Description text - no extra padding
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            widget.product.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),

        // Warranty information if available
        if (widget.product.warrantyInformation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warranty',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.warrantyInformation,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Return policy if available
        if (widget.product.returnPolicy.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.assignment_return_outlined,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Returns',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.returnPolicy,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpecificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Basic specs
          _buildSpecRow('Brand', widget.product.brand),
          _buildSpecRow('Category', widget.product.category),
          _buildSpecRow('Stock', widget.product.stock.toString()),

          if (widget.product.sku.isNotEmpty)
            _buildSpecRow('SKU', widget.product.sku),

          if (widget.product.weight > 0)
            _buildSpecRow('Weight', '${widget.product.weight} kg'),

          // Dimensions if available
          if (widget.product.dimensions != null) ...[
            _buildSpecRow(
              'Dimensions',
              '${widget.product.dimensions!.width} × ${widget.product.dimensions!.height} × ${widget.product.dimensions!.depth} cm',
            ),
          ],

          // Creation date if available
          if (widget.product.meta != null && widget.product.meta!.createdAt != null) ...[
            _buildSpecRow(
              'Listed on',
              DateFormat.yMMMMd().format(widget.product.meta!.createdAt),
            ),
          ],

          // Barcode if available
          if (widget.product.meta != null && widget.product.meta!.barcode.isNotEmpty) ...[
            _buildSpecRow('Barcode', widget.product.meta!.barcode),
          ],

          const SizedBox(height: 16),

          // Additional info section
          const Text(
            'Additional Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                if (widget.product.shippingInformation.isNotEmpty)
                  _buildInfoRow(
                    Icons.local_shipping_outlined,
                    'Shipping',
                    widget.product.shippingInformation,
                  ),
                if (widget.product.warrantyInformation.isNotEmpty)
                  _buildInfoRow(
                    Icons.verified_user_outlined,
                    'Warranty',
                    widget.product.warrantyInformation,
                  ),
                if (widget.product.returnPolicy.isNotEmpty)
                  _buildInfoRow(
                    Icons.assignment_return_outlined,
                    'Returns',
                    widget.product.returnPolicy,
                  ),
                _buildInfoRow(
                  Icons.inventory_2_outlined,
                  'Availability',
                  widget.product.availabilityStatus.isNotEmpty
                      ? widget.product.availabilityStatus
                      : (widget.product.isInStock ? 'In Stock' : 'Out of Stock'),
                ),
              ],
            ),
          ),

          // Add extra bottom space to ensure all content is visible
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (widget.product.reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No reviews yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to review this product',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // No extra padding - just the reviews
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.product.reviews.length; i++) ...[
          _buildReviewItem(widget.product.reviews[i]),
          if (i < widget.product.reviews.length - 1)
            Divider(color: Colors.grey[200]),
        ],
      ],
    );
  }

  Widget _buildReviewItem(dynamic review) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  review.reviewerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat.yMMMd().format(review.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              RatingBarIndicator(
                rating: review.rating.toDouble(),
                itemBuilder: (context, index) =>
                const Icon(Icons.star, color: AppColors.starRating),
                itemCount: 5,
                itemSize: 14,
              ),
              const SizedBox(width: 4),
              Text(
                review.rating.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}