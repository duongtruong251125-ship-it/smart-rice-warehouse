import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';

class CuteLoading extends StatelessWidget {
  const CuteLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryLight,
                strokeWidth: 3.5,
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rice_bowl_rounded,
                color: AppTheme.primaryDark,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Đang tải... đợi một xíu xiu nha! 🌾',
          style: TextStyle(
            color: AppTheme.primaryDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
