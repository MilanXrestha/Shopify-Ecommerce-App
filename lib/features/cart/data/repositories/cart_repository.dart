// lib/features/cart/data/repositories/cart_repository.dart
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../../../core/database/database_helper.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../models/cart_item_model.dart';

class CartRepository {
  final DatabaseHelper _databaseHelper;
  final ProductsRepository _productsRepository;
  final Logger _logger = Logger();

  // State notifiers
  final ValueNotifier<List<CartItemModel>> cartItems =
      ValueNotifier<List<CartItemModel>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  CartRepository(this._databaseHelper, this._productsRepository) {
    loadCart();
  }

  // Load cart items from database
  Future<void> loadCart() async {
    isLoading.value = true;
    error.value = null;

    try {
      final cartData = await _databaseHelper.getCartItems();
      final List<CartItemModel> items = [];

      for (var item in cartData) {
        try {
          // Get product details
          ProductModel? product = await _productsRepository.getProductById(
            item['productId'],
          );

          if (product != null) {
            items.add(
              CartItemModel(
                id: item['id'],
                product: product,
                quantity: item['quantity'],
                addedAt: DateTime.now(),
                // You might want to store this in DB
                selectedSize: item['selectedSize'],
                selectedColor: item['selectedColor'],
                selectedStorage: item['selectedStorage'],
              ),
            );
          }
        } catch (e) {
          _logger.e('Error loading cart item: $e');
        }
      }

      cartItems.value = items;
      _logger.i('Loaded ${items.length} cart items');
    } catch (e) {
      _logger.e('Error loading cart: $e');
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // Add item to cart
  Future<void> addToCart({
    required ProductModel product,
    required int quantity,
    String? selectedSize,
    String? selectedColor,
    String? selectedStorage,
  }) async {
    try {
      // Check if item already exists with same variants
      final existingIndex = cartItems.value.indexWhere(
        (item) =>
            item.product.id == product.id &&
            item.selectedSize == selectedSize &&
            item.selectedColor == selectedColor &&
            item.selectedStorage == selectedStorage,
      );

      if (existingIndex != -1) {
        // Update quantity if item exists
        final existingItem = cartItems.value[existingIndex];
        await updateQuantity(existingItem.id, existingItem.quantity + quantity);
      } else {
        // Add new item
        final cartItem = {
          'productId': product.id,
          'quantity': quantity,
          'selectedSize': selectedSize,
          'selectedColor': selectedColor,
          'selectedStorage': selectedStorage,
        };

        final id = await _databaseHelper.insertCartItem(cartItem);

        final newItem = CartItemModel(
          id: id,
          product: product,
          quantity: quantity,
          addedAt: DateTime.now(),
          selectedSize: selectedSize,
          selectedColor: selectedColor,
          selectedStorage: selectedStorage,
        );

        cartItems.value = [...cartItems.value, newItem];
        _logger.i('Added ${product.title} to cart');
      }
    } catch (e) {
      _logger.e('Error adding to cart: $e');
      throw e;
    }
  }

  // Update item quantity
  Future<void> updateQuantity(int cartItemId, int newQuantity) async {
    try {
      if (newQuantity <= 0) {
        await removeFromCart(cartItemId);
        return;
      }

      // Find the cart item
      final index = cartItems.value.indexWhere((item) => item.id == cartItemId);
      if (index == -1) return;

      final item = cartItems.value[index];

      // Check stock availability
      if (newQuantity > item.product.stock) {
        throw Exception('Not enough stock available');
      }


      // Update in database
      await _databaseHelper.updateCartItemQuantity(
        item.product.id,
        newQuantity,
      );

      // Update in memory
      final updatedItems = List<CartItemModel>.from(cartItems.value);
      updatedItems[index] = item.copyWith(quantity: newQuantity);
      cartItems.value = updatedItems;

      _logger.i('Updated quantity for ${item.product.title} to $newQuantity');
    } catch (e) {
      _logger.e('Error updating quantity: $e');
      throw e;
    }
  }

  // Remove item from cart
  Future<void> removeFromCart(int cartItemId) async {
    try {
      final item = cartItems.value.firstWhere((item) => item.id == cartItemId);

      // Remove from database
      await _databaseHelper.deleteCartItem(item.product.id);

      // Remove from memory
      cartItems.value = cartItems.value
          .where((item) => item.id != cartItemId)
          .toList();

      _logger.i('Removed ${item.product.title} from cart');
    } catch (e) {
      _logger.e('Error removing from cart: $e');
      throw e;
    }
  }

  // Clear entire cart
  Future<void> clearCart() async {
    try {
      // Clear all items from database
      for (var item in cartItems.value) {
        await _databaseHelper.deleteCartItem(item.product.id);
      }

      // Clear from memory
      cartItems.value = [];

      _logger.i('Cart cleared');
    } catch (e) {
      _logger.e('Error clearing cart: $e');
      throw e;
    }
  }

  // Get cart summary
  Map<String, dynamic> getCartSummary() {
    double subtotal = 0;
    double totalDiscount = 0;
    int totalItems = 0;

    for (var item in cartItems.value) {
      subtotal += item.product.price * item.quantity;
      totalDiscount +=
          (item.product.price - item.product.discountedPrice) * item.quantity;
      totalItems += item.quantity;
    }

    final shipping = subtotal > 50 ? 0.0 : 10.0; // Free shipping over $50
    final tax = (subtotal - totalDiscount) * 0.08; // 8% tax
    final total = subtotal - totalDiscount + shipping + tax;

    return {
      'subtotal': subtotal,
      'discount': totalDiscount,
      'shipping': shipping,
      'tax': tax,
      'total': total,
      'totalItems': totalItems,
      'itemCount': cartItems.value.length,
    };
  }

  // Check if product is in cart
  bool isInCart(int productId) {
    return cartItems.value.any((item) => item.product.id == productId);
  }

  // Get cart item by product id
  CartItemModel? getCartItem(int productId) {
    try {
      return cartItems.value.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }
}
