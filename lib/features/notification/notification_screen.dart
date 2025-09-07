import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../core/config/routes/route_name.dart';

// Notification model
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final int? productId;
  final String? thumbnail;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.productId,
    this.thumbnail,
    this.isRead = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen> {
  // Dummy notifications
  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: '1',
      title: 'New Arrival!',
      message: 'Check out the latest product in our store.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      productId: 1,
      thumbnail: 'https://dummyjson.com/image/i/products/1/thumbnail.jpg',
    ),
    NotificationModel(
      id: '2',
      title: 'Flash Sale Alert',
      message: '50% off on selected products. Hurry, limited stock!',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      productId: 2,
      thumbnail: 'https://dummyjson.com/image/i/products/2/thumbnail.jpg',
    ),
    NotificationModel(
      id: '3',
      title: 'Order Shipped',
      message: 'Your order #12345 has been shipped.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NotificationModel(
      id: '4',
      title: 'New Collection',
      message: 'Explore our new summer clothing collection.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      productId: 3,
      thumbnail: 'https://dummyjson.com/image/i/products/3/thumbnail.jpg',
    ),
  ];

  // Check if all notifications are read
  bool get _allNotificationsRead => _notifications.every((notification) => notification.isRead);

  // Format relative time
  String _getRelativeTime(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  void _navigateToProductDetail(int productId) {
    // Debug print to verify the product ID
    debugPrint('Navigating to product detail with ID: $productId');

    Navigator.pushNamed(
      context,
      RoutesName.productDetailScreen,
      arguments: productId,
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  // Get icon for notification based on content
  String _getNotificationIcon(NotificationModel notification) {
    // Use different icons based on notification content
    if (notification.title.contains('Order')) {
      return 'assets/icons/svg/ic_shipped.svg';
    } else if (notification.title.contains('Sale') || notification.message.contains('off')) {
      return 'assets/icons/svg/ic_discount.svg';
    } else if (notification.title.contains('Arrival') || notification.title.contains('Collection')) {
      return 'assets/icons/svg/ic_new.svg';
    } else {
      return 'assets/icons/svg/ic_notification.svg'; // Default icon
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        // Custom back button to ensure it's black
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppColors.surfaceLight,
        elevation: 0.5,
        shadowColor: AppColors.divider.withOpacity(0.3),
        actions: [
          if (_notifications.isNotEmpty && !_allNotificationsRead)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all as read',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 14.sp,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const _EmptyState()
          : ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final bool hasProduct = notification.productId != null;
    final String iconPath = _getNotificationIcon(notification);

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () {
          if (notification.productId != null) {
            _navigateToProductDetail(notification.productId!);
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left dot indicator for unread notifications
                if (!notification.isRead)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h, right: 8.w),
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // SVG Icon instead of thumbnail
                Container(
                  width: 70.w,
                  height: 70.h,
                  decoration: BoxDecoration(
                    color: hasProduct
                        ? AppColors.primaryLight.withOpacity(0.1)
                        : AppColors.secondaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconPath,
                      width: 32.w,
                      height: 32.h,
                      color: hasProduct
                          ? AppColors.primaryLight
                          : AppColors.secondaryLight,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),

                // Notification Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasProduct)
                            Container(
                              width: 28.w,
                              height: 28.h,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14.sp,
                                color: AppColors.primaryLight,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondaryLight,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14.sp,
                            color: AppColors.textTertiaryLight,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            _getRelativeTime(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced empty state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/svg/ic_notification.svg',
                width: 60.w,
                height: 60.h,
                color: AppColors.primaryLight.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No Notifications Yet',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              'We\'ll notify you when something important happens, like price drops or new arrivals.',
              style: TextStyle(
                fontSize: 15.sp,
                color: AppColors.textSecondaryLight,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.r),
              ),
            ),
            child: Text(
              'Explore Products',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}