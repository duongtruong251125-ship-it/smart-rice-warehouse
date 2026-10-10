import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/widgets/dashboard_card.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';

/// Màn hình Hub Nhập / Xuất - Tái cấu trúc theo phong cách "AgriWarehouse Modern System"
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // --- 1. TỔNG QUAN PHIẾU KHO (BENTO METRIC CARDS) ---
        const SectionTitle('Tổng quan Hoạt động Nhập / Xuất'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: BentoMetricCard(
                title: 'Tổng Nhập kho',
                amountText: '+${totalImportTons.toStringAsFixed(1)} Tấn',
                countText: '${importProvider.receipts.length} phiếu',
                icon: Icons.south_west_rounded,
                accentColor: AppTheme.accentGreen,
                isPositive: true,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.import),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BentoMetricCard(
                title: 'Tổng Xuất kho',
                amountText: '-${totalExportTons.toStringAsFixed(1)} Tấn',
                countText: '${exportProvider.receipts.length} phiếu',
                icon: Icons.north_east_rounded,
                accentColor: AppTheme.secondaryColor,
                isPositive: false,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.export),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // --- 2. THAO TÁC TẠO PHIẾU NHANH ---
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.addImport),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text(
                    'Tạo phiếu nhập',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.addExport),
                  icon: const Icon(Icons.outbox_rounded, size: 18),
                  label: const Text(
                    'Tạo phiếu xuất',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Quick OCR Scan Button
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.ocrPrototype),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.document_scanner_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Nhập kho bằng OCR Hóa đơn / Cân xe',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI Smart',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // --- 3. SỔ GIAO DỊCH NHẬP / XUẤT KHO ---
        const SectionTitle('Sổ giao dịch Kho gạo'),
        const SizedBox(height: 10),
        _ModernTransactionCard(
          title: 'Sổ Phiếu Nhập kho',
          subtitle:
              'Quản lý lịch sử nhập, thông số ẩm độ, tạp chất & cân xe tải',
          badgeText: '${importProvider.receipts.length} phiếu',
          badgeColor: AppTheme.accentGreen,
          icon: Icons.download_rounded,
          accentColor: AppTheme.accentGreen,
          route: AppRoutes.import,
        ),
        const SizedBox(height: 10),
        _ModernTransactionCard(
          title: 'Sổ Phiếu Xuất kho',
          subtitle: 'Lịch sử phân bổ FEFO hạn dùng & giao bán đại lý phân phối',
          badgeText: '${exportProvider.receipts.length} phiếu',
          badgeColor: AppTheme.secondaryColor,
          icon: Icons.upload_rounded,
          accentColor: AppTheme.secondaryColor,
          route: AppRoutes.export,
        ),

        if (recentEntries.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionTitle('Biến động giao dịch gần đây'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (var i = 0; i < recentEntries.length; i++) ...[
                    _RecentTransactionTile(entry: recentEntries[i]),
                    if (i < recentEntries.length - 1)
                      const Divider(
                          height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModernTransactionCard extends StatelessWidget {
  const _ModernTransactionCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.accentColor,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color accentColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pushNamed(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
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
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.entry});

  final _RecentEntry entry;

  @override
  Widget build(BuildContext context) {
    final color =
        entry.isImport ? AppTheme.accentGreen : AppTheme.secondaryColor;
    final bags = (entry.quantity / 50).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.isImport
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        entry.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '• ${entry.riceName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.partnerName} • ${DateFormatter.ddMMyyyy(entry.date)} • $bags bao',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.isImport ? '+' : '-'}${CurrencyFormatter.formatVnd(entry.totalAmount)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.isImport ? '+' : '-'}${NumberFormatter.quantity(entry.quantity)} kg',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
