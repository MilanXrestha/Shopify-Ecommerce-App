import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../../common/theme/app_colors.dart';
import '../../../../../core/app_scope.dart';
import '../../../../../core/config/routes/route_name.dart';
import '../../data/models/product_model.dart';

class ProductAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ProductModel? product;
  final bool isLoading;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const ProductAppBar({
    super.key,
    required this.product,
    required this.isLoading,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!isLoading && product != null)
          _buildAppBarIcon(
            icon: const Icon(Icons.share, color: Colors.black, size: 20),
            onTap: () => _shareProduct(context, product!),
          ),
        _buildAppBarIcon(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.black,
            size: 20,
          ),
          onTap: isLoading ? null : onToggleFavorite,
        ),
        ValueListenableBuilder(
          valueListenable: AppScope.of(context).cartRepository.cartItems,
          builder: (context, cartItems, _) {
            final itemCount = cartItems.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            );

            return _buildAppBarIcon(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.asset(
                    'assets/icons/svg/ic_cart.svg',
                    color: Colors.black,
                    width: 20,
                    height: 20,
                  ),
                  if (itemCount > 0)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            itemCount > 99 ? '99+' : itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () => Navigator.pushNamed(context, RoutesName.cartScreen),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  Widget _buildAppBarIcon({required Widget icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: icon),
      ),
    );
  }

  void _shareProduct(BuildContext context, ProductModel product) {
    // Implement your share functionality here
  }
}
