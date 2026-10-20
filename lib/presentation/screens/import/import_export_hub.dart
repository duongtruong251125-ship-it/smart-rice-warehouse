import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/pressable_scale.dart';

class ImportExportHub extends StatelessWidget {
  const ImportExportHub({super.key});

  @override
  Widget build(BuildContext context) {
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final recentEntries = _buildRecentEntries(importProvider, exportProvider);

    final totalImportKg =
        importProvider.receipts.fold<double>(0.0, (s, r) => s + r.quantity);
    final totalExportKg =
        exportProvider.receipts.fold<double>(0.0, (s, r) => s + r.quantity);
    final totalImportTons = totalImportKg / 1000.0;
    final totalExportTons = totalExportKg / 1000.0;

    final isLoading = importProvider.isLoading || exportProvider.isLoading;
    final errorMessage =
        importProvider.errorMessage ?? exportProvider.errorMessage;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget maybeFadeIn(Widget child, Duration duration) {
      if (disableAnimations) return child;
      return child.animate().fadeIn(duration: duration);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (isLoading || (errorMessage != null && errorMessage.isNotEmpty)) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AsyncStatusBanner(
              isLoading: isLoading,
              errorMessage: errorMessage,
              onRetry: () {
                importProvider.retrySync();
                exportProvider.retrySync();
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // --- TẦNG 1: HERO BANNER EMERALD GRADIENT ---
        maybeFadeIn(
          _ImportExportHeroBanner(
            importCount: importProvider.receipts.length,
            exportCount: exportProvider.receipts.length,
            onAddImport: () =>
                Navigator.of(context).pushNamed(AppRoutes.addImport),
            onAddExport: () =>
                Navigator.of(context).pushNamed(AppRoutes.addExport),
          ),
          250.ms,
        ),

        const SizedBox(height: 18),

        // --- TẦNG 2: THẺ TỔNG LƯỢNG GIAO DỊCH ĐỐI XỨNG ---
        maybeFadeIn(
          _TransactionOverviewCard(
            totalImportTons: totalImportTons,
            totalExportTons: totalExportTons,
            importCount: importProvider.receipts.length,
            exportCount: exportProvider.receipts.length,
            onViewImport: () =>
                Navigator.of(context).pushNamed(AppRoutes.import),
            onViewExport: () =>
                Navigator.of(context).pushNamed(AppRoutes.export),
          ),
          300.ms,
        ),

        const SizedBox(height: 14),

        // --- TÍNH NĂNG OCR CÂN XE / HÓA ĐƠN ---
        maybeFadeIn(
          _OcrQuickBanner(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.ocrInvoice),
          ),
          300.ms,
        ),

        const SizedBox(height: 20),

        // --- TẦNG 3: SỔ GIAO DỊCH KHO GẠO ---
        Text(
          'Sổ giao dịch Kho gạo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Sổ Phiếu Nhập kho',
          badgeText: '${importProvider.receipts.length} phiếu',
          badgeColor: AppTheme.primaryColor,
          icon: Icons.south_west_rounded,
          iconBgColor: AppTheme.primaryLight,
          iconColor: AppTheme.primaryColor,
          route: AppRoutes.import,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Sổ Phiếu Xuất kho',
          badgeText: '${exportProvider.receipts.length} phiếu',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.north_east_rounded,
          iconBgColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          route: AppRoutes.export,
        ),

        // --- TẦNG 4: BIẾN ĐỘNG GẦN ĐÂY ---
        if (recentEntries.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'Biến động Giao nhận Gần đây',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final entry in recentEntries) ...[
                _RecentTransactionCard(entry: entry),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 1: HERO BANNER NHẬP / XUẤT (ĐỒNG BỘ MÀU EMERALD GRADIENT)
/// -----------------------------------------------------------------------
class _ImportExportHeroBanner extends StatelessWidget {
  const _ImportExportHeroBanner({
    required this.importCount,
    required this.exportCount,
    required this.onAddImport,
    required this.onAddExport,
  });

  final int importCount;
  final int exportCount;
  final VoidCallback onAddImport;
  final VoidCallback onAddExport;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.modernElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ĐIỀU ĐỘ NHẬP & XUẤT KHO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quy trình Cân xe, Bốc dỡ & Giao nhận',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniChip('$importCount Phiếu Nhập'),
              _buildMiniChip('$exportCount Phiếu Xuất'),
              _buildMiniChip('OCR Smart Scan'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BannerButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Tạo phiếu nhập',
                  onTap: onAddImport,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BannerButton(
                  icon: Icons.outbox_rounded,
                  label: 'Tạo phiếu xuất',
                  onTap: onAddExport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return PressableScale(
      semanticLabel: label,
      onTap: onTap,
      scaleFactor: 0.95,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isDark ? const Color(0xFF34D399) : AppTheme.primaryDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? const Color(0xFF34D399) : AppTheme.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 2: THẺ TỔNG LƯỢNG GIAO DỊCH ĐỐI XỨNG (CARD ĐỒNG BỘ)
/// -----------------------------------------------------------------------
class _TransactionOverviewCard extends StatelessWidget {
  const _TransactionOverviewCard({
    required this.totalImportTons,
    required this.totalExportTons,
    required this.importCount,
    required this.exportCount,
    required this.onViewImport,
    required this.onViewExport,
  });

  final double totalImportTons;
  final double totalExportTons;
  final int importCount;
  final int exportCount;
  final VoidCallback onViewImport;
  final VoidCallback onViewExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Khối Tổng Nhập
        Expanded(
          child: InkWell(
            onTap: onViewImport,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border(context)),
                boxShadow: AppTheme.isDark(context)
                    ? AppTheme.darkCardShadow
                    : AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.safeBgColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.south_west_rounded,
                          color: AppTheme.safeTextColor(context),
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textSecondaryColor(context)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tổng Nhập kho',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context)),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+${totalImportTons.toStringAsFixed(1)} Tấn',
                      style: AppTheme.tabularFigures(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.safeTextColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$importCount phiếu nhập',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Khối Tổng Xuất
        Expanded(
          child: InkWell(
            onTap: onViewExport,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border(context)),
                boxShadow: AppTheme.isDark(context)
                    ? AppTheme.darkCardShadow
                    : AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.warningBgColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.north_east_rounded,
                          color: AppTheme.warningTextColor(context),
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textSecondaryColor(context)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tổng Xuất kho',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context)),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '-${totalExportTons.toStringAsFixed(1)} Tấn',
                      style: AppTheme.tabularFigures(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.warningTextColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$exportCount phiếu xuất',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 3: BANNER TIỆN ÍCH QUÉT OCR
/// -----------------------------------------------------------------------
class _OcrQuickBanner extends StatelessWidget {
  const _OcrQuickBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return PressableScale(
      semanticLabel: 'Nhập kho bằng OCR Hóa đơn hoặc Cân xe',
      onTap: onTap,
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
          boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.safeBgColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                color: AppTheme.safeTextColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập kho bằng OCR Hóa đơn / Cân xe',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.safeTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quét phiếu cân tự động điền số lượng',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 4: CARD CHỨC NĂNG DÙNG CHUNG
/// -----------------------------------------------------------------------
class _HubItemCard extends StatelessWidget {
  const _HubItemCard({
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.route,
  });

  final String title;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return PressableScale(
      semanticLabel: '$title, $badgeText',
      onTap: () => Navigator.of(context).pushNamed(route),
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 5: CARD BIẾN ĐỘNG GẦN ĐÂY
/// -----------------------------------------------------------------------
class _RecentTransactionCard extends StatelessWidget {
  const _RecentTransactionCard({required this.entry});

  final _RecentEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final color = entry.isImport
        ? AppTheme.safeTextColor(context)
        : AppTheme.warningTextColor(context);
    final bgColor = entry.isImport
        ? AppTheme.safeBgColor(context)
        : AppTheme.warningBgColor(context);
    final bags = (entry.quantity / 50).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.isImport
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.riceName,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.code} • ${DateFormatter.ddMMyyyy(entry.date)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.isImport ? "+" : "-"}${NumberFormatter.quantity(entry.quantity)} kg',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.tabularFigures(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '~$bags bao • ${CurrencyFormatter.formatVnd(entry.totalAmount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// DATA MODEL & HELPER
/// -----------------------------------------------------------------------
class _RecentEntry {
  const _RecentEntry({
    required this.code,
    required this.riceName,
    required this.partnerName,
    required this.date,
    required this.quantity,
    required this.totalAmount,
    required this.isImport,
  });

  final String code;
  final String riceName;
  final String partnerName;
  final DateTime date;
  final double quantity;
  final double totalAmount;
  final bool isImport;
}

List<_RecentEntry> _buildRecentEntries(
  ImportProvider importProvider,
  ExportProvider exportProvider,
) {
  final list = <_RecentEntry>[
    for (final r in importProvider.receipts)
      _RecentEntry(
        code: r.code,
        riceName: r.riceName,
        partnerName: r.supplierName,
        date: r.date,
        quantity: r.quantity,
        totalAmount: r.totalAmount,
        isImport: true,
      ),
    for (final r in exportProvider.receipts)
      _RecentEntry(
        code: r.code,
        riceName: r.riceName,
        partnerName: r.customerName,
        date: r.date,
        quantity: r.quantity,
        totalAmount: r.totalAmount,
        isImport: false,
      ),
  ];
  list.sort((a, b) => b.date.compareTo(a.date));
  return list.take(5).toList();
}
