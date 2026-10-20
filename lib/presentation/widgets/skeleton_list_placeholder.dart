import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';

/// Widget hiển thị khung xương (Skeleton Shimmer) thanh lịch,
/// thay thế spinner tròn nhàm chán khi danh sách hoặc dữ liệu đang tải.
class SkeletonListPlaceholder extends StatelessWidget {
  const SkeletonListPlaceholder({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE2E8F0),
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF334155)
            : const Color(0xFFF1F5F9),
        duration: const Duration(milliseconds: 1400),
      ),
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 90,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 60,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 45,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
