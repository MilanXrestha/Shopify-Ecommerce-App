import 'dart:async';
import 'package:e_commerce_app/common/constants/app_constants.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

import '../../features/category/data/models/category_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final Logger _logger = Logger();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<void> initDatabase() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    _logger.i('Initializing database at $path');

    _database = await openDatabase(
      path,
      version: 4, // Increment version to force migration
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
      onOpen: _onDatabaseOpen,
    );
  }

  // Add an onOpen callback to verify and fix schema if needed
  Future<void> _onDatabaseOpen(Database db) async {
    _logger.i('Database opened, verifying schema integrity');
    await _ensureCategoriesSchema(db);
  }

  // Check and fix categories table schema if needed
  Future<void> _ensureCategoriesSchema(Database db) async {
    try {
      // Check if imagePath column exists in categories table
      var tableInfo = await db.rawQuery("PRAGMA table_info(categories)");
      var columnNames = tableInfo.map((col) => col['name'].toString()).toList();

      _logger.d('Categories table columns: $columnNames');

      if (!columnNames.contains('imagePath')) {
        _logger.w('imagePath column missing from categories table. Adding it now.');
        await db.execute('ALTER TABLE categories ADD COLUMN imagePath TEXT');
        _logger.i('Successfully added imagePath column to categories table');
      }
    } catch (e) {
      _logger.e('Error ensuring categories schema: $e');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    await initDatabase();
    return _database!;
  }

  Future<void> _createDb(Database db, int version) async {
    _logger.i('Creating database tables (version $version)');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        discountPercentage REAL,
        rating REAL,
        stock INTEGER,
        brand TEXT,
        category TEXT,
        thumbnail TEXT,
        images TEXT,
        tags TEXT,
        sku TEXT,
        weight REAL,
        dimensions TEXT,
        warrantyInformation TEXT,
        shippingInformation TEXT,
        availabilityStatus TEXT,
        reviews TEXT,
        returnPolicy TEXT,
        minimumOrderQuantity INTEGER,
        meta TEXT,
        timestamp INTEGER
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        isLocal INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT,
        timestamp INTEGER
      )
    ''');

    // Cart items table
    await db.execute('''
      CREATE TABLE cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        selectedSize TEXT,
        selectedColor TEXT,
        selectedStorage TEXT,
        FOREIGN KEY (productId) REFERENCES products (id)
        )
        ''');

    // User profile table
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT,
        phone TEXT,
        avatarUrl TEXT
      )
    ''');

    // Banners table for caching
    await db.execute('''
      CREATE TABLE banners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        title TEXT NOT NULL,
        image TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    // Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL UNIQUE,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');
  }

  // Handle database migrations
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    _logger.i('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // Add new columns to products table if upgrading from version 1
      try {
        // Check if columns already exist to avoid errors
        var tableInfo = await db.rawQuery("PRAGMA table_info(products)");
        var columnNames = tableInfo
            .map((col) => col['name'].toString())
            .toList();

        // Add new columns if they don't exist
        if (!columnNames.contains('tags')) {
          await db.execute('ALTER TABLE products ADD COLUMN tags TEXT');
        }

        if (!columnNames.contains('sku')) {
          await db.execute('ALTER TABLE products ADD COLUMN sku TEXT');
        }

        if (!columnNames.contains('weight')) {
          await db.execute('ALTER TABLE products ADD COLUMN weight REAL');
        }

        if (!columnNames.contains('dimensions')) {
          await db.execute('ALTER TABLE products ADD COLUMN dimensions TEXT');
        }

        if (!columnNames.contains('warrantyInformation')) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN warrantyInformation TEXT',
          );
        }

        if (!columnNames.contains('shippingInformation')) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN shippingInformation TEXT',
          );
        }

        if (!columnNames.contains('availabilityStatus')) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN availabilityStatus TEXT',
          );
        }

        if (!columnNames.contains('reviews')) {
          await db.execute('ALTER TABLE products ADD COLUMN reviews TEXT');
        }

        if (!columnNames.contains('returnPolicy')) {
          await db.execute('ALTER TABLE products ADD COLUMN returnPolicy TEXT');
        }

        if (!columnNames.contains('minimumOrderQuantity')) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN minimumOrderQuantity INTEGER',
          );
        }

        if (!columnNames.contains('meta')) {
          await db.execute('ALTER TABLE products ADD COLUMN meta TEXT');
        }

        _logger.i('Successfully added new columns to products table');
      } catch (e) {
        _logger.e('Error upgrading database: $e');
      }
    }

    // Add imagePath to categories table for version 3 or 4
    if (oldVersion < 4) {
      try {
        // Check if imagePath column already exists to avoid errors
        var tableInfo = await db.rawQuery("PRAGMA table_info(categories)");
        var columnNames = tableInfo
            .map((col) => col['name'].toString())
            .toList();

        _logger.d('Categories columns before migration: $columnNames');

        if (!columnNames.contains('imagePath')) {
          _logger.d('Adding imagePath column to categories table');
          await db.execute('ALTER TABLE categories ADD COLUMN imagePath TEXT');
          _logger.i('Successfully added imagePath column to categories table');
        } else {
          _logger.d('imagePath column already exists in categories table');
        }
      } catch (e) {
        _logger.e('Error adding imagePath to categories table: ');
      }
    }
  }

  Future<void> recreateDatabase() async {
    _logger.w('Recreating database from scratch');
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    // Close database if open
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Delete database file
    await deleteDatabase(path);

    // Reinitialize database
    await initDatabase();
    _logger.i('Database recreated successfully');
  }

  // Products methods
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert(
      'products',
      product,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getProducts({
    int? limit,
    int? offset,
    String? search,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? brand,
    double? minRating,
    String? availabilityStatus,
    String? tags,
    String? sortBy,
    bool? sortAscending,
  }) async {
    final db = await database;
    String query = 'SELECT * FROM products';
    List<dynamic> args = [];
    List<String> conditions = [];

    // Apply filters
    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }

    if (search != null && search.isNotEmpty) {
      conditions.add('(title LIKE ? OR description LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }

    if (minPrice != null) {
      conditions.add('price >= ?');
      args.add(minPrice);
    }

    if (maxPrice != null) {
      conditions.add('price <= ?');
      args.add(maxPrice);
    }

    if (brand != null && brand.isNotEmpty) {
      conditions.add('brand = ?');
      args.add(brand);
    }

    if (minRating != null) {
      conditions.add('rating >= ?');
      args.add(minRating);
    }

    if (availabilityStatus != null) {
      conditions.add('availabilityStatus = ?');
      args.add(availabilityStatus);
    }

    if (tags != null && tags.isNotEmpty) {
      // Note: This is a simplistic approach - tags are stored as JSON in SQLite
      // A better approach would use JSON functions if your SQLite version supports them
      conditions.add('tags LIKE ?');
      args.add('%$tags%');
    }

    // Add WHERE clause if we have conditions
    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    // Add ORDER BY clause based on sortBy and sortAscending
    if (sortBy != null) {
      String direction = (sortAscending ?? true) ? 'ASC' : 'DESC';

      switch (sortBy) {
        case 'price':
          query += ' ORDER BY price $direction';
          break;
        case 'rating':
          query += ' ORDER BY rating $direction';
          break;
        case 'discount':
          query += ' ORDER BY discountPercentage $direction';
          break;
        case 'title':
          query += ' ORDER BY title $direction';
          break;
        case 'date':
        // Assuming timestamp represents creation date
          query += ' ORDER BY timestamp $direction';
          break;
        case 'popularity':
        default:
        // A simple popularity formula combining rating and discount
          query +=
          ' ORDER BY (rating * 3 + discountPercentage * 0.2) $direction';
          break;
      }
    } else {
      // Default ordering by timestamp (newest first)
      query += ' ORDER BY timestamp DESC';
    }

    // Add pagination
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);

      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }

    return await db.rawQuery(query, args);
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Get similar products
  Future<List<Map<String, dynamic>>> getSimilarProducts(
      int productId,
      String category,
      String? brand, {
        int limit = 5,
      }) async {
    final db = await database;

    // First try to find products in same category and brand
    List<Map<String, dynamic>> results = [];

    if (brand != null && brand.isNotEmpty) {
      results = await db.query(
        'products',
        where: 'id != ? AND category = ? AND brand = ?',
        whereArgs: [productId, category, brand],
        limit: limit,
      );
    }

    // If we don't have enough results, get more from the same category
    if (results.length < limit) {
      final remainingLimit = limit - results.length;
      final moreResults = await db.query(
        'products',
        where: 'id != ? AND category = ? AND (brand != ? OR brand IS NULL)',
        whereArgs: [productId, category, brand ?? ''],
        limit: remainingLimit,
      );

      results.addAll(moreResults);
    }

    // If we still need more, get products from other categories
    if (results.length < limit) {
      final remainingLimit = limit - results.length;
      final existingIds = [productId, ...results.map((r) => r['id'] as int)];

      final moreResults = await db.query(
        'products',
        where: 'id NOT IN (${existingIds.join(',')})',
        limit: remainingLimit,
      );

      results.addAll(moreResults);
    }

    return results;
  }

  // Categories methods
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    _logger.d(
      'Inserting category: ${category['name']}, slug: ${category['slug']}',
    );
    return await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<void> debugCategories() async {
    final categories = await getCategories();
    for (var category in categories) {
      _logger.d('Database category: $category');
    }
  }

  Future<void> migrateCategoryNames() async {
    final db = await database;
    final categories = await getCategories();
    for (var category in categories) {
      final formattedName = CategoryModel.formatCategoryName(category['slug']);
      await db.update(
        'categories',
        {'name': formattedName},
        where: 'slug = ?',
        whereArgs: [category['slug']],
      );
      _logger.d(
        'Migrated category: slug=${category['slug']}, new name=$formattedName',
      );
    }
    _logger.i('Category names migrated');
  }

  Future<void> clearCategories() async {
    final db = await database;
    await db.delete('categories');
    _logger.i('Categories table cleared');
  }

  // Cart methods
  Future<int> insertCartItem(Map<String, dynamic> cartItem) async {
    final db = await database;

    // Check if product already exists in cart with same variants
    final List<Map<String, dynamic>> existing = await db.query(
      'cart_items',
      where:
      'productId = ? AND selectedSize = ? AND selectedColor = ? AND selectedStorage = ?',
      whereArgs: [
        cartItem['productId'],
        cartItem['selectedSize'],
        cartItem['selectedColor'],
        cartItem['selectedStorage'],
      ],
    );

    if (existing.isNotEmpty) {
      // Update quantity
      return await db.update(
        'cart_items',
        {'quantity': existing.first['quantity'] + cartItem['quantity']},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }

    return await db.insert('cart_items', cartItem);
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT ci.*, p.title, p.price, p.thumbnail, p.discountPercentage, 
           p.availabilityStatus, p.stock, p.minimumOrderQuantity
    FROM cart_items ci
    JOIN products p ON ci.productId = p.id
  ''');
  }

  Future<int> updateCartItemQuantity(int productId, int quantity) async {
    final db = await database;
    return await db.update(
      'cart_items',
      {'quantity': quantity},
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  Future<int> deleteCartItem(int productId) async {
    final db = await database;
    return await db.delete(
      'cart_items',
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  // User profile methods
  Future<int> saveUserProfile(Map<String, dynamic> profile) async {
    final db = await database;

    // Check if user exists
    final List<Map<String, dynamic>> users = await db.query('user_profile');

    if (users.isEmpty) {
      return await db.insert('user_profile', profile);
    } else {
      return await db.update(
        'user_profile',
        profile,
        where: 'id = ?',
        whereArgs: [users.first['id']],
      );
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> users = await db.query('user_profile');

    if (users.isNotEmpty) {
      return users.first;
    }
    return null;
  }

  // Favorites methods
  Future<int> toggleFavorite(int productId) async {
    final db = await database;

    // Check if product is already a favorite
    final List<Map<String, dynamic>> favorites = await db.query(
      'favorites',
      where: 'productId = ?',
      whereArgs: [productId],
    );

    if (favorites.isEmpty) {
      // Add to favorites
      return await db.insert('favorites', {
        'productId': productId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      // Remove from favorites
      return await db.delete(
        'favorites',
        where: 'productId = ?',
        whereArgs: [productId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, f.timestamp as favTimestamp
      FROM favorites f
      JOIN products p ON f.productId = p.id
      ORDER BY f.timestamp DESC
    ''');
  }

  Future<bool> isFavorite(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> favorites = await db.query(
      'favorites',
      where: 'productId = ?',
      whereArgs: [productId],
    );

    return favorites.isNotEmpty;
  }

  // Custom category methods
  Future<List<Map<String, dynamic>>> getLocalCategories() async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'isLocal = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
  }

  // Updated to accept imagePath
  Future<int> insertLocalCategory(String name, String slug, String? imagePath) async {
    final db = await database;

    // Ensure the column exists before trying to insert
    await _ensureCategoriesSchema(db);

    _logger.d('Inserting local category: $name, slug: $slug, imagePath: $imagePath');

    return await db.insert('categories', {
      'name': name,
      'slug': slug,
      'isLocal': 1,
      'imagePath': imagePath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteLocalCategory(String slug) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'slug = ? AND isLocal = 1',
      whereArgs: [slug],
    );
  }

  Future<bool> categorySlugExists(String slug) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Get a single category by slug
  Future<Map<String, dynamic>?> getCategoryBySlug(String slug) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'categories',
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Database statistics and utilities
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    final stats = <String, dynamic>{};

    // Get product count
    final productCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products'),
    );
    stats['productsCount'] = productCount;

    // Get favorites count
    final favoritesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM favorites'),
    );
    stats['favoritesCount'] = favoritesCount;

    // Get cart count
    final cartCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cart_items'),
    );
    stats['cartCount'] = cartCount;

    // Get categories count
    final categoriesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    stats['categoriesCount'] = categoriesCount;

    // Get local categories count
    final localCategoriesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories WHERE isLocal = 1'),
    );
    stats['localCategoriesCount'] = localCategoriesCount;

    // Get database size (approximate)
    final dbSize = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()',
      ),
    );
    stats['databaseSizeBytes'] = dbSize;

    return stats;
  }

  // Clear all database data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('favorites');
    await db.delete('cart_items');
    await db.delete('products');
    await db.delete('categories');
    await db.delete('banners');
    _logger.w('All database data cleared');
  }
}