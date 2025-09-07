import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../common/widgets/error_display.dart';
import '../../../../core/app_scope.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repositories/products_repository.dart';
import '../../products/presentation/screens/product_detail_screen.dart';
import '../../products/presentation/widgets/product_card.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;
  final List<ProductModel> initialProducts;

  const SearchResultsScreen({
    super.key,
    required this.searchQuery,
    this.initialProducts = const [],
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late ProductsRepository _productsRepository;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<ProductModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _searchResults = widget.initialProducts;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appScope = AppScope.of(context);
    _productsRepository = ProductsRepository(
      appScope.apiClient,
      appScope.databaseHelper,
    );
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _productsRepository.searchProducts(
        _searchController.text,
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _search();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchResults = [];
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _search();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_productsRepository.error.value != null) {
      return ErrorDisplay(
        error: _productsRepository.error.value!,
        onRetry: _search,
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.searchQuery == 'Filtered Products'
                  ? 'No products found for applied filters'
                  : 'No products found for "${_searchController.text}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords or browse categories',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return ProductCard(
          product: product,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProductDetailScreen(productId: product.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        padding: const EdgeInsets.all(8),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Container(
            height: 220 + (index % 2) * 40,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
