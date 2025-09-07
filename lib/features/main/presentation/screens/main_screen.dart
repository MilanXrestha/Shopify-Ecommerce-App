import 'package:e_commerce_app/common/theme/app_colors.dart';
import 'package:e_commerce_app/features/wishlist/presentation/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../../common/widgets/debug_panel_button.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Callback to change tab index
  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Initialize screens with callback for CartScreen
  late final List<Widget> _screens = [
    const HomeScreen(),
    const ProductsScreen(),
    CartScreen(onNavigateToProducts: () => _changeTab(1)),
    WishlistScreen(onNavigateToProducts: () => _changeTab(1)),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Show exit confirmation dialog
  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      // If not on home screen, go to home screen
      setState(() {
        _currentIndex = 0;
      });
      return false;
    } else {
      // If on home screen, show exit confirmation dialog
      return await _showExitConfirmationDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _screens),
            Positioned(right: 16, bottom: 20, child: DebugPanelButton()),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            selectedItemColor: AppColors.primaryLight,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/icons/svg/ic_home_outline.svg',
                  width: 24,
                  height: 24,
                  color: Colors.grey,
                ),
                activeIcon: SvgPicture.asset(
                  'assets/icons/svg/ic_home_filled.svg',
                  width: 24,
                  height: 24,
                  color: AppColors.primaryLight,
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/icons/svg/ic_product_outline.svg',
                  width: 24,
                  height: 24,
                  color: Colors.grey,
                ),
                activeIcon: SvgPicture.asset(
                  'assets/icons/svg/ic_product_filled.svg',
                  width: 24,
                  height: 24,
                  color: AppColors.primaryLight,
                ),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/icons/svg/ic_cart.svg',
                  width: 24,
                  height: 24,
                  color: Colors.grey,
                ),
                activeIcon: SvgPicture.asset(
                  'assets/icons/svg/ic_cart_filled.svg',
                  width: 24,
                  height: 24,
                  color: AppColors.primaryLight,
                ),
                label: 'Cart',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/icons/svg/ic_wishlist.svg',
                  width: 24,
                  height: 24,
                  color: Colors.grey,
                ),
                activeIcon: SvgPicture.asset(
                  'assets/icons/svg/ic_wishlist_filled.svg',
                  width: 24,
                  height: 24,
                  color: AppColors.primaryLight,
                ),
                label: 'Wishlist',
              ),
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  'assets/icons/svg/ic_profile.svg',
                  width: 24,
                  height: 24,
                  color: Colors.grey,
                ),
                activeIcon: SvgPicture.asset(
                  'assets/icons/svg/ic_profile_filled.svg',
                  width: 24,
                  height: 24,
                  color: AppColors.primaryLight,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}