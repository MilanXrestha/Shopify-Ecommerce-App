import 'package:e_commerce_app/features/products/presentation/screens/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logger/logger.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/error_display.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/config/routes/route_name.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../products/presentation/widgets/quantity_selector.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/repositories/cart_repository.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProducts;

  const CartScreen({super.key, this.onNavigateToProducts});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  late CartRepository _cartRepository;
  final Logger _logger = Logger();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appScope = AppScope.of(context);
    _cartRepository = appScope.cartRepository;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _updateQuantity(CartItemModel item, int newQuantity) async {
    try {
      await _cartRepository.updateQuantity(item.id, newQuantity);
    } catch (e) {
      _logger.e('Error updating quantity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeItem(CartItemModel item) async {
    try {
      await _cartRepository.removeFromCart(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.product.title} removed from cart'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _cartRepository.addToCart(
                product: item.product,
                quantity: item.quantity,
                selectedSize: item.selectedSize,
                selectedColor: item.selectedColor,
                selectedStorage: item.selectedStorage,
              );
            },
          ),
        ),
      );
    } catch (e) {
      _logger.e('Error removing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing item: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _cartRepository.clearCart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart cleared')),
        );
      } catch (e) {
        _logger.e('Error clearing cart: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cart: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _proceedToCheckout() {
    final summary = _cartRepository.getCartSummary();
    final checkoutData = {
      ...summary,
      'countryDefault': 'Nepal',
      'paymentMethods': [
        {
          'id': 'cash_on_delivery',
          'name': 'Cash on Delivery',
          'isDefault': true,
        },
        {'id': 'khalti', 'name': 'Khalti', 'isDefault': false},
        {'id': 'esewa', 'name': 'eSewa', 'isDefault': false},
        {'id': 'connectips', 'name': 'ConnectIPS', 'isDefault': false},
      ],
    };
    Navigator.pushNamed(
      context,
      RoutesName.checkoutScreen,
      arguments: checkoutData,
    );
  }

  void _navigateToShop() {
    if (widget.onNavigateToProducts != null) {
      // We're in bottom nav - use callback to switch to ProductsScreen tab
      widget.onNavigateToProducts?.call();
    } else {
      // Create a smooth transition back to main screen with products tab
      Navigator.pushNamed(
        context,
        RoutesName.mainScreen,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Material(
          color: Colors.white,
          elevation: 1,
          child: AppBar(
            title: const Text(
              'My Shopping Cart',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              ValueListenableBuilder(
                valueListenable: _cartRepository.cartItems,
                builder: (context, items, _) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: _clearCart,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/svg/ic_delete.svg',
                            width: 24,
                            height: 24,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: _cartRepository.isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder(
            valueListenable: _cartRepository.error,
            builder: (context, error, _) {
              if (error != null) {
                return ErrorDisplay(
                  error: error,
                  onRetry: () => _cartRepository.loadCart(),
                );
              }
              return ValueListenableBuilder(
                valueListenable: _cartRepository.cartItems,
                builder: (context, items, _) {
                  if (items.isEmpty) {
                    return _buildEmptyCart();
                  }
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Expanded(child: _buildCartItems(items)),
                        _buildCartSummary(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add items to get started',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _navigateToShop,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(List<CartItemModel> items) {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: items.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final item = items[index];
        return Slidable(
          key: ValueKey(item.id),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => _removeItem(item),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Delete',
                borderRadius: BorderRadius.circular(12.r),
              ),
            ],
          ),
          child: _buildCartItem(item),
        );
      },
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 120.w;
        return Stack(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProductDetailScreen(productId: item.product.id),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: CachedNetworkImage(
                        imageUrl: item.product.thumbnail,
                        width: 70.w,
                        height: 70.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error, size: 20),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  SizedBox(
                    width: availableWidth - 30.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.product.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        if (item.selectedSize != null ||
                            item.selectedColor != null ||
                            item.selectedStorage != null) ...[
                          SizedBox(
                            width: availableWidth,
                            child: Wrap(
                              spacing: 4.w,
                              runSpacing: 4.h,
                              children: [
                                if (item.selectedSize != null)
                                  _buildVariantChip('Size: ${item.selectedSize}'),
                                if (item.selectedColor != null)
                                  _buildVariantChip('Color: ${item.selectedColor}'),
                                if (item.selectedStorage != null)
                                  _buildVariantChip(item.selectedStorage!),
                              ],
                            ),
                          ),
                          SizedBox(height: 4.h),
                        ],
                        Row(
                          children: [
                            Text(
                              '\$${item.product.discountedPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            if (item.product.discountPercentage > 0) ...[
                              SizedBox(width: 6.w),
                              Text(
                                '\$${item.product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              height: 32.h,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: item.quantity > 1
                                        ? () => _updateQuantity(
                                      item,
                                      item.quantity - 1,
                                    )
                                        : null,
                                    child: Container(
                                      width: 32.w,
                                      height: 32.h,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.remove,
                                        size: 18.sp,
                                        color: item.quantity > 1
                                            ? Colors.black
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 36.w,
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.quantity.toString(),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: item.quantity < item.product.stock
                                        ? () => _updateQuantity(
                                      item,
                                      item.quantity + 1,
                                    )
                                        : null,
                                    child: Container(
                                      width: 32.w,
                                      height: 32.h,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.add,
                                        size: 18.sp,
                                        color: item.quantity < item.product.stock
                                            ? Colors.black
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${item.totalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (item.quantity > item.product.stock - 3 &&
                            item.product.stock > 0)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(
                              'Only ${item.product.stock} left',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8.h,
              right: 8.w,
              child: InkWell(
                onTap: () => _removeItem(item),
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  width: 28.w,
                  height: 28.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVariantChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      margin: EdgeInsets.only(bottom: 2.h, right: 3.w),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
    final summary = _cartRepository.getCartSummary();
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Subtotal', summary['subtotal']),
            if (summary['discount'] > 0)
              _buildSummaryRow('Discount', -summary['discount'], isDiscount: true),
            _buildSummaryRow('Shipping', summary['shipping']),
            _buildSummaryRow('Tax', summary['tax']),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Divider(color: Colors.grey[300]),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${summary['total'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _proceedToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                minimumSize: Size.fromHeight(50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Proceed to Checkout (${summary['itemCount']} items)',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
          Text(
            '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDiscount ? Colors.green : Colors.grey[800],
              fontWeight: isDiscount ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}