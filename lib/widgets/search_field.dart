import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  splashRadius: 18,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh Filter Chips ngang trực quan phong cách hiện đại
class HorizontalFilterBar<T> extends StatelessWidget {
  const HorizontalFilterBar({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.labelBuilder,
    this.badgeCountBuilder,
  });

  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;
  final String Function(T item) labelBuilder;
  final int? Function(T item)? badgeCountBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          final count = badgeCountBuilder?.call(item);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelBuilder(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    if (count != null && count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
