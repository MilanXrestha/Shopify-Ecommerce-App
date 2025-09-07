import '../../../products/data/models/product_model.dart';

class CartItemModel {
  final int id;
  final ProductModel product;
  int quantity;
  final DateTime addedAt;

  // Optional attributes for variants
  final String? selectedSize;
  final String? selectedColor;
  final String? selectedStorage;

  CartItemModel({
    required this.id,
    required this.product,
    required this.quantity,
    required this.addedAt,
    this.selectedSize,
    this.selectedColor,
    this.selectedStorage,
  });

  // Calculate total price for this cart item
  double get totalPrice => product.discountedPrice * quantity;

  // Create a unique key for this cart item (useful for variants)
  String get uniqueKey {
    String key = '${product.id}';
    if (selectedSize != null) key += '_$selectedSize';
    if (selectedColor != null) key += '_$selectedColor';
    if (selectedStorage != null) key += '_$selectedStorage';
    return key;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': product.id,
      'quantity': quantity,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'selectedSize': selectedSize,
      'selectedColor': selectedColor,
      'selectedStorage': selectedStorage,
    };
  }

  factory CartItemModel.fromMap(
    Map<String, dynamic> map,
    ProductModel product,
  ) {
    return CartItemModel(
      id: map['id'],
      product: product,
      quantity: map['quantity'],
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt']),
      selectedSize: map['selectedSize'],
      selectedColor: map['selectedColor'],
      selectedStorage: map['selectedStorage'],
    );
  }

  CartItemModel copyWith({
    int? id,
    ProductModel? product,
    int? quantity,
    DateTime? addedAt,
    String? selectedSize,
    String? selectedColor,
    String? selectedStorage,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedStorage: selectedStorage ?? this.selectedStorage,
    );
  }
}
