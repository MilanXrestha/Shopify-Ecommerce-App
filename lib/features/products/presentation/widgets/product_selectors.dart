import 'package:e_commerce_app/features/products/presentation/widgets/quantity_selector.dart';
import 'package:e_commerce_app/features/products/presentation/widgets/size_selector.dart';
import 'package:flutter/material.dart';
import '../../../../../common/theme/app_colors.dart';
import '../../data/models/product_model.dart';
import 'color_selector.dart';


class ProductSelectors extends StatelessWidget {
  final ProductModel product;
  final List<Color> availableColors;
  final List<String> availableSizes;
  final List<String> storageOptions;
  final List<String> clothingCategories;
  final List<String> colorOnlyCategories;
  final List<String> electronicsCategories;
  final Color? selectedColor;
  final String? selectedSize;
  final String? selectedStorage;
  final int quantity;
  final Function(Color) onColorSelected;
  final Function(String) onSizeSelected;
  final Function(String) onStorageSelected;
  final Function(int) onQuantityChanged;

  const ProductSelectors({
    super.key,
    required this.product,
    required this.availableColors,
    required this.availableSizes,
    required this.storageOptions,
    required this.clothingCategories,
    required this.colorOnlyCategories,
    required this.electronicsCategories,
    required this.selectedColor,
    required this.selectedSize,
    required this.selectedStorage,
    required this.quantity,
    required this.onColorSelected,
    required this.onSizeSelected,
    required this.onStorageSelected,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final category = product.category.toLowerCase();
    final isClothing = clothingCategories.contains(category);
    final hasColorOption = isClothing || colorOnlyCategories.contains(category);
    final isElectronics = electronicsCategories.contains(category);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color selector
          if (hasColorOption) ...[
            const Text(
              'Colors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ColorSelector(
              colors: availableColors,
              selectedColor: selectedColor,
              onColorSelected: onColorSelected,
            ),
            const SizedBox(height: 20),
          ],

          // Size selector
          if (isClothing) ...[
            const Text(
              'Sizes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizeSelector(
              sizes: availableSizes,
              selectedSize: selectedSize,
              onSizeSelected: onSizeSelected,
            ),
            const SizedBox(height: 20),
          ],

          // Storage options
          if (isElectronics) ...[
            _buildStorageOptions(context),
            const SizedBox(height: 20),
          ],

          // Quantity selector
          const Text(
            'Quantity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          QuantitySelector(
            quantity: quantity,
            maxQuantity: product.stock,
            minQuantity: 1,
            onChanged: onQuantityChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Storage',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: storageOptions.map((option) {
            final isSelected = option == selectedStorage;
            return GestureDetector(
              onTap: () => onStorageSelected(option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryLight
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}