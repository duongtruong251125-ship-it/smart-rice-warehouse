import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';

/// Thanh công cụ ghim cố định ở đáy màn hình Form (Bottom Sticky Action Bar)
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.secondaryIcon,
    this.summaryWidget,
    this.primaryColor,
  });

  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final IconData? secondaryIcon;
  final Widget? summaryWidget;
  final Color? primaryColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = primaryColor ?? AppTheme.primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(
          top: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (summaryWidget != null) ...[
            summaryWidget!,
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (secondaryLabel != null && onSecondaryPressed != null) ...[
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: onSecondaryPressed,
                    icon: secondaryIcon != null
                        ? Icon(secondaryIcon, size: 18)
                        : const SizedBox.shrink(),
                    label: Text(
                      secondaryLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: effectiveColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    elevation: 0,
                  ),
                  onPressed: onPrimaryPressed,
                  icon: primaryIcon != null
                      ? Icon(primaryIcon, size: 19)
                      : const SizedBox.shrink(),
                  label: Text(
                    primaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
