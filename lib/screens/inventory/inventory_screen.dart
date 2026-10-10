import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/search_field.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedFilter = 'Tất cả';

  static const _filterOptions = <String>[
    'Tất cả',
    'ST25',
    'Jasmine',
    'Bao 50kg',
    'Cần nhập thêm',
    'Đủ hàng',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riceProvider = context.watch<RiceProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final allRices = riceProvider.searchRice(_query);

    // Lọc theo Filter Chip
    final filteredRices = allRices.where((rice) {
      final stock = batchProvider.totalStockForRice(rice.id);
      final isLow = stock <= rice.minimumStock;

      switch (_selectedFilter) {
        case 'ST25':
          return rice.name.toLowerCase().contains('st25') ||
              rice.code.toLowerCase().contains('st25');
        case 'Jasmine':
          return rice.name.toLowerCase().contains('jasmine');
        case 'Bao 50kg':
          return true; // Tất cả gạo dạng đóng bao 50kg
        case 'Cần nhập thêm':
          return isLow;
        case 'Đủ hàng':
          return !isLow;
        case 'Tất cả':
        default:
          return true;
      }
    }).toList(growable: false);

    final totalKg = filteredRices.fold<double>(
      0.0,
      (sum, rice) => sum + batchProvider.totalStockForRice(rice.id),
    );
    final totalTons = totalKg / 1000.0;
    final totalBags = (totalKg / 50.0).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tồn kho gạo'),
        actions: [
          IconButton(
            tooltip: 'Tạo phiếu nhập mới',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.addImport),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh công cụ tìm kiếm thông minh + Hàng Filter Chips ngang
          Container(
            color: AppTheme.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchField(
                  controller: _searchController,
                  hintText: 'Tìm theo mã lô, tên gạo ST25, Jasmine...',
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
                    if (item == 'Cần nhập thêm') {
                      return allRices
                          .where((r) =>
                              batchProvider.totalStockForRice(r.id) <=
                              r.minimumStock)
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

                // Thống kê tóm tắt theo bộ lọc
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
                        'Hiển thị: ${filteredRices.length} loại gạo • '
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
            child: filteredRices.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_outlined,
                    message: _query.isNotEmpty || _selectedFilter != 'Tất cả'
                        ? 'Không tìm thấy loại gạo phù hợp bộ lọc'
                        : 'Kho hiện chưa có dữ liệu mặt hàng',
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filteredRices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final rice = filteredRices[index];
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
                        locationText: locationNames.isNotEmpty
                            ? locationNames
                            : 'Khu A - Silo Trung Tâm',
                      );
                    },
                  ),
          ),
        ],
      ),
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

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock ? AppTheme.warningBorder : AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header thẻ: Icon gạo + Tên sản phẩm + Badge trạng thái
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.rice_bowl_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rice.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rice.code,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                rice.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(isLowStock: isLowStock),
                ],
              ),
              const SizedBox(height: 12),

              // Thông tin Silo / Quy cách đóng gói & Tồn kho quy đổi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    // Hàng tồn kho chính (Tấn + kg + số bao)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'Số lượng tồn thực tế:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              totalStock >= 1000
                                  ? '${tons.toStringAsFixed(2).replaceAll('.', ',')} TẤN'
                                  : '${NumberFormatter.quantity(totalStock)} KG',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isLowStock
                                    ? AppTheme.warningText
                                    : AppTheme.primaryDark,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '(~ $bagsCount bao 50kg)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 14),

                    // Vị trí Silo / Kệ và Quy cách đóng gói
                    Row(
                      children: [
                        const Icon(
                          Icons.warehouse_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Vị trí: $locationText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$batchCount lô lưu kho',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Action Toolbar nhanh: Xem lô gạo, In tem mã vạch, Nhập thêm
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      minimumSize: const Size(0, 36),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.batches),
                    icon: const Icon(Icons.qr_code_2_rounded,
                        size: 16, color: AppTheme.textSecondary),
                    label: const Text(
                      'Lô hàng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.addImport),
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Nhập thêm',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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
