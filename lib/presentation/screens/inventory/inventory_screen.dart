import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/inventory_view_model.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/presentation/widgets/rice_thumbnail.dart';
import 'package:smart_rice_warehouse/presentation/widgets/search_field.dart';
import 'package:smart_rice_warehouse/presentation/widgets/status_chip.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  late final InventoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = InventoryViewModel();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Widget _buildInventoryCard(
    RiceModel rice,
    BatchProvider batchProvider,
  ) {
    final stock = batchProvider.totalStockForRice(rice.id);
    final batches = batchProvider.findByRiceId(rice.id);
    final locationNames = batches
        .map((b) => b.locationName)
        .where((loc) => loc != null && loc.isNotEmpty)
        .toSet()
        .join(', ');

    return _ModernInventoryCard(
      rice: rice,
      totalStock: stock,
      batchCount: batches.length,
      locationText:
          locationNames.isNotEmpty ? locationNames : 'Khu A - Silo Trung Tâm',
    );
  }

  @override
  Widget build(BuildContext context) {
    final riceProvider = context.watch<RiceProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final isLoading = riceProvider.isLoading || batchProvider.isLoading;
    final errorMessage =
        riceProvider.errorMessage ?? batchProvider.errorMessage;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final allRices = riceProvider.rices;
        final filteredRices = _viewModel.filterRices(
          allRices: allRices,
          batchProvider: batchProvider,
        );
        final metrics = _viewModel.calculateMetrics(
          rices: filteredRices,
          batchProvider: batchProvider,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Quản lý tồn kho gạo'),
            actions: [
              IconButton(
                tooltip: 'Tạo phiếu nhập mới',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.addImport),
              ),
            ],
          ),
          body: Column(
            children: [
              AsyncStatusBanner(
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRetry: () {
                  riceProvider.retrySync();
                  batchProvider.retrySync();
                },
              ),
              // 1. Thanh công cụ tìm kiếm thông minh + Hàng Filter Chips ngang
              Container(
                color: AppTheme.cardBg(context),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchField(
                      controller: _searchController,
                      hintText: 'Tìm theo mã lô, tên gạo ST25, Jasmine...',
                      onChanged: (value) => _viewModel.setQuery(value),
                    ),
                    const SizedBox(height: 10),
                    HorizontalFilterBar<String>(
                      items: InventoryViewModel.filterOptions,
                      selectedItem: _viewModel.selectedFilter,
                      labelBuilder: (item) => item,
                      badgeCountBuilder: (item) => _viewModel.getBadgeCount(
                        item,
                        allRices,
                        batchProvider,
                      ),
                      onSelected: (filter) => _viewModel.setFilter(filter),
                    ),
                    const SizedBox(height: 10),

                    // Thống kê tóm tắt theo bộ lọc
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AppTheme.isDark(context)
                              ? const Color(0xFF34D399)
                              : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Hiển thị: ${filteredRices.length} loại gạo • '
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
              Divider(height: 1, color: AppTheme.border(context)),

              // 2. Danh sách Modern Data Cards (hỗ trợ cả điện thoại 320px/390px và Tablet >= 720px)
              Expanded(
                child: filteredRices.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_outlined,
                        message: _viewModel.query.isNotEmpty ||
                                _viewModel.selectedFilter != 'Tất cả'
                            ? 'Không tìm thấy loại gạo phù hợp bộ lọc'
                            : 'Kho hiện chưa có dữ liệu mặt hàng',
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isTablet = constraints.maxWidth >= 720;
                          if (isTablet) {
                            final rowCount = (filteredRices.length + 1) ~/ 2;
                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: rowCount,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, rowIndex) {
                                final firstIndex = rowIndex * 2;
                                final secondIndex = firstIndex + 1;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildInventoryCard(
                                        filteredRices[firstIndex],
                                        batchProvider,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: secondIndex < filteredRices.length
                                          ? _buildInventoryCard(
                                              filteredRices[secondIndex],
                                              batchProvider,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                );
                              },
                            );
                          }

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: filteredRices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildInventoryCard(
                              filteredRices[index],
                              batchProvider,
                            ),
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

class _ModernInventoryCard extends StatelessWidget {
  const _ModernInventoryCard({
    required this.rice,
    required this.totalStock,
    required this.batchCount,
    required this.locationText,
  });

  final RiceModel rice;
  final double totalStock;
  final int batchCount;
  final String locationText;

  @override
  Widget build(BuildContext context) {
    final isLowStock = totalStock <= rice.minimumStock;
    final bagsCount = (totalStock / 50.0).round();
    final tons = totalStock / 1000.0;

    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock
              ? AppTheme.warningBorderColor(context)
              : AppTheme.border(context),
          width: 1,
        ),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header thẻ: Thumbnail gạo + Tên sản phẩm + Badge trạng thái
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RiceThumbnail(
                    rice: rice,
                    size: 44,
                    borderRadius: 12,
                    enablePreview: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rice.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryColor(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(isLowStock: isLowStock),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF131D31)
                                    : AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rice.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ),
                            Text(
                              rice.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondaryColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final charProvider =
                      context.watch<RiceCharacteristicProvider>();
                  final chars = charProvider
                      .getCharacteristicsForIds(rice.characteristicIds);
                  if (chars.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: chars.map((char) {
                        final color = Color(char.colorValue);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  color.withValues(alpha: isDark ? 0.45 : 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            char.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Thông tin Silo / Quy cách đóng gói & Tồn kho quy đổi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hàng tồn kho chính (Tấn + kg + số bao) - dùng Wrap để không tràn ở 320px / 200% text scale
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Số lượng tồn thực tế:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              totalStock >= 1000
                                  ? '${tons.toStringAsFixed(2).replaceAll('.', ',')} TẤN'
                                  : '${NumberFormatter.quantity(totalStock)} KG',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: isLowStock
                                    ? AppTheme.warningTextColor(context)
                                    : AppTheme.safeTextColor(context),
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              '(~ $bagsCount bao 50kg)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Divider(height: 14, color: AppTheme.border(context)),

                    // Vị trí Silo / Kệ và Số lô lưu kho
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
                              Icons.warehouse_outlined,
                              size: 15,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Vị trí: $locationText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$batchCount lô lưu kho',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Action Toolbar nhanh: Xem lô gạo, Nhập thêm (dùng Wrap chống tràn ở màn hình 320px & chữ 200%)
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        minimumSize: const Size(88, 44),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        side: BorderSide(color: AppTheme.border(context)),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.batches),
                      icon: Icon(
                        Icons.qr_code_2_rounded,
                        size: 17,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                      label: Text(
                        'Lô hàng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        minimumSize: const Size(96, 44),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.addImport),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Nhập thêm',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
