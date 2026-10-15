import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/widgets/pressable_scale.dart';

/// =======================================================================
/// TAB 3: HUB NHẬP / XUẤT KHO (IMPORT / EXPORT HUB)
/// Đồng bộ 100% với layout của HomeTab và WarehouseHub:
/// - Hero Banner Emerald Gradient với phím tắt Tạo phiếu Nhập/Xuất.
/// - Khối Thống kê Tổng lượng Giao dịch đối xứng.
/// - Nút Scan OCR Hóa đơn / Cân xe thông minh.
/// - Sổ giao dịch và Danh sách Biến động gần đây.
/// =======================================================================
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // --- TẦNG 1: HERO BANNER EMERALD GRADIENT ---
        _ImportExportHeroBanner(
          importCount: importProvider.receipts.length,
          exportCount: exportProvider.receipts.length,
          onAddImport: () =>
              Navigator.of(context).pushNamed(AppRoutes.addImport),
          onAddExport: () =>
              Navigator.of(context).pushNamed(AppRoutes.addExport),
        ).animate().fadeIn(duration: 250.ms),

        const SizedBox(height: 18),

        // --- TẦNG 2: THẺ TỔNG LƯỢNG GIAO DỊCH ĐỐI XỨNG ---
        _TransactionOverviewCard(
          totalImportTons: totalImportTons,
          totalExportTons: totalExportTons,
          importCount: importProvider.receipts.length,
          exportCount: exportProvider.receipts.length,
          onViewImport: () => Navigator.of(context).pushNamed(AppRoutes.import),
          onViewExport: () => Navigator.of(context).pushNamed(AppRoutes.export),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 14),

        // --- TÍNH NĂNG OCR CÂN XE / HÓA ĐƠN ---
        _OcrQuickBanner(
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.ocrInvoice),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 20),

        // --- TẦNG 3: SỔ GIAO DỊCH KHO GẠO ---
        const Text(
          'Sổ giao dịch Kho gạo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Sổ Phiếu Nhập kho',
          subtitle: 'Danh sách biên bản thu mua, nhập lúa gạo',
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
          subtitle: 'Danh sách phiếu xuất bán đại lý, đối tác',
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
          const Text(
            'Biến động Giao nhận Gần đây',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroEmeraldGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.modernElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ĐIỀU ĐỘ NHẬP & XUẤT KHO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Giao nhận',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quy trình Cân xe, Bốc dỡ & Giao nhận',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
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
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.95,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryDark),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
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
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.south_west_rounded,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tổng Nhập kho',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
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
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$importCount phiếu nhập',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
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
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.north_east_rounded,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tổng Xuất kho',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
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
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$exportCount phiếu xuất',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
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
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập kho bằng OCR Hóa đơn / Cân xe',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Quét phiếu cân tự động điền số lượng',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
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
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context).pushNamed(route),
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textSecondary,
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
    final color =
        entry.isImport ? AppTheme.primaryColor : const Color(0xFFD97706);
    final bgColor =
        entry.isImport ? AppTheme.primaryLight : const Color(0xFFFEF3C7);
    final bags = (entry.quantity / 50).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.code} • ${DateFormatter.ddMMyyyy(entry.date)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.isImport ? "+" : "-"}${NumberFormatter.quantity(entry.quantity)} kg',
                style: AppTheme.tabularFigures(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '~$bags bao • ${CurrencyFormatter.formatVnd(entry.totalAmount)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
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
