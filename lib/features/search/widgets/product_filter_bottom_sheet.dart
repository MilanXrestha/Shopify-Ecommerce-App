import 'package:e_commerce_app/features/search/widgets/product_filter_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../common/theme/app_colors.dart';
import '../../products/data/repositories/products_repository.dart';

class ProductFilterBottomSheet extends StatefulWidget {
  final ProductFilterModel initialFilter;
  final ProductsRepository productsRepository;
  final Function(ProductFilterModel) onApply;

  const ProductFilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.productsRepository,
    required this.onApply,
  });

  @override
  State<ProductFilterBottomSheet> createState() =>
      _ProductFilterBottomSheetState();

  static Future<ProductFilterModel?> show({
    required BuildContext context,
    required ProductFilterModel initialFilter,
    required ProductsRepository productsRepository,
  }) async {
    return await showModalBottomSheet<ProductFilterModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductFilterBottomSheet(
        initialFilter: initialFilter,
        productsRepository: productsRepository,
        onApply: (filter) {
          Navigator.pop(context, filter);
        },
      ),
    );
  }
}

class _ProductFilterBottomSheetState extends State<ProductFilterBottomSheet> {
  late ProductFilterModel _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  Widget _buildFilterChip(
      String label, {
        required bool isSelected,
        required Function(bool) onSelected,
      }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.grey[100],
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      showCheckmark: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primaryDark : Colors.grey[300]!,
          width: 1,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Get price range, brands, and availability statuses
    final priceRange = widget.productsRepository.getPriceRange();
    final brands = widget.productsRepository.getUniqueBrands();
    final availabilityStatuses = widget.productsRepository
        .getAvailabilityStatuses();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter & Sort',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  if (_filter.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filter.clear();
                        });
                      },
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/svg/ic_clear.svg',
                      width: 22.w,
                      height: 22.h,
                      color: Colors.grey[800],
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),

          // Scrollable content
          Expanded(
            child: ListView(
              children: [
                // Sort Options Section
                Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: ProductFilterModel.sortMapping.keys
                      .map(
                        (option) => _buildFilterChip(
                          option,
                          isSelected: _filter.sortOption == option,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _filter.sortOption = option;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 20.h),

                // Price Range Section
                Text(
                  'Price Range',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${(_filter.minPrice ?? priceRange['min']!).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '\$${(_filter.maxPrice ?? priceRange['max']!).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(
                    _filter.minPrice ?? priceRange['min']!,
                    _filter.maxPrice ?? priceRange['max']!,
                  ),
                  min: priceRange['min']!,
                  max: priceRange['max']!,
                  divisions: 50,
                  activeColor: AppColors.primaryLight,
                  inactiveColor: Colors.grey[300],
                  labels: RangeLabels(
                    '\$${(_filter.minPrice ?? priceRange['min']!).toStringAsFixed(0)}',
                    '\$${(_filter.maxPrice ?? priceRange['max']!).toStringAsFixed(0)}',
                  ),
                  onChanged: (RangeValues values) {
                    setState(() {
                      _filter.minPrice = values.start;
                      _filter.maxPrice = values.end;

                      // If price is at min/max, set to null to avoid unnecessary filtering
                      if (_filter.minPrice == priceRange['min']) {
                        _filter.minPrice = null;
                      }
                      if (_filter.maxPrice == priceRange['max']) {
                        _filter.maxPrice = null;
                      }
                    });
                  },
                ),
                SizedBox(height: 20.h),

                // Brand Selection Section
                if (brands.isNotEmpty) ...[
                  Text(
                    'Brand',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: DropdownButton<String>(
                      value: _filter.selectedBrand,
                      hint: Text('Select Brand'),
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(Icons.keyboard_arrow_down),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Brands'),
                        ),
                        ...brands
                            .map(
                              (brand) => DropdownMenuItem<String>(
                                value: brand,
                                child: Text(brand),
                              ),
                            )
                            .toList(),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _filter.selectedBrand = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],

                // Rating Filter
                Text(
                  'Minimum Rating',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  children: [0.0, 1.0, 2.0, 3.0, 4.0, 4.5]
                      .map(
                        (rating) => _buildFilterChip(
                          rating == 0.0 ? 'Any' : '$rating★+',
                          isSelected: _filter.minRating == rating,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _filter.minRating = rating == 0.0
                                    ? null
                                    : rating;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 20.h),

                // Availability Status
                if (availabilityStatuses.isNotEmpty) ...[
                  Text(
                    'Availability',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _buildFilterChip(
                        'Any',
                        isSelected: _filter.availabilityStatus == null,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filter.availabilityStatus = null;
                            });
                          }
                        },
                      ),
                      ...availabilityStatuses
                          .map(
                            (status) => _buildFilterChip(
                              status,
                              isSelected: _filter.availabilityStatus == status,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _filter.availabilityStatus = status;
                                  });
                                }
                              },
                            ),
                          )
                          .toList(),
                    ],
                  ),
                  SizedBox(height: 20.h),
                ],
              ],
            ),
          ),

          // Apply button
          ElevatedButton(
            onPressed: () {
              widget.onApply(_filter);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              minimumSize: Size.fromHeight(50.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Apply',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
