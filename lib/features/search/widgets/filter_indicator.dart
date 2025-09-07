import 'package:e_commerce_app/features/search/widgets/product_filter_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../common/theme/app_colors.dart';

class FilterIndicator extends StatelessWidget {
  final ProductFilterModel filter;
  final VoidCallback onClearFilters;

  const FilterIndicator({
    super.key,
    required this.filter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (!filter.hasActiveFilters) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16.sp, color: AppColors.primaryDark),
          SizedBox(width: 4.w),
          Text(
            'Filters Applied',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
            ),
          ),
          Spacer(),
          TextButton(
            onPressed: onClearFilters,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.symmetric(horizontal: 8.w),
            ),
            child: Text(
              'Clear All',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
