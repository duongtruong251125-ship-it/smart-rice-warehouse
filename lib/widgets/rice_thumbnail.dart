import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/widgets/pressable_scale.dart';

/// Widget hiển thị ảnh giống gạo (Thumbnail) kèm tính năng chạm phóng to xem chi tiết
class RiceThumbnail extends StatelessWidget {
  const RiceThumbnail({
    super.key,
    this.rice,
    this.imagePath,
    this.name,
    this.code,
    this.category,
    this.size = 48,
    this.borderRadius = 12,
    this.enablePreview = true,
  });

  final RiceModel? rice;
  final String? imagePath;
  final String? name;
  final String? code;
  final String? category;
  final double size;
  final double borderRadius;
  final bool enablePreview;

  String? get _effectiveImagePath => imagePath ?? rice?.imagePath;
  String get _effectiveName => name ?? rice?.name ?? 'Giống gạo';
  String get _effectiveCode => code ?? rice?.code ?? '';
  String get _effectiveCategory => category ?? rice?.category ?? '';

  bool get _hasValidImage {
    final path = _effectiveImagePath;
    if (path == null || path.trim().isEmpty) return false;
    if (path.startsWith('assets/')) return true;
    final file = File(path);
    return file.existsSync();
  }

  ImageProvider<Object> get _imageProvider {
    final path = _effectiveImagePath!;
    return path.startsWith('assets/')
        ? AssetImage(path)
        : FileImage(File(path));
  }

  void _showImagePreview(BuildContext context) {
    if (!_hasValidImage) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh nút đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Card chi tiết ảnh gạo
            Container(
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hình ảnh chính phóng to
                    Flexible(
                      child: InteractiveViewer(
                        maxScale: 3.5,
                        child: Image(
                          image: _imageProvider,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  size: 48, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Banner thông tin giống gạo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.4)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _effectiveName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_effectiveCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _effectiveCode,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_effectiveCategory.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.grain_rounded,
                                    size: 14, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _effectiveCategory,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = _hasValidImage;

    Widget content;
    if (hasImage) {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          image: DecorationImage(
            image: _imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Fallback placeholder hạt gạo & icon bát gạo thanh lịch
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.rice_bowl_rounded,
            color: colorScheme.primary,
            size: size * 0.52,
          ),
        ),
      );
    }

    if (hasImage && enablePreview) {
      return PressableScale(
        onTap: () => _showImagePreview(context),
        child: content,
      );
    }

    return content;
  }
}
