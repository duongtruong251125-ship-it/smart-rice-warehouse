import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/dashboard_card.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Sức chứa thiết kế của hệ thống kho (kg)
  static const double _warehouseCapacityKg = 5000.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMetrics();
    });
  }

  void _syncMetrics() {
    if (!mounted) return;
    final riceProvider = context.read<RiceProvider>();
    final batchProvider = context.read<BatchProvider>();
    final exportProvider = context.read<ExportProvider>();

    context.read<AlertProvider>().scanAlerts(
          rices: riceProvider.rices,
          batches: batchProvider.batches,
        );
    context.read<ForecastProvider>().refreshForecasts(
          rices: riceProvider.rices,
          exportReceipts: exportProvider.receipts,
          batchProvider: batchProvider,
        );
  }

  @override
  Widget build(BuildContext context) {
    final riceProvider = context.watch<RiceProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final forecastProvider = context.watch<ForecastProvider>();
    final userName = context.watch<AuthProvider>().currentUser?.name ?? 'Admin';

    final today = DateTime.now();
    final totalStockKg = batchProvider.totalStock;

    // Quy đổi số liệu kho
    final totalTons = totalStockKg / 1000.0;
    final bagsCount = (totalStockKg / 50.0).round();
    final capacityRatio = totalStockKg / _warehouseCapacityKg;
    final capacityPercentText = '${(capacityRatio * 100).toStringAsFixed(1)}%';

    // Thống kê ngày hôm nay
    final todayImports = importProvider.receipts
        .where((r) =>
            r.date.year == today.year &&
            r.date.month == today.month &&
            r.date.day == today.day)
        .toList(growable: false);
    final todayImportKg = todayImports.fold(0.0, (sum, r) => sum + r.quantity);
    final todayImportTons = todayImportKg / 1000.0;

    final todayExports = exportProvider.receipts
        .where((r) =>
            r.date.year == today.year &&
            r.date.month == today.month &&
            r.date.day == today.day)
        .toList(growable: false);
    final todayExportKg = todayExports.fold(0.0, (sum, r) => sum + r.quantity);
    final todayExportTons = todayExportKg / 1000.0;

    final recentActivities = _getRecentActivities(
      rices: riceProvider.rices,
      importProvider: importProvider,
      exportProvider: exportProvider,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, $userName',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Đây là tình hình kho hàng hôm nay.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          // 1. Hero KPI: Tồn kho hiện tại
          BentoKpiCard(
            title: 'TỒN KHO HIỆN TẠI',
            mainValue: totalStockKg >= 1000
                ? totalTons.toStringAsFixed(2).replaceAll('.', ',')
                : _formatQuantity(totalStockKg),
            unit: totalStockKg >= 1000 ? 'Tấn' : 'Kg',
            convertedSubValue:
                '~ ${_formatQuantity(totalStockKg)} kg ($bagsCount bao) • ${riceProvider.rices.length} loại gạo',
            capacityPercent: capacityRatio,
            capacityText:
                '$capacityPercentText (${_formatQuantity(totalStockKg)}/${_formatQuantity(_warehouseCapacityKg)} kg)',
            badgeText: capacityRatio > 0.85 ? 'Gần đầy kho' : 'Sẵn sàng',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.inventory),
          ),
          const SizedBox(height: 12),

          // 2. Nhập Xuất hôm nay
          Row(
            children: [
              Expanded(
                child: BentoMetricCard(
                  title: 'Nhập hôm nay',
                  amountText: todayImportKg >= 1000
                      ? '+${todayImportTons.toStringAsFixed(2).replaceAll('.', ',')} Tấn'
                      : '+${_formatQuantity(todayImportKg)} kg',
                  countText: '${todayImports.length} phiếu',
                  icon: Icons.south_west_rounded,
                  accentColor: AppTheme.infoColor,
                  isPositive: true,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.import),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoMetricCard(
                  title: 'Xuất hôm nay',
                  amountText: todayExportKg >= 1000
                      ? '-${todayExportTons.toStringAsFixed(2).replaceAll('.', ',')} Tấn'
                      : '-${_formatQuantity(todayExportKg)} kg',
                  countText: '${todayExports.length} phiếu',
                  icon: Icons.north_east_rounded,
                  accentColor: AppTheme.warningColor,
                  isPositive: false,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.export),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Grid chức năng nhanh 4 cột
          const _ModernQuickActionsGrid(),
          const SizedBox(height: 24),

          // 4. Việc cần xử lý (Banner cảnh báo)
          if (alertProvider.criticalCount > 0 ||
              alertProvider.lowStockCount > 0 ||
              alertProvider.expiringCount > 0) ...[
            const SectionTitle('Việc cần xử lý'),
            const SizedBox(height: 10),
            _SmartWarehouseBanner(
              alertProvider: alertProvider,
              forecastProvider: forecastProvider,
            ),
            const SizedBox(height: 24),
          ],

          // 5. Trạng thái kho & Tồn Silo mặt hàng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionTitle('Trạng thái tồn kho'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.inventory),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _WarehouseStatus(
            rices: riceProvider.rices.take(5).toList(growable: false),
            batchProvider: batchProvider,
          ),
          const SizedBox(height: 22),

          // 7. Biến động gần nhất (Mini Activity Cards)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionTitle('Biến động gần nhất'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.import),
                child: const Text(
                  'Xem sổ kho',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _RecentActivityList(activities: recentActivities),
        ],
      ),
    );
  }
}

class _SmartWarehouseBanner extends StatelessWidget {
  const _SmartWarehouseBanner({
    required this.alertProvider,
    required this.forecastProvider,
  });

  final AlertProvider alertProvider;
  final ForecastProvider forecastProvider;

  @override
  Widget build(BuildContext context) {
    final hasCritical = alertProvider.criticalCount > 0;
    final hasWarning =
        alertProvider.lowStockCount > 0 || alertProvider.expiringCount > 0;

    final Color cardBg;
    final Color borderColor;
    final Color accentColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (hasCritical) {
      cardBg = AppTheme.dangerBg;
      borderColor = AppTheme.dangerBorder;
      accentColor = AppTheme.dangerText;
      icon = Icons.error_outline_rounded;
      final topAlert = alertProvider.criticalAlerts.first;
      title = 'Cảnh báo khẩn: ${topAlert.title}';
      subtitle = topAlert.message;
    } else if (hasWarning) {
      cardBg = AppTheme.warningBg;
      borderColor = AppTheme.warningBorder;
      accentColor = AppTheme.warningText;
      icon = Icons.warning_amber_rounded;
      title =
          'Chú ý kho: ${alertProvider.lowStockCount} loại gạo tồn thấp, ${alertProvider.expiringCount} lô cận hạn';
      subtitle = 'Ưu tiên xuất FEFO ngay hoặc chuẩn bị kế hoạch nhập hàng';
    } else {
      cardBg = AppTheme.safeBg;
      borderColor = AppTheme.safeBorder;
      accentColor = AppTheme.safeText;
      icon = Icons.verified_outlined;
      title = 'Kho hàng đang vận hành an toàn';
      subtitle = 'Tất cả mặt hàng đều đạt định mức tồn và độ ẩm lưu kho chuẩn';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pushNamed(
            hasCritical || hasWarning ? AppRoutes.alerts : AppRoutes.forecast,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: accentColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pillBadge(
                      label: '${alertProvider.lowStockCount} tồn thấp',
                      isAlert: alertProvider.lowStockCount > 0,
                      context: context,
                      route: AppRoutes.alerts,
                    ),
                    _pillBadge(
                      label: '${alertProvider.expiringCount} lô cận hạn',
                      isAlert: alertProvider.expiringCount > 0,
                      context: context,
                      route: AppRoutes.alerts,
                    ),
                    _pillBadge(
                      label:
                          '${forecastProvider.reorderSoonCount} cần nhập gấp',
                      isAlert: forecastProvider.reorderSoonCount > 0,
                      context: context,
                      route: AppRoutes.forecast,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillBadge({
    required String label,
    required bool isAlert,
    required BuildContext context,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isAlert ? AppTheme.dangerBg : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isAlert ? AppTheme.dangerBorder : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isAlert ? AppTheme.dangerText : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ModernQuickActionsGrid extends StatelessWidget {
  const _ModernQuickActionsGrid();

  static const _actions = <_QuickActionItem>[
    _QuickActionItem(
        label: 'Nhập kho',
        icon: Icons.move_to_inbox_rounded,
        color: Color(0xFF3B75D6),
        bgColor: Color(0xFFE8F0FE),
        route: AppRoutes.addImport),
    _QuickActionItem(
        label: 'Xuất kho',
        icon: Icons.outbox_rounded,
        color: Color(0xFFD97706),
        bgColor: Color(0xFFFEF3C7),
        route: AppRoutes.addExport),
    _QuickActionItem(
        label: 'Tồn kho',
        icon: Icons.inventory_2_rounded,
        color: Color(0xFF16A36A),
        bgColor: Color(0xFFE7F7EF),
        route: AppRoutes.inventory),
    _QuickActionItem(
        label: 'Quét QR',
        icon: Icons.qr_code_scanner_rounded,
        color: Color(0xFF0F172A),
        bgColor: Color(0xFFE2E8F0),
        route: AppRoutes.qrScanner),
    _QuickActionItem(
        label: 'Lô hàng',
        icon: Icons.category_rounded,
        color: Color(0xFF9333EA),
        bgColor: Color(0xFFF3E8FF),
        route: AppRoutes.batches),
    _QuickActionItem(
        label: 'Kiểm kê',
        icon: Icons.fact_check_rounded,
        color: Color(0xFF2563EB),
        bgColor: Color(0xFFDBEAFE),
        route: AppRoutes.inventoryCheck),
    _QuickActionItem(
        label: 'Vị trí',
        icon: Icons.grid_view_rounded,
        color: Color(0xFF92400E),
        bgColor: Color(0xFFFEF3C7),
        route: AppRoutes.warehouseLocations),
    _QuickActionItem(
        label: 'Báo hỏng',
        icon: Icons.report_problem_rounded,
        color: Color(0xFFD94A45),
        bgColor: Color(0xFFFDECEB),
        route: AppRoutes.damageReportList),
    _QuickActionItem(
        label: 'NCC',
        icon: Icons.local_shipping_rounded,
        color: Color(0xFF0D9488),
        bgColor: Color(0xFFCCFBF1),
        route: AppRoutes.suppliers),
    _QuickActionItem(
        label: 'Khách',
        icon: Icons.groups_rounded,
        color: Color(0xFF4F46E5),
        bgColor: Color(0xFFE0E7FF),
        route: AppRoutes.customers),
    _QuickActionItem(
        label: 'Báo cáo',
        icon: Icons.bar_chart_rounded,
        color: Color(0xFF6366F1),
        bgColor: Color(0xFFE0E7FF),
        route: AppRoutes.reports),
    _QuickActionItem(
        label: 'Thêm',
        icon: Icons.more_horiz_rounded,
        color: Color(0xFF64748B),
        bgColor: Color(0xFFF1F5F9),
        route: AppRoutes.home),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.8,
      children: [
        for (final item in _actions) _ModernQuickActionButton(item: item),
      ],
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.route,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String route;
}

class _ModernQuickActionButton extends StatelessWidget {
  const _ModernQuickActionButton({required this.item});

  final _QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(item.route),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 26),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseStatus extends StatelessWidget {
  const _WarehouseStatus({
    required this.rices,
    required this.batchProvider,
  });

  final List<RiceModel> rices;
  final BatchProvider batchProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rices.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final rice = rices[index];
          final stock = batchProvider.totalStockForRice(rice.id);
          final bags = (stock / 50.0).round();
          final isLowStock = stock <= rice.minimumStock;
          final stockRatio = rice.minimumStock > 0
              ? (stock / (rice.minimumStock * 2)).clamp(0.0, 1.0)
              : 1.0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  rice.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quy cách: Bao 50kg • Tối thiểu: ${_formatQuantity(rice.minimumStock)} ${rice.unit}',
                            style: const TextStyle(
                              fontSize: 11.5,
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
                          '${_formatQuantity(stock)} ${rice.unit}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isLowStock
                                ? AppTheme.warningText
                                : AppTheme.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '~ $bags bao',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: stockRatio,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isLowStock
                                ? AppTheme.secondaryColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusChip(isLowStock: isLowStock),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Mini Activity Cards cho Biến động gần nhất
class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.activities});

  final List<_DashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: Text(
            'Chưa có giao dịch nhập xuất gần đây',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final activity in activities) ...[
          _MiniActivityCard(activity: activity),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MiniActivityCard extends StatelessWidget {
  const _MiniActivityCard({required this.activity});

  final _DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final isImport = activity.isImport;
    final accentColor =
        isImport ? AppTheme.primaryColor : AppTheme.secondaryColor;
    final bgColor = isImport ? AppTheme.primaryLight : AppTheme.secondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 1),
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
              isImport ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: accentColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isImport ? 'Nhập kho' : 'Xuất kho',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activity.code,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  activity.riceName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isImport ? '+' : '-'}${_formatQuantity(activity.quantity)} ${activity.unit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(activity.date),
                style: const TextStyle(
                  fontSize: 11,
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

class _DashboardActivity {
  const _DashboardActivity({
    required this.isImport,
    required this.code,
    required this.riceName,
    required this.quantity,
    required this.unit,
    required this.date,
  });

  final bool isImport;
  final String code;
  final String riceName;
  final double quantity;
  final String unit;
  final DateTime date;
}

List<_DashboardActivity> _getRecentActivities({
  required List<RiceModel> rices,
  required ImportProvider importProvider,
  required ExportProvider exportProvider,
}) {
  final unitsByRiceId = <String, String>{
    for (final rice in rices) rice.id: rice.unit,
  };
  final activities = <_DashboardActivity>[
    for (final receipt in importProvider.receipts)
      _DashboardActivity(
        isImport: true,
        code: receipt.code,
        riceName: receipt.riceName,
        quantity: receipt.quantity,
        unit: unitsByRiceId[receipt.riceId] ?? 'kg',
        date: receipt.date,
      ),
    for (final receipt in exportProvider.receipts)
      _DashboardActivity(
        isImport: false,
        code: receipt.code,
        riceName: receipt.riceName,
        quantity: receipt.quantity,
        unit: unitsByRiceId[receipt.riceId] ?? 'kg',
        date: receipt.date,
      ),
  ]..sort((first, second) => second.date.compareTo(first.date));

  return activities.take(5).toList(growable: false);
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return _withThousandsSeparator(value.toInt());
  }

  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _withThousandsSeparator(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }

  return buffer.toString();
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
