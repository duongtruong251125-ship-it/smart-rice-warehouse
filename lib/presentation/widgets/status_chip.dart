import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';

enum StatusBadgeType { safe, warning, danger }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required bool isLowStock})
      : label = isLowStock ? 'Sắp hết' : 'Đủ hàng',
        type = isLowStock ? StatusBadgeType.warning : StatusBadgeType.safe;

  const StatusChip.active({super.key, required bool isActive})
      : label = isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
        type = isActive ? StatusBadgeType.safe : StatusBadgeType.danger;

  const StatusChip.custom({
    super.key,
    required this.label,
    required bool isPositive,
  }) : type = isPositive ? StatusBadgeType.safe : StatusBadgeType.danger;

  const StatusChip.safe({super.key, required this.label})
      : type = StatusBadgeType.safe;

  const StatusChip.warning({super.key, required this.label})
      : type = StatusBadgeType.warning;

  const StatusChip.danger({super.key, required this.label})
      : type = StatusBadgeType.danger;

  final String label;
  final StatusBadgeType type;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final Color borderColor;

    switch (type) {
      case StatusBadgeType.safe:
        bgColor = AppTheme.safeBgColor(context);
        textColor = AppTheme.safeTextColor(context);
        borderColor = AppTheme.safeBorderColor(context);
      case StatusBadgeType.warning:
        bgColor = AppTheme.warningBgColor(context);
        textColor = AppTheme.warningTextColor(context);
        borderColor = AppTheme.warningBorderColor(context);
      case StatusBadgeType.danger:
        bgColor = AppTheme.dangerBgColor(context);
        textColor = AppTheme.dangerTextColor(context);
        borderColor = AppTheme.dangerBorderColor(context);
    }

    return Semantics(
      label: 'Trạng thái: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
