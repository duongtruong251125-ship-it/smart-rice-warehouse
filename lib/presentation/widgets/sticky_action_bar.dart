import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';

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
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final IconData? secondaryIcon;
  final Widget? summaryWidget;
  final Color? primaryColor;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = primaryColor ?? AppTheme.primaryColor;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hasSecondary = secondaryLabel != null && onSecondaryPressed != null;
    final stackVertically =
        hasSecondary && (screenWidth < 340 || textScale >= 1.6);
    final trimmedError = errorMessage?.trim();

    Widget buildSecondaryButton() {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onPressed: isLoading ? null : onSecondaryPressed,
        icon: secondaryIcon != null
            ? Icon(secondaryIcon, size: 18)
            : const SizedBox.shrink(),
        label: Text(
          secondaryLabel!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    Widget buildPrimaryButton() {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPrimaryPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : (primaryIcon != null
                ? Icon(primaryIcon, size: 19)
                : const SizedBox.shrink()),
        label: Text(
          isLoading ? 'Đang xử lý...' : primaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 1),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trimmedError != null && trimmedError.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.dangerBgColor(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.dangerBorderColor(context)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppTheme.dangerTextColor(context),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          trimmedError,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.dangerTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onRetry != null && !isLoading)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.dangerTextColor(context),
                        minimumSize: const Size(64, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Thử lại',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (summaryWidget != null) ...[
            summaryWidget!,
            const SizedBox(height: 10),
          ],
          if (stackVertically) ...[
            buildPrimaryButton(),
            const SizedBox(height: 8),
            buildSecondaryButton(),
          ] else
            Row(
              children: [
                if (hasSecondary) ...[
                  Expanded(
                    flex: 2,
                    child: buildSecondaryButton(),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: buildPrimaryButton(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
