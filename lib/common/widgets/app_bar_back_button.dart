import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBarBackButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onPressed;

  const AppBarBackButton({super.key, this.color, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: Colors.black,
      icon: Icon(
        Icons.arrow_back_ios_rounded,
        size: 20,
        color: AppColors.backgroundLight,
      ),
      onPressed:
          onPressed ??
          () {
            Navigator.of(context).pop();
          },
    );
  }
}
