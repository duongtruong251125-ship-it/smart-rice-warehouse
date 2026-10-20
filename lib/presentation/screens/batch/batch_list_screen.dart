import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/services/printing_service.dart';
import 'package:smart_rice_warehouse/logic/view_models/batch_list_view_model.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/presentation/widgets/pressable_scale.dart';
import 'package:smart_rice_warehouse/presentation/widgets/rice_thumbnail.dart';
import 'package:smart_rice_warehouse/presentation/widgets/search_field.dart';
import 'package:smart_rice_warehouse/presentation/widgets/status_chip.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  final _searchController = TextEditingController();
  late final BatchListViewModel _viewModel;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _viewModel = BatchListViewModel();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final riceProvider = context.watch<RiceProvider>();
    final isLoading = batchProvider.isLoading || riceProvider.isLoading;
    final errorMessage =
        batchProvider.errorMessage ?? riceProvider.errorMessage;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final allBatches = batchProvider.batches;
        final filteredBatches = _viewModel.filterBatches(allBatches);
        final metrics = _viewModel.calculateMetrics(filteredBatches);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Quản lý lô gạo lưu kho'),
            actions: [
              IconButton(
                tooltip: 'Xuất báo cáo Excel',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_rounded),
                onPressed: _isExporting
                    ? null
                    : () async {
                        setState(() => _isExporting = true);
                        try {
                          final batches = context.read<BatchProvider>().batches;
                          final rices = context.read<RiceProvider>().rices;
                          final exported =
                              await _viewModel.exportExcel(batches, rices);
                          if (context.mounted) {
                            if (exported) {
                              AppToast.success(context, 'Đã tạo báo cáo Excel');
                            } else {
                              AppToast.error(
                                  context, 'Không thể tạo báo cáo Excel');
                            }
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isExporting = false);
                          }
                        }
                      },
              ),
              IconButton(
                tooltip: 'Quét tem QR Lô',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.qrScanner),
              ),
            ],
          ),
          body: Column(
            children: [
              AsyncStatusBanner(
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRetry: () {
                  batchProvider.retrySync();
                  riceProvider.retrySync();
                },
              ),
              // 1. Thanh tìm kiếm thông minh + Hàng Filter Chips ngang
              Container(
                color: AppTheme.cardBg(context),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchField(
                      controller: _searchController,
                      hintText:
                          'Tìm theo mã lô (LO-...), tên gạo ST25, vị trí...',
                      onChanged: (value) => _viewModel.setQuery(value),
                    ),
                    const SizedBox(height: 10),
                    HorizontalFilterBar<String>(
                      items: BatchListViewModel.filterOptions,
                      selectedItem: _viewModel.selectedFilter,
                      labelBuilder: (item) => item,
                      badgeCountBuilder: (item) =>
                          _viewModel.getBadgeCount(item, allBatches),
                      onSelected: (filter) => _viewModel.setFilter(filter),
                    ),
                    const SizedBox(height: 10),

                    // Thống kê tóm tắt
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Hiển thị: ${filteredBatches.length} lô gạo • '
                            'Tổng: ${metrics.totalKg >= 1000 ? '${metrics.totalTons.toStringAsFixed(2).replaceAll('.', ',')} Tấn' : '${NumberFormatter.quantity(metrics.totalKg)} kg'} '
                            '(~ ${metrics.totalBags} bao)',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor(context),
                              fontSize: 12.5,
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
                        message: _viewModel.query.isNotEmpty ||
                                _viewModel.selectedFilter != 'Tất cả'
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
                            rice: rice,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModernBatchCard extends StatelessWidget {
  const _ModernBatchCard({
    required this.batch,
    required this.unit,
    this.rice,
  });

  final BatchModel batch;
  final String unit;
  final RiceModel? rice;

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

    return PressableScale(
      semanticLabel: 'Lô gạo ${batch.code}, ${batch.riceName}',
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.batchDetail,
        arguments: batch.id,
      ),
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border(context),
            width: 1,
          ),
          boxShadow: AppTheme.isDark(context)
              ? AppTheme.darkCardShadow
              : AppTheme.softShadow,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: railColor, width: 5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RiceThumbnail(
                    rice: rice,
                    name: batch.riceName,
                    size: 42,
                    borderRadius: 10,
                    enablePreview: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              batch.code,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                            StatusChip.custom(
                              label: batch.status.label,
                              isPositive: batch.status == BatchStatus.available,
                            ),
                            if (isWarning || isExpired || isCritical)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: railColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isExpired
                                      ? 'Hết hạn'
                                      : 'FEFO: ${daysUntilExpiry}d',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: railColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batch.riceName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Số lượng:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                        Text(
                          batch.quantity >= 1000
                              ? '${tons.toStringAsFixed(2).replaceAll('.', ',')} Tấn'
                              : '${NumberFormatter.quantity(batch.quantity)} $unit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 15,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                batch.locationName ?? 'Chưa xếp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'HSD: ${DateFormatter.ddMMyyyy(batch.expiryDate)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: (isWarning || isCritical || isExpired)
                                ? AppTheme.dangerTextColor(context)
                                : AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Nhập: ${DateFormatter.ddMMyyyy(batch.importDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                        color: AppTheme.textSecondaryColor(context),
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.warehouseLocations),
                        tooltip: 'Chuyển vị trí',
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 20),
                        color: AppTheme.primaryColor,
                        onPressed: () async {
                          final printed =
                              await PrintingService.printBatchLabel(batch);
                          if (!context.mounted || printed) return;
                          AppToast.info(context, 'Đã hủy lệnh in tem QR.');
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
    );
  }
}
