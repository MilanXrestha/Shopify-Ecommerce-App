import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/error_display.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/config/routes/route_name.dart';
import '../../data/repositories/cart_repository.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> cartSummary; // Passed from CartScreen

  const CheckoutScreen({super.key, required this.cartSummary});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Logger _logger = Logger();
  late CartRepository _cartRepository;
  bool _isLoading = false;
  String? _error;
  String _selectedPaymentMethod = 'Cash on Delivery'; // Default for Nepal

  // Form key and controllers for shipping address
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedProvince = 'Bagmati Province'; // Default province

  // Nepal provinces
  final List<String> _nepalProvinces = [
    'Koshi Province',
    'Madhesh Province',
    'Bagmati Province',
    'Gandaki Province',
    'Lumbini Province',
    'Karnali Province',
    'Sudurpashchim Province',
  ];

  // Nepal-specific payment methods
  final List<String> _nepalPaymentMethods = [
    'Cash on Delivery',
    'Khalti',
    'eSewa',
    'Fonepay',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appScope = AppScope.of(context);
    _cartRepository = appScope.cartRepository;

    // Set payment method from cart summary if available
    if (widget.cartSummary.containsKey('paymentMethods')) {
      final paymentMethods = widget.cartSummary['paymentMethods'] as List<dynamic>;
      for (final method in paymentMethods) {
        if (method['isDefault'] == true) {
          _selectedPaymentMethod = method['name'];
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Simulate API call for placing order
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Simulate network delay

      // Clear cart after successful order
      await _cartRepository.clearCart();

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Order Placed'),
            content: const Text('Your order has been successfully placed!'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    RoutesName.mainScreen,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                ),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _logger.e('Error placing order: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Material(
          color: Colors.white,
          elevation: 1,
          child: AppBar(
            title: const Text(
              'Checkout',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorDisplay(error: _error!, onRetry: _placeOrder)
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            _buildOrderSummary(),

            SizedBox(height: 24.h),

            // Shipping Address
            _buildShippingAddressForm(),

            SizedBox(height: 24.h),

            // Payment Method
            _buildPaymentMethodSelection(),

            SizedBox(height: 24.h),

            // Place Order Button
            ElevatedButton(
              onPressed: _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                minimumSize: Size.fromHeight(50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Place Order',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final summary = widget.cartSummary;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          _buildSummaryRow('Subtotal', summary['subtotal']),
          if (summary['discount'] > 0)
            _buildSummaryRow('Discount', -summary['discount'], isDiscount: true),
          _buildSummaryRow('Shipping', summary['shipping']),
          _buildSummaryRow('Tax', summary['tax']),
          Divider(height: 24.h, color: Colors.grey[300]),
          _buildSummaryRow('Total', summary['total'], isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      String label,
      double amount, {
        bool isDiscount = false,
        bool isTotal = false,
      }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? AppColors.primaryDark : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddressForm() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shipping Address',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Street Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              value: _selectedProvince,
              decoration: InputDecoration(
                labelText: 'Province',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              items: _nepalProvinces.map((province) {
                return DropdownMenuItem<String>(
                  value: province,
                  child: Text(province),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value!;
                });
              },
              validator: (value) => value == null ? 'Required' : null,
            ),
            SizedBox(height: 12.h),
            // Display Nepal as the country (non-editable)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 15.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8.r),
                color: Colors.grey[100],
              ),
              child: Row(
                children: [
                  Text(
                    'Country: ',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Nepal',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),

          // Radio buttons for payment methods
          ...List.generate(_nepalPaymentMethods.length, (index) {
            final method = _nepalPaymentMethods[index];
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  method,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: _selectedPaymentMethod == method
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                leading: Radio<String>(
                  value: method,
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                    });
                  },
                  activeColor: AppColors.primaryLight,
                ),
                dense: true,
                // Add payment method icons if you have them
                trailing: _getPaymentMethodIcon(method),
              ),
            );
          }),

          // Show additional info for Cash on Delivery
          if (_selectedPaymentMethod == 'Cash on Delivery')
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20.sp, color: Colors.blue[700]),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Pay with cash upon delivery. Our delivery partner will collect the payment.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to return payment method icons
  Widget? _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'Cash on Delivery':
        return Image.asset(
          'assets/icons/png/ic_cod.png',
          width: 50.w,
          height: 24.h,
          fit: BoxFit.contain,
        );
      case 'Khalti':
        return Image.asset(
          'assets/icons/png/ic_khalti.png',
          width: 50.w,
          height: 40.h,
          fit: BoxFit.contain,
        );
      case 'eSewa':
        return Image.asset(
          'assets/icons/png/ic_esewa.png',
          width: 50.w,
          height: 30.h,
          fit: BoxFit.contain,
        );

      case 'Fonepay':
        return Image.asset(
          'assets/icons/png/ic_fonepay.png',
          width: 45.w,
          height: 24.h,
          fit: BoxFit.contain,
        );
      default:
        return null;
    }
  }

}