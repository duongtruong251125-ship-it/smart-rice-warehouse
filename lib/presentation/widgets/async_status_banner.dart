import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.status,
    this.onRetry,
    this.onHeroSurface = true,
  });

  final WarehouseSyncStatus status;
  final VoidCallback? onRetry;
  final bool onHeroSurface;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color dotColor,
      Color bgColor,
      Color borderColor,
      Color textColor
    ) = _resolveVisuals(context);

    final badgeContent = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isSyncing &&
              !(MediaQuery.maybeDisableAnimationsOf(context) ?? false))
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: dotColor,
              ),
            )
          else
            Icon(icon, size: 14, color: dotColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (status.hasError && onRetry != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.refresh_rounded, size: 14, color: textColor),
          ],
        ],
      ),
    );

    if (status.hasError && onRetry != null) {
      return Semantics(
        button: true,
        label: '${status.semanticDescription}. Nhấn để thử lại.',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onRetry,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              widthFactor: 1,
              alignment: Alignment.center,
              child: badgeContent,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: status.semanticDescription,
      child: badgeContent,
    );
  }

  (IconData, Color, Color, Color, Color) _resolveVisuals(BuildContext context) {
    if (onHeroSurface) {
      switch (status.state) {
        case WarehouseSyncState.synced:
          return (
            Icons.cloud_done_rounded,
            const Color(0xFF6EE7B7),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.28),
            Colors.white,
          );
        case WarehouseSyncState.syncing:
          return (
            Icons.sync_rounded,
            const Color(0xFF93C5FD),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.28),
            Colors.white,
          );
        case WarehouseSyncState.local:
          return (
            Icons.storage_rounded,
            const Color(0xFFFDE68A),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.28),
            Colors.white,
          );
        case WarehouseSyncState.error:
          return (
            Icons.error_outline_rounded,
            const Color(0xFFFCA5A5),
            const Color(0xFF7F1D1D).withValues(alpha: 0.72),
            const Color(0xFFFCA5A5).withValues(alpha: 0.65),
            Colors.white,
          );
        case WarehouseSyncState.unknown:
          return (
            Icons.help_outline_rounded,
            Colors.white70,
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.24),
            Colors.white,
          );
      }
    }

    switch (status.state) {
      case WarehouseSyncState.synced:
        return (
          Icons.cloud_done_rounded,
          AppTheme.safeTextColor(context),
          AppTheme.safeBgColor(context),
          AppTheme.safeBorderColor(context),
          AppTheme.safeTextColor(context),
        );
      case WarehouseSyncState.syncing:
        return (
          Icons.sync_rounded,
          AppTheme.infoTextColor(context),
          AppTheme.infoBgColor(context),
          AppTheme.infoTextColor(context).withValues(alpha: 0.35),
          AppTheme.infoTextColor(context),
        );
      case WarehouseSyncState.local:
        return (
          Icons.storage_rounded,
          AppTheme.warningTextColor(context),
          AppTheme.warningBgColor(context),
          AppTheme.warningBorderColor(context),
          AppTheme.warningTextColor(context),
        );
      case WarehouseSyncState.error:
        return (
          Icons.error_outline_rounded,
          AppTheme.dangerTextColor(context),
          AppTheme.dangerBgColor(context),
          AppTheme.dangerBorderColor(context),
          AppTheme.dangerTextColor(context),
        );
      case WarehouseSyncState.unknown:
        return (
          Icons.help_outline_rounded,
          AppTheme.textSecondaryColor(context),
          AppTheme.cardBg(context),
          AppTheme.border(context),
          AppTheme.textSecondaryColor(context),
        );
    }
  }
}

class AsyncStatusBanner extends StatelessWidget {
  const AsyncStatusBanner({
    super.key,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.loadingLabel = 'Đang đồng bộ dữ liệu...',
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final trimmedError = errorMessage?.trim();
    final hasError = trimmedError != null && trimmedError.isNotEmpty;

    if (!isLoading && !hasError) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          Semantics(
            label: loadingLabel,
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.infoBgColor(context),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.infoTextColor(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loadingLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.infoTextColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasError)
          Semantics(
            liveRegion: true,
            label: 'Lỗi: $trimmedError',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.dangerBgColor(context),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.dangerBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppTheme.dangerTextColor(context),
                      ),
                      const SizedBox(width: 8),
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
                  if (onRetry != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerTextColor(context),
                        side: BorderSide(
                          color: AppTheme.dangerBorderColor(context),
                        ),
                        minimumSize: const Size(88, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
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
          ),
      ],
    );
  }
}
