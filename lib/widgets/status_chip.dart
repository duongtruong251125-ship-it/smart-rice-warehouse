import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required bool isLowStock})
      : label = isLowStock ? 'Sắp hết' : 'Bình thường',
        isPositive = !isLowStock;

  const StatusChip.active({super.key, required bool isActive})
      : label = isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
        isPositive = isActive;

  const StatusChip.custom({
    super.key,
    required this.label,
    required this.isPositive,
  });

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isPositive
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final foregroundColor = isPositive
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: foregroundColor.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foregroundColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

