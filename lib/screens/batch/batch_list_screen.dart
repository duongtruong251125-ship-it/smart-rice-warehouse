import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/services/printing_service.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/search_field.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';
import 'package:smart_rice_warehouse/core/services/excel_export_service.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedFilter = 'Tất cả';

  static const _filterOptions = <String>[
    'Tất cả',
    'ST25',
    'Jasmine',
    'Bao 50kg',
    'Cần ưu tiên xuất',
    'Còn hàng',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final riceProvider = context.watch<RiceProvider>();
    final allBatches = batchProvider.searchBatches(_query);
    final now = DateTime.now();

    // Lọc theo Filter Chip
    final filteredBatches = allBatches.where((batch) {
      final daysUntilExpiry = batch.expiryDate.difference(now).inDays;

      switch (_selectedFilter) {
        case 'ST25':
          return batch.riceName.toLowerCase().contains('st25') ||
              batch.code.toLowerCase().contains('st25');
        case 'Jasmine':
          return batch.riceName.toLowerCase().contains('jasmine');
        case 'Bao 50kg':
          return true; // Tất cả quy cách bao 50kg
        case 'Cần ưu tiên xuất':
          return daysUntilExpiry <= 30 &&
              batch.quantity > 0 &&
              batch.status != BatchStatus.expired;
        case 'Còn hàng':
          return batch.status == BatchStatus.available && batch.quantity > 0;
        case 'Tất cả':
        default:
          return true;
      }
    }).toList(growable: false);

    final totalKg =
        filteredBatches.fold<double>(0.0, (sum, b) => sum + b.quantity);
    final totalTons = totalKg / 1000.0;
    final totalBags = (totalKg / 50.0).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý lô gạo lưu kho'),
        actions: [
          IconButton(
            tooltip: 'Xuất báo cáo Excel',
            icon: const Icon(Icons.file_download_rounded),
            onPressed: () {
              final batches = context.read<BatchProvider>().batches;
              final rices = context.read<RiceProvider>().rices;
              ExcelExportService.exportInventoryReport(batches, rices);
            },
          ),
          IconButton(
            tooltip: 'Quét tem QR Lô',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.qrScanner),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm thông minh + Hàng Filter Chips ngang
          Container(
            color: AppTheme.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchField(
                  controller: _searchController,
                  hintText: 'Tìm theo mã lô (LO-...), tên gạo ST25, vị trí...',
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                HorizontalFilterBar<String>(
                  items: _filterOptions,
                  selectedItem: _selectedFilter,
                  labelBuilder: (item) => item,
                  badgeCountBuilder: (item) {
                    if (item == 'Cần ưu tiên xuất') {
                      return allBatches
                          .where((b) =>
                              b.expiryDate.difference(now).inDays <= 30 &&
                              b.quantity > 0)
                          .length;
                    }
                    return null;
                  },
                  onSelected: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Thống kê tóm tắt
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 15,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hiển thị: ${filteredBatches.length} lô gạo • '
                        'Tổng: ${totalKg >= 1000 ? '${totalTons.toStringAsFixed(2).replaceAll('.', ',')} Tấn' : '${NumberFormatter.quantity(totalKg)} kg'} '
                        '(~ $totalBags bao)',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Danh sách Modern Data Cards
          Expanded(
            child: filteredBatches.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: _query.isNotEmpty || _selectedFilter != 'Tất cả'
                        ? 'Không tìm thấy lô gạo phù hợp bộ lọc'
                        : 'Chưa có lô gạo nào trong kho',
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filteredBatches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final batch = filteredBatches[index];
                      final rice = riceProvider.findById(batch.riceId);

                      return _ModernBatchCard(
                        batch: batch,
                        unit: rice?.unit ?? 'kg',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModernBatchCard extends StatelessWidget {
  const _ModernBatchCard({required this.batch, required this.unit});

  final BatchModel batch;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysUntilExpiry = batch.expiryDate.difference(now).inDays;
    final isExpired = daysUntilExpiry <= 0;
    final isCritical = daysUntilExpiry <= 7;
    final isWarning = daysUntilExpiry <= 30;
    final isQualityHold = batch.status == BatchStatus.qualityHold;

    Color railColor;
    if (isExpired || isCritical) {
      railColor = AppTheme.dangerColor;
    } else if (isQualityHold) {
      railColor = AppTheme.infoColor;
    } else if (isWarning) {
      railColor = AppTheme.warningColor;
    } else {
      railColor = AppTheme.primaryColor;
    }

    final tons = batch.quantity / 1000.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.batchDetail,
            arguments: batch.id,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  color: railColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          batch.code,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isWarning ||
                                          isExpired ||
                                          isCritical) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: railColor.withValues(
                                                alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isExpired
                                                ? 'Hết hạn'
                                                : 'FEFO: ${daysUntilExpiry}d',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: railColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    batch.riceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip.custom(
                              label: batch.status.label,
                              isPositive: batch.status == BatchStatus.available,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Số lượng:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary)),
                                  Text(
                                    batch.quantity >= 1000
                                        ? '${tons.toStringAsFixed(2).replaceAll('.', ',')} Tấn'
                                        : '${NumberFormatter.quantity(batch.quantity)} $unit',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded,
                                          size: 14,
                                          color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(batch.locationName ?? 'Chưa xếp',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                  Text(
                                    'HSD: ${DateFormatter.ddMMyyyy(batch.expiryDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (isWarning || isCritical || isExpired)
                                              ? AppTheme.dangerColor
                                              : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Nhập: ${DateFormatter.ddMMyyyy(batch.importDate)}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.swap_horiz_rounded,
                                      size: 20),
                                  color: AppTheme.textSecondary,
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.warehouseLocations),
                                  tooltip: 'Chuyển vị trí',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.qr_code_rounded,
                                      size: 20),
                                  color: AppTheme.primaryColor,
                                  onPressed: () async {
                                    final printed =
                                        await PrintingService.printBatchLabel(
                                            batch);
                                    if (!context.mounted || printed) return;
                                    AppToast.info(
                                        context, 'Đã hủy lệnh in tem QR.');
                                  },
                                  tooltip: 'In tem QR',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
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
