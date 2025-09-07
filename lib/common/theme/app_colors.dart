import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Light Theme Colors
  static const Color primaryLight = Color(0xFF3F51B5); // Indigo
  static const Color primaryVariantLight = Color(0xFF303F9F); // Darker Indigo
  static const Color secondaryLight = Color(0xFFFF4081); // Pink
  static const Color backgroundLight = Color(0xFFF5F7FA); // Light Gray
  static const Color surfaceLight = Colors.white;
  static const Color errorLight = Color(0xFFB00020); // Red

  static const Color textPrimaryLight = Color(0xFF212121); // Almost Black
  static const Color textSecondaryLight = Color(0xFF757575); // Gray
  static const Color textTertiaryLight = Color(0xFFBDBDBD); // Light Gray

  // Dark Theme Colors
  static const Color primaryDark = Color(0xFF5C6BC0); // Lighter Indigo
  static const Color primaryVariantDark = Color(0xFF3F51B5); // Indigo
  static const Color secondaryDark = Color(0xFFFF80AB); // Lighter Pink
  static const Color backgroundDark = Color(0xFF121212); // Very Dark Gray
  static const Color surfaceDark = Color(0xFF1E1E1E); // Dark Gray
  static const Color errorDark = Color(0xFFCF6679); // Pink-Red

  static const Color textPrimaryDark = Color(0xFFEEEEEE); // Almost White
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Light Gray
  static const Color textTertiaryDark = Color(0xFF757575); // Gray

  // Common Colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color info = Color(0xFF2196F3); // Blue
  static const Color warning = Color(0xFFFFC107); // Amber
  static const Color divider = Color(0xFFE0E0E0); // Light Gray

  // Product Colors
  static const Color discountBadge = Color(0xFFE91E63); // Pink
  static const Color outOfStock = Color(0xFFBDBDBD); // Gray
  static const Color starRating = Color(0xFFFFC107); // Amber

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF3F51B5),
    Color(0xFF5C6BC0),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFFF4081),
    Color(0xFFFF80AB),
  ];
}