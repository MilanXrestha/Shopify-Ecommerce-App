class CategoryModel {
  final String name;
  final String slug;
  final bool isLocal;
  final int? timestamp;

  CategoryModel({
    required this.name,
    required this.slug,
    this.isLocal = false,
    this.timestamp,
  });

  factory CategoryModel.fromJson(dynamic category) {
    // If category is a string
    if (category is String) {
      return CategoryModel(
        name: formatCategoryName(category),
        slug: category,
        isLocal: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    // If category is a map
    if (category is Map<String, dynamic>) {
      return CategoryModel(
        name: category['name'] ?? formatCategoryName(category['slug'] ?? ''),
        slug: category['slug'] ?? '',
        isLocal: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    // Default fallback
    return CategoryModel(
      name: formatCategoryName(category.toString()),
      slug: category.toString(),
      isLocal: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory CategoryModel.fromDatabase(Map<String, dynamic> map) {
    return CategoryModel(
      name: map['name'] ?? formatCategoryName(map['slug'] ?? ''),
      slug: map['slug'] ?? '',
      isLocal: map['isLocal'] == 1,
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'isLocal': isLocal ? 1 : 0,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Helper method to format category name from slug (made public by removing underscore)
  static String formatCategoryName(String input) {
    // Convert 'womens-dresses' to 'Women's Dresses'
    return input
        .split('-')
        .map(
          (word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }

  // Override toString to ensure proper string representation
  @override
  String toString() {
    return name;
  }
}