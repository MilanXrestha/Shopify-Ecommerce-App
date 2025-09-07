import 'package:flutter/material.dart';

import '../../features/debug/presentation/screens/debug_panel_screen.dart';
import '../theme/app_colors.dart';

class DebugPanelButton extends StatelessWidget {
  const DebugPanelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: AppColors.primaryLight.withOpacity(0.8),
      child: const Icon(Icons.bug_report, color: Colors.white),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DebugPanelScreen()),
        );
      },
    );
  }
}
