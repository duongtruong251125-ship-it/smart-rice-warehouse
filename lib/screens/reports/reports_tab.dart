import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/screens/reports/report_charts.dart';
import 'package:smart_rice_warehouse/widgets/dashboard_card.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';
import 'package:smart_rice_warehouse/models/inventory_snapshot_model.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int _selectedMonthTable = 0; // 0: Nhập, 1: Xuất, 2: Cả hai

  @override
  Widget build(BuildContext context) {
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final riceProvider = context.watch<RiceProvider>();
    final now = DateTime.now();
    final activities = _buildDailyActivities(
      today: now,
      importProvider: importProvider,
      exportProvider: exportProvider,
    );
    final topExportedRices = _calculateTopExportedRices(
      exportReceipts: exportProvider.receipts,
      rices: riceProvider.rices,
    );
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    final currentMonthImports = importProvider.receipts
        .where(
          (r) => r.date.year == now.year && r.date.month == now.month,
        )
        .toList();
    final currentMonthExports = exportProvider.receipts
        .where(
          (r) => r.date.year == now.year && r.date.month == now.month,
        )
        .toList();

    final effectiveImports = currentMonthImports.isNotEmpty
        ? currentMonthImports
        : importProvider.receipts.reversed.take(6).toList();
    final effectiveExports = currentMonthExports.isNotEmpty
        ? currentMonthExports
        : exportProvider.receipts.reversed.take(6).toList();

    final monthImportAmount = currentMonthImports.isNotEmpty
        ? importProvider.totalAmountForMonth(now)
        : effectiveImports.fold(0.0, (s, r) => s + r.totalAmount);
    final monthExportAmount = currentMonthExports.isNotEmpty
        ? exportProvider.totalAmountForMonth(now)
        : effectiveExports.fold(0.0, (s, r) => s + r.totalAmount);

    final monthImportQty = effectiveImports.fold(0.0, (s, r) => s + r.quantity);
    final monthExportQty = effectiveExports.fold(0.0, (s, r) => s + r.quantity);

    final weeklyData = _buildMonthlyWeeklyBars(
      importReceipts: effectiveImports,
      exportReceipts: effectiveExports,
    );
    final inventorySlices = _buildInventorySlices(
      batches: batchProvider.batches,
      rices: riceProvider.rices,
    );
    final inventoryValuePoints = _buildInventoryValuePoints(
      snapshots: context.read<AppSnapshot>().snapshots,
      today: now,
      currentValue: batchProvider.inventoryValue(riceProvider.rices),
      importReceipts: importProvider.receipts,
      exportReceipts: exportProvider.receipts,
      rices: riceProvider.rices,
    );

    final total7DaysImport =
        activities.fold(0.0, (s, a) => s + a.importQuantity);
    final total7DaysExport =
        activities.fold(0.0, (s, a) => s + a.exportQuantity);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Tổng quan tháng này'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: isNarrow ? 1 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isNarrow ? 2.1 : 1.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MonthlyMetricCard(
                title: 'Tổng nhập tháng',
                amount: monthImportAmount,
                quantity: monthImportQty,
                receiptCount: effectiveImports.length,
                icon: Icons.download_rounded,
                accentColor: AppTheme.accentGreen,
                isSelected:
                    _selectedMonthTable == 0 || _selectedMonthTable == 2,
                onTap: () {
                  setState(() {
                    _selectedMonthTable = 0;
                  });
                },
              ),
              _MonthlyMetricCard(
                title: 'Tổng xuất tháng',
                amount: monthExportAmount,
                quantity: monthExportQty,
                receiptCount: effectiveExports.length,
                icon: Icons.upload_rounded,
                accentColor: AppTheme.secondaryColor,
                isSelected:
                    _selectedMonthTable == 1 || _selectedMonthTable == 2,
                onTap: () {
                  setState(() {
                    _selectedMonthTable = 1;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: DashboardCard(
              icon: Icons.inventory_2_outlined,
              title: 'Giá trị tồn kho',
              value: CurrencyFormatter.formatVnd(
                batchProvider.inventoryValue(riceProvider.rices),
              ),
              accentColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Phân tích tồn kho'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final composition = InventoryCompositionChart(
                slices: inventorySlices,
                totalQuantity: inventorySlices.fold(
                  0,
                  (sum, item) => sum + item.quantity,
                ),
              );
              final trend = InventoryValueTrendChart(
                points: inventoryValuePoints,
              );

              if (constraints.maxWidth >= 720) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: composition),
                    const SizedBox(width: 12),
                    Expanded(child: trend),
                  ],
                );
              }
              return Column(
                children: [
                  composition,
                  const SizedBox(height: 12),
                  trend,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _MonthlyDetailTableCard(
            selectedMode: _selectedMonthTable,
            onModeChanged: (mode) {
              setState(() {
                _selectedMonthTable = mode;
              });
            },
            importReceipts: effectiveImports,
            exportReceipts: effectiveExports,
            weeklyData: weeklyData,
            isNarrow: isNarrow,
          ),
          const SizedBox(height: 24),
          const SectionTitle('Hoạt động 7 ngày gần đây'),
          const SizedBox(height: 4),
          Text(
            'Nhập: ${NumberFormatter.quantity(total7DaysImport)} kg • Xuất: ${NumberFormatter.quantity(total7DaysExport)} kg',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _SevenDayChart(activities: activities),
          const SizedBox(height: 24),
          if (isNarrow) ...[
            const SectionTitle('Top gạo xuất nhiều nhất'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.forecast),
                icon: const Icon(Icons.insights_rounded, size: 16),
                label: const Text('Xem dự báo'),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: SectionTitle('Top gạo xuất nhiều nhất'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.forecast),
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('Xem dự báo'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _TopExportedList(items: topExportedRices),
        ],
      ),
    );
  }
}

class _MonthlyDetailTableCard extends StatelessWidget {
  const _MonthlyDetailTableCard({
    required this.selectedMode,
    required this.onModeChanged,
    required this.importReceipts,
    required this.exportReceipts,
    required this.weeklyData,
    required this.isNarrow,
  });

  final int selectedMode;
  final ValueChanged<int> onModeChanged;
  final List<ImportReceiptModel> importReceipts;
  final List<ExportReceiptModel> exportReceipts;
  final List<_WeeklyBarData> weeklyData;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TableModeChip(
                  label: '📥 Bảng Cột Nhập (${importReceipts.length})',
                  isSelected: selectedMode == 0,
                  activeColor: AppTheme.accentGreen,
                  onTap: () => onModeChanged(0),
                ),
                _TableModeChip(
                  label: '📤 Bảng Cột Xuất (${exportReceipts.length})',
                  isSelected: selectedMode == 1,
                  activeColor: AppTheme.secondaryColor,
                  onTap: () => onModeChanged(1),
                ),
                _TableModeChip(
                  label: '📋 Cả 2 Bảng',
                  isSelected: selectedMode == 2,
                  activeColor: AppTheme.primaryColor,
                  onTap: () => onModeChanged(2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MonthlyColumnBars(
              selectedMode: selectedMode,
              weeklyData: weeklyData,
            ),
            const SizedBox(height: 14),
            if (selectedMode == 0 || selectedMode == 2) ...[
              _ImportDataTable(
                receipts: importReceipts,
                isNarrow: isNarrow,
              ),
            ],
            if (selectedMode == 2) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(thickness: 1.5),
              ),
            ],
            if (selectedMode == 1 || selectedMode == 2) ...[
              _ExportDataTable(
                receipts: exportReceipts,
                isNarrow: isNarrow,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableModeChip extends StatelessWidget {
  const _TableModeChip({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MonthlyColumnBars extends StatelessWidget {
  const _MonthlyColumnBars({
    required this.selectedMode,
    required this.weeklyData,
  });

  final int selectedMode;
  final List<_WeeklyBarData> weeklyData;

  @override
  Widget build(BuildContext context) {
    final showImport = selectedMode == 0 || selectedMode == 2;
    final showExport = selectedMode == 1 || selectedMode == 2;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Biểu đồ cột tháng này (kg):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (showImport)
                    const _LegendItem(
                      color: AppTheme.accentGreen,
                      label: 'Cột Nhập',
                    ),
                  if (showExport)
                    const _LegendItem(
                      color: AppTheme.secondaryColor,
                      label: 'Cột Xuất',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ReportFlowBarChart(
            points: weeklyData
                .map(
                  (week) => ReportFlowPoint(
                    label: week.label.split(' ').first,
                    importQuantity: week.importQty,
                    exportQuantity: week.exportQty,
                  ),
                )
                .toList(growable: false),
            showImport: showImport,
            showExport: showExport,
          ),
        ],
      ),
    );
  }
}

class _ImportDataTable extends StatelessWidget {
  const _ImportDataTable({
    required this.receipts,
    required this.isNarrow,
  });

  final List<ImportReceiptModel> receipts;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    final totalQty = receipts.fold(0.0, (s, r) => s + r.quantity);
    final totalAmount = receipts.fold(0.0, (s, r) => s + r.totalAmount);
    final sortedReceipts = List<ImportReceiptModel>.from(receipts)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 15,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Bảng Cột Nhập Tháng',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${sortedReceipts.length} dòng dữ liệu',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
          ],
        ),
        if (isNarrow) ...[
          const SizedBox(height: 4),
          const Text(
            '👉 Vuốt ngang để xem đầy đủ các cột dữ liệu',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 465,
                child: Column(
                  children: [
                    // TABLE HEADER
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              'Cột Ngày',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Cột Mã phiếu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 115,
                            child: Text(
                              'Cột Loại gạo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'Cột Lượng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGreen,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text(
                              'Cột Tiền (₫)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // TABLE ROWS
                    ...sortedReceipts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final receipt = entry.value;
                      final isEven = index % 2 == 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              isEven ? Colors.white : const Color(0xFFF8FAFC),
                          border: const Border(
                            bottom:
                                BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text(
                                _formatDate(receipt.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    receipt.code,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 115,
                              child: Text(
                                receipt.riceName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '+${NumberFormatter.quantity(receipt.quantity)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentGreen,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                CurrencyFormatter.formatVnd(
                                    receipt.totalAmount),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // TABLE FOOTER TOTALS
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.08),
                        border: const Border(
                          top: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 265,
                            child: Text(
                              'Tổng Cột Nhập:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '+${NumberFormatter.quantity(totalQty)} kg',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGreen,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text(
                              CurrencyFormatter.formatVnd(totalAmount),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGreen,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportDataTable extends StatelessWidget {
  const _ExportDataTable({
    required this.receipts,
    required this.isNarrow,
  });

  final List<ExportReceiptModel> receipts;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    final totalQty = receipts.fold(0.0, (s, r) => s + r.quantity);
    final totalAmount = receipts.fold(0.0, (s, r) => s + r.totalAmount);
    final sortedReceipts = List<ExportReceiptModel>.from(receipts)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      size: 15,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Bảng Cột Xuất Tháng',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${sortedReceipts.length} dòng dữ liệu',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ),
          ],
        ),
        if (isNarrow) ...[
          const SizedBox(height: 4),
          const Text(
            '👉 Vuốt ngang để xem đầy đủ các cột dữ liệu',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 465,
                child: Column(
                  children: [
                    // TABLE HEADER
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              'Cột Ngày',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Cột Mã phiếu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 115,
                            child: Text(
                              'Cột Khách hàng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'Cột Lượng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondaryColor,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text(
                              'Cột Tiền (₫)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // TABLE ROWS
                    ...sortedReceipts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final receipt = entry.value;
                      final isEven = index % 2 == 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              isEven ? Colors.white : const Color(0xFFF8FAFC),
                          border: const Border(
                            bottom:
                                BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text(
                                _formatDate(receipt.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    receipt.code,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.secondaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 115,
                              child: Text(
                                '${receipt.customerName} (${receipt.riceName})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '-${NumberFormatter.quantity(receipt.quantity)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.secondaryColor,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                CurrencyFormatter.formatVnd(
                                    receipt.totalAmount),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // TABLE FOOTER TOTALS
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                        border: const Border(
                          top: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 265,
                            child: Text(
                              'Tổng Cột Xuất:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '-${NumberFormatter.quantity(totalQty)} kg',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondaryColor,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text(
                              CurrencyFormatter.formatVnd(totalAmount),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondaryColor,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopExportedItem {
  const _TopExportedItem({
    required this.riceId,
    required this.riceName,
    required this.unit,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  final String riceId;
  final String riceName;
  final String unit;
  final double totalQuantity;
  final double totalRevenue;
}

List<_TopExportedItem> _calculateTopExportedRices({
  required List<ExportReceiptModel> exportReceipts,
  required List<RiceModel> rices,
}) {
  final quantities = <String, double>{};
  final revenues = <String, double>{};

  for (final receipt in exportReceipts) {
    quantities[receipt.riceId] =
        (quantities[receipt.riceId] ?? 0.0) + receipt.quantity;
    revenues[receipt.riceId] =
        (revenues[receipt.riceId] ?? 0.0) + receipt.totalAmount;
  }

  final items = <_TopExportedItem>[];
  for (final entry in quantities.entries) {
    final rice = rices.cast<RiceModel?>().firstWhere(
          (r) => r?.id == entry.key,
          orElse: () => null,
        );
    items.add(
      _TopExportedItem(
        riceId: entry.key,
        riceName: rice?.name ?? entry.key,
        unit: rice?.unit ?? 'kg',
        totalQuantity: entry.value,
        totalRevenue: revenues[entry.key] ?? 0.0,
      ),
    );
  }

  items.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
  return items.take(5).toList(growable: false);
}

class _TopExportedList extends StatelessWidget {
  const _TopExportedList({required this.items});

  final List<_TopExportedItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Chưa có dữ liệu xuất hàng',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final maxQty = items.first.totalQuantity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 16),
              _buildRow(items[index], index + 1, maxQty, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    _TopExportedItem item,
    int rank,
    double maxQty,
    ThemeData theme,
  ) {
    final ratio =
        maxQty > 0 ? (item.totalQuantity / maxQty).clamp(0.05, 1.0) : 0.0;
    final isTop1 = rank == 1;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isTop1 ? AppTheme.secondaryColor : AppTheme.backgroundColor,
            shape: BoxShape.circle,
            border: isTop1 ? null : Border.all(color: AppTheme.borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isTop1 ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.riceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: AppTheme.backgroundColor,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${NumberFormatter.quantity(item.totalQuantity)} ${item.unit}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.formatVnd(item.totalRevenue),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({required this.activities});

  final List<_DailyActivity> activities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var maximum = 0.0;
    for (final activity in activities) {
      if (activity.importQuantity > maximum) {
        maximum = activity.importQuantity;
      }
      if (activity.exportQuantity > maximum) {
        maximum = activity.exportQuantity;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _LegendItem(
                    color: AppTheme.accentGreen, label: 'Cột Nhập kho (kg)'),
                _LegendItem(
                    color: AppTheme.secondaryColor, label: 'Cột Xuất kho (kg)'),
              ],
            ),
            const SizedBox(height: 16),
            if (maximum == 0)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Chưa có dữ liệu trong khoảng thời gian này',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 125,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final activity in activities)
                      Expanded(
                        child: _DailyBars(
                          activity: activity,
                          maximum: maximum,
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(height: 28),
            Text(
              'Bảng đối soát 7 ngày gần đây:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _SevenDayTable(activities: activities),
          ],
        ),
      ),
    );
  }
}

class _SevenDayTable extends StatelessWidget {
  const _SevenDayTable({required this.activities});

  final List<_DailyActivity> activities;

  @override
  Widget build(BuildContext context) {
    final reversed = activities.reversed.toList();
    final today = DateTime.now();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Ngày',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Nhập (kg)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGreen,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Xuất (kg)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Biến động',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...reversed.map((act) {
          final isToday = act.date.year == today.year &&
              act.date.month == today.month &&
              act.date.day == today.day;
          final net = act.importQuantity - act.exportQuantity;
          final dateStr = isToday
              ? 'Hôm nay'
              : '${act.date.day.toString().padLeft(2, '0')}/${act.date.month.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    act.importQuantity > 0
                        ? '+${NumberFormatter.quantity(act.importQuantity)}'
                        : '0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: act.importQuantity > 0
                          ? AppTheme.accentGreen
                          : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    act.exportQuantity > 0
                        ? '-${NumberFormatter.quantity(act.exportQuantity)}'
                        : '0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: act.exportQuantity > 0
                          ? AppTheme.secondaryColor
                          : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    net > 0
                        ? '+${NumberFormatter.quantity(net)}'
                        : NumberFormatter.quantity(net),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: net > 0
                          ? AppTheme.accentGreen
                          : (net < 0
                              ? AppTheme.secondaryColor
                              : AppTheme.textSecondary),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.activity, required this.maximum});

  final _DailyActivity activity;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    final hasImport = activity.importQuantity > 0;
    final hasExport = activity.exportQuantity > 0;

    return Column(
      children: [
        SizedBox(
          height: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasImport)
                  Text(
                    '${activity.importQuantity.toInt()}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                if (hasImport && hasExport) const SizedBox(width: 2),
                if (hasExport)
                  Text(
                    '${activity.exportQuantity.toInt()}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final importH = maximum > 0 && hasImport
                  ? (maxH * activity.importQuantity / maximum).clamp(6.0, maxH)
                  : 2.0;
              final exportH = maximum > 0 && hasExport
                  ? (maxH * activity.exportQuantity / maximum).clamp(6.0, maxH)
                  : 2.0;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ActivityBar(
                      height: importH,
                      color: hasImport
                          ? AppTheme.accentGreen
                          : const Color(0xFFE2E8F0),
                      width: 11,
                    ),
                    const SizedBox(width: 3),
                    _ActivityBar(
                      height: exportH,
                      color: hasExport
                          ? AppTheme.secondaryColor
                          : const Color(0xFFE2E8F0),
                      width: 11,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${activity.date.day}/${activity.date.month}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({
    required this.height,
    required this.color,
    this.width = 11,
  });

  final double height;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _MonthlyMetricCard extends StatelessWidget {
  const _MonthlyMetricCard({
    required this.title,
    required this.amount,
    required this.quantity,
    required this.receiptCount,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final double amount;
  final double quantity;
  final int receiptCount;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 2.5 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? accentColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color:
                isSelected ? accentColor.withValues(alpha: 0.04) : Colors.white,
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? accentColor : AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, size: 16, color: accentColor),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatVnd(amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${NumberFormatter.quantity(quantity)} kg • $receiptCount phiếu',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSelected ? '✓ Đang xem bảng' : '👆 Nhấp xem bảng',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? accentColor : AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarData {
  const _WeeklyBarData({
    required this.label,
    required this.importQty,
    required this.exportQty,
  });

  final String label;
  final double importQty;
  final double exportQty;
}

List<_WeeklyBarData> _buildMonthlyWeeklyBars({
  required List<ImportReceiptModel> importReceipts,
  required List<ExportReceiptModel> exportReceipts,
}) {
  final importQtys = [0.0, 0.0, 0.0, 0.0];
  final exportQtys = [0.0, 0.0, 0.0, 0.0];

  for (final r in importReceipts) {
    final day = r.date.day;
    final index = (day <= 7)
        ? 0
        : (day <= 14)
            ? 1
            : (day <= 21)
                ? 2
                : 3;
    importQtys[index] += r.quantity;
  }

  for (final r in exportReceipts) {
    final day = r.date.day;
    final index = (day <= 7)
        ? 0
        : (day <= 14)
            ? 1
            : (day <= 21)
                ? 2
                : 3;
    exportQtys[index] += r.quantity;
  }

  final labels = [
    'Tuần 1 (1-7)',
    'Tuần 2 (8-14)',
    'Tuần 3 (15-21)',
    'Tuần 4 (22+)'
  ];
  return List.generate(4, (i) {
    return _WeeklyBarData(
      label: labels[i],
      importQty: importQtys[i],
      exportQty: exportQtys[i],
    );
  });
}

class _DailyActivity {
  const _DailyActivity({
    required this.date,
    required this.importQuantity,
    required this.exportQuantity,
  });

  final DateTime date;
  final double importQuantity;
  final double exportQuantity;
}

List<_DailyActivity> _buildDailyActivities({
  required DateTime today,
  required ImportProvider importProvider,
  required ExportProvider exportProvider,
}) {
  final currentDay = DateTime(today.year, today.month, today.day);
  return List<_DailyActivity>.generate(7, (index) {
    final date = currentDay.subtract(Duration(days: 6 - index));
    return _DailyActivity(
      date: date,
      importQuantity: importProvider.quantityOn(date),
      exportQuantity: exportProvider.quantityOn(date),
    );
  });
}

List<ReportInventorySlice> _buildInventorySlices({
  required List<BatchModel> batches,
  required List<RiceModel> rices,
}) {
  const colors = [
    AppTheme.primaryColor,
    AppTheme.warningColor,
    AppTheme.infoColor,
    Color(0xFF8B5CF6),
    AppTheme.accentTeal,
  ];
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final namesById = {for (final rice in rices) rice.id: rice.name};
  final quantities = <String, double>{};

  for (final batch in batches) {
    final expiry = DateTime(
      batch.expiryDate.year,
      batch.expiryDate.month,
      batch.expiryDate.day,
    );
    if (batch.quantity <= 0 ||
        batch.status == BatchStatus.expired ||
        expiry.isBefore(startOfToday)) {
      continue;
    }
    quantities.update(
      batch.riceId,
      (value) => value + batch.quantity,
      ifAbsent: () => batch.quantity,
    );
  }

  final sorted = quantities.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final visible = sorted.take(4).toList();
  final otherQuantity = sorted.skip(4).fold<double>(
        0,
        (sum, entry) => sum + entry.value,
      );

  final result = List<ReportInventorySlice>.generate(
    visible.length,
    (index) => ReportInventorySlice(
      label: namesById[visible[index].key] ?? visible[index].key,
      quantity: visible[index].value,
      color: colors[index],
    ),
  );
  if (otherQuantity > 0) {
    result.add(
      ReportInventorySlice(
        label: 'Khác',
        quantity: otherQuantity,
        color: colors[4],
      ),
    );
  }
  return result;
}

List<ReportValuePoint> _buildInventoryValuePoints({
  required List<InventorySnapshotModel> snapshots,
  required DateTime today,
  required double currentValue,
  required List<ImportReceiptModel> importReceipts,
  required List<ExportReceiptModel> exportReceipts,
  required List<RiceModel> rices,
}) {
  final pricesByRiceId = {
    for (final rice in rices) rice.id: rice.purchasePrice,
  };
  final startOfToday = DateTime(today.year, today.month, today.day);

  return List.generate(7, (index) {
    final date = startOfToday.subtract(Duration(days: 6 - index));
    final nextDay = date.add(const Duration(days: 1));
    final laterImports = importReceipts
        .where((receipt) => !receipt.date.isBefore(nextDay))
        .fold<double>(0, (sum, receipt) => sum + receipt.totalAmount);
    final laterExportCost = exportReceipts
        .where((receipt) => !receipt.date.isBefore(nextDay))
        .fold<double>(
          0,
          (sum, receipt) =>
              sum +
              receipt.quantity *
                  (pricesByRiceId[receipt.riceId] ?? receipt.sellingPrice),
        );
    return ReportValuePoint(
      date: date,
      value: (currentValue - laterImports + laterExportCost).clamp(
        0,
        double.infinity,
      ),
    );
  });
}

String _formatDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month';
}
