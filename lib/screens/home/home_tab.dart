import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';

/// =======================================================================
/// MÀN HÌNH BÀN LÀM VIỆC CHÍNH (HOME TAB / DASHBOARD)
/// Nâng cấp toàn diện cho môn Lập trình Giao diện:
/// - Nút Hero Banner tinh gọn: Bỏ sub-badge nhỏ, chỉ gồm Icon và Tên nút.
/// - Phần dưới nâng cấp phong phú: Mini Trend Chart 7 ngày, Top giống gạo,
///   khối Điều độ Bento Hub và Nhật ký biến động tương tác Modal.
/// - Responsive hoàn hảo, không bị tràn viền (320px+).
/// =======================================================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final riceProvider = context.watch<RiceProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final userName = context.watch<AuthProvider>().currentUser?.name ?? 'Admin';

    // 1. Thống kê kho & chuẩn FEFO
    final totalStockKg = batchProvider.totalStock;
    final totalTons = totalStockKg / 1000.0;
    const double warehouseMaxCapacityTons = 200.0;
    final capacityPercent = (totalTons / warehouseMaxCapacityTons).clamp(0.0, 1.0);

    final now = DateTime.now();
    final batches = batchProvider.batches;
    final availableBatches = batches.where((b) => b.status == BatchStatus.available && b.expiryDate.isAfter(now)).length;
    final nearExpiryBatches = batches.where((b) => b.expiryDate.isAfter(now) && b.expiryDate.difference(now).inDays <= 30).length;
    final expiredBatches = batches.where((b) => b.status == BatchStatus.expired || b.expiryDate.isBefore(now)).length;

    // 2. Thống kê Nhập / Xuất hôm nay
    final todayImportList = importProvider.receipts.where((r) => _isToday(r.date)).toList();
    final todayImportCount = todayImportList.length;
    final todayImportKg = todayImportList.fold(0.0, (sum, r) => sum + r.quantity);
    final alertImportsCount = alertProvider.alerts.where((a) => a.title.contains('nhập') || a.message.contains('nhập')).length;

    final todayExportList = exportProvider.receipts.where((r) => _isToday(r.date)).toList();
    final todayExportCount = todayExportList.length;
    final todayExportKg = todayExportList.fold(0.0, (sum, r) => sum + r.quantity);
    final alertExportsCount = alertProvider.alerts.where((a) => a.title.contains('xuất') || a.message.contains('xuất')).length;

    // 3. Biến động giao dịch gần đây & Top giống gạo
    final recentActivities = _getRecentActivities(
      rices: riceProvider.rices,
      importProvider: importProvider,
      exportProvider: exportProvider,
    );

    final topRices = _getTopStockRices(riceProvider.rices, batchProvider);

    // 4. Dữ liệu biểu đồ 7 ngày gần nhất
    final weekChartData = _getWeekChartData(importProvider.receipts, exportProvider.receipts);

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async => _syncMetrics(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER CHÀO HỎI & STATUS ONLINE
            _GreetingHeader(userName: userName)
                .animate()
                .fadeIn(duration: 250.ms),

            const SizedBox(height: 14),

            // 2. HERO BANNER THAO TÁC NHANH (ĐÃ BỎ CÁC SUB-BADGE NHỎ)
            _HeroQuickActionsBanner(
              onImport: () => Navigator.pushNamed(context, AppRoutes.addImport),
              onExport: () => Navigator.pushNamed(context, AppRoutes.addExport),
              onScanQr: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
              onInventoryCheck: () => Navigator.pushNamed(context, AppRoutes.inventoryCheck),
            )
                .animate()
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 18),

            // 3. THẺ THỐNG KÊ TỔNG QUAN TỒN KHO & TIÊU CHUẨN FEFO
            _WarehouseKpiCard(
              totalTons: totalTons,
              capacityPercent: capacityPercent,
              availableBatches: availableBatches,
              nearExpiryBatches: nearExpiryBatches,
              expiredBatches: expiredBatches,
              onViewBatches: () => Navigator.pushNamed(context, AppRoutes.batches),
              onViewInventory: () => Navigator.pushNamed(context, AppRoutes.inventory),
            )
                .animate()
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // 4. BIỂU ĐỒ MINI XU HƯỚNG 7 NGÀY (GIAO DIỆN PHONG PHÚ)
            _MiniWeeklyTrendCard(
              chartData: weekChartData,
              onViewReports: () => Navigator.pushNamed(context, AppRoutes.reports),
            )
                .animate()
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // 5. KHỐI ĐIỀU ĐỘ GIAO DỊCH HÔM NAY (BENTO HUB)
            _DispatchHubSection(
              todayImportCount: todayImportCount,
              todayImportKg: todayImportKg,
              alertImportsCount: alertImportsCount,
              todayExportCount: todayExportCount,
              todayExportKg: todayExportKg,
              alertExportsCount: alertExportsCount,
              onTapImport: () => Navigator.pushNamed(context, AppRoutes.import),
              onTapExport: () => Navigator.pushNamed(context, AppRoutes.export),
            )
                .animate()
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // 6. THẺ TOP GIỐNG GẠO TỒN KHO NHIỀU NHẤT
            if (topRices.isNotEmpty) ...[
              _TopStockRiceCard(
                topRices: topRices,
                onViewAllRices: () => Navigator.pushNamed(context, AppRoutes.rice),
              )
                  .animate()
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 20),
            ],

            // 7. DANH SÁCH BIẾN ĐỘNG GẦN ĐÂY VỚI MODAL CHI TIẾT
            _RecentActivitySection(
              activities: recentActivities,
              onViewAll: () => Navigator.pushNamed(context, AppRoutes.import),
            )
                .animate()
                .fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 1: HEADER CHÀO HỎI & STATUS CA LÀM VIỆC (RESPONSIVE)
/// -----------------------------------------------------------------------
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdayNames = ['Hai', 'Ba', 'Tư', 'Năm', 'Sáu', 'Bảy', 'Chủ Nhật'];
    final weekdayStr = 'Thứ ${weekdayNames[now.weekday - 1]}';
    final dateStr = '$weekdayStr, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.person_rounded, color: Colors.white, size: 24),
          ),
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
                      'Xin chào, $userName',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.waving_hand_rounded, size: 14, color: Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Kho Online',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 2: HERO BANNER THAO TÁC NHANH (ĐÃ BỎ HẾT SUB-BADGE / CHIP CON)
/// Chỉ gồm Icon to rõ và Tên nút sạch sẽ!
/// -----------------------------------------------------------------------
class _HeroQuickActionsBanner extends StatelessWidget {
  const _HeroQuickActionsBanner({
    required this.onImport,
    required this.onExport,
    required this.onScanQr,
    required this.onInventoryCheck,
  });

  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onScanQr;
  final VoidCallback onInventoryCheck;

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
                  'TÁC VỤ KHO NHANH',
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
                  'Phím tắt',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Nhập kho',
                  onTap: onImport,
                ),
              ),
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.outbox_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  label: 'Xuất kho',
                  onTap: onExport,
                ),
              ),
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Quét QR',
                  onTap: onScanQr,
                ),
              ),
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.fact_check_rounded,
                  iconColor: const Color(0xFF6366F1),
                  label: 'Kiểm kê',
                  onTap: onInventoryCheck,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 3: THẺ THỐNG KÊ TỒN KHO & TIÊU CHUẨN FEFO
/// -----------------------------------------------------------------------
class _WarehouseKpiCard extends StatelessWidget {
  const _WarehouseKpiCard({
    required this.totalTons,
    required this.capacityPercent,
    required this.availableBatches,
    required this.nearExpiryBatches,
    required this.expiredBatches,
    required this.onViewBatches,
    required this.onViewInventory,
  });

  final double totalTons;
  final double capacityPercent;
  final int availableBatches;
  final int nearExpiryBatches;
  final int expiredBatches;
  final VoidCallback onViewBatches;
  final VoidCallback onViewInventory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.analytics_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Hiện trạng Tồn kho & FEFO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewInventory,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Thẻ kho',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          totalTons.toStringAsFixed(1),
                          style: AppTheme.tabularFigures(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Tấn',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lấp đầy: ${(capacityPercent * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: capacityPercent,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                capacityPercent > 0.85 ? AppTheme.dangerColor : AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FefoMiniPill(
                  label: 'Sẵn sàng',
                  count: availableBatches,
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                  onTap: onViewBatches,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FefoMiniPill(
                  label: 'Cận hạn 30d',
                  count: nearExpiryBatches,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  onTap: onViewBatches,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FefoMiniPill(
                  label: 'Quá hạn',
                  count: expiredBatches,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                  borderColor: const Color(0xFFFECACA),
                  onTap: onViewBatches,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FefoMiniPill extends StatelessWidget {
  const _FefoMiniPill({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count Lô',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85),
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
/// WIDGET 4: BIỂU ĐỒ MINI XU HƯỚNG 7 NGÀY (MINI TREND CHART)
/// -----------------------------------------------------------------------
class _MiniWeeklyTrendCard extends StatelessWidget {
  const _MiniWeeklyTrendCard({
    required this.chartData,
    required this.onViewReports,
  });

  final List<_DayFlowData> chartData;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    final maxVal = chartData.fold<double>(0.0, (curr, d) => math.max(curr, math.max(d.importKg, d.exportKg)));
    final safeMax = maxVal <= 0 ? 1000.0 : maxVal * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Biến động Xuất / Nhập 7 ngày qua',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewReports,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _indicatorItem(AppTheme.primaryColor, 'Nhập kho (kg)'),
              _indicatorItem(const Color(0xFFD97706), 'Xuất kho (kg)'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: safeMax,
                barTouchData: const BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= chartData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            chartData[idx].dayLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < chartData.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: chartData[i].importKg,
                          color: AppTheme.primaryColor,
                          width: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: chartData[i].exportKg,
                          color: const Color(0xFFD97706),
                          width: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicatorItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 5: KHỐI ĐIỀU ĐỘ GIAO DỊCH HÔM NAY (BENTO HUB)
/// -----------------------------------------------------------------------
class _DispatchHubSection extends StatelessWidget {
  const _DispatchHubSection({
    required this.todayImportCount,
    required this.todayImportKg,
    required this.alertImportsCount,
    required this.todayExportCount,
    required this.todayExportKg,
    required this.alertExportsCount,
    required this.onTapImport,
    required this.onTapExport,
  });

  final int todayImportCount;
  final double todayImportKg;
  final int alertImportsCount;
  final int todayExportCount;
  final double todayExportKg;
  final int alertExportsCount;
  final VoidCallback onTapImport;
  final VoidCallback onTapExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Điều độ Giao dịch Hôm nay',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DispatchCard(
                title: 'Nhập kho',
                count: todayImportCount,
                quantityKg: todayImportKg,
                alertCount: alertImportsCount,
                icon: Icons.south_west_rounded,
                accentColor: AppTheme.primaryColor,
                lightColor: AppTheme.primaryLight,
                onTap: onTapImport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DispatchCard(
                title: 'Xuất kho',
                count: todayExportCount,
                quantityKg: todayExportKg,
                alertCount: alertExportsCount,
                icon: Icons.north_east_rounded,
                accentColor: const Color(0xFFD97706),
                lightColor: const Color(0xFFFEF3C7),
                onTap: onTapExport,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({
    required this.title,
    required this.count,
    required this.quantityKg,
    required this.alertCount,
    required this.icon,
    required this.accentColor,
    required this.lightColor,
    required this.onTap,
  });

  final String title;
  final int count;
  final double quantityKg;
  final int alertCount;
  final IconData icon;
  final Color accentColor;
  final Color lightColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quantityText = quantityKg >= 1000
        ? '${(quantityKg / 1000).toStringAsFixed(1)} Tấn'
        : '${quantityKg.toInt()} kg';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
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
                    color: lightColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const Spacer(),
                if (alertCount > 0)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$alertCount lưu ý',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '$count',
                  style: AppTheme.tabularFigures(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 3),
                const Text(
                  'phiếu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Tổng: $quantityText',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
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
/// WIDGET 6: THẺ TOP GIỐNG GẠO TỒN KHO NHIỀU NHẤT
/// -----------------------------------------------------------------------
class _TopStockRiceCard extends StatelessWidget {
  const _TopStockRiceCard({
    required this.topRices,
    required this.onViewAllRices,
  });

  final List<_RiceStockSummary> topRices;
  final VoidCallback onViewAllRices;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.rice_bowl_outlined, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Top Giống Gạo Tồn Kho Lớn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewAllRices,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Danh mục',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < topRices.length; i++) ...[
            _topRiceRow(topRices[i], i + 1),
            if (i < topRices.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _topRiceRow(_RiceStockSummary item, int rank) {
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFFD97706),
      const Color(0xFF2563EB),
    ];
    final color = colors[(rank - 1) % colors.length];

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Mã: ${item.code}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${NumberFormatter.quantity(item.stockKg)} ${item.unit}',
              style: AppTheme.tabularFigures(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 7: DANH SÁCH BIẾN ĐỘNG GẦN ĐÂY VỚI MODAL CHI TIẾT
/// -----------------------------------------------------------------------
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.activities,
    required this.onViewAll,
  });

  final List<_DashboardActivity> activities;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Biến động Gần đây',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Center(
              child: Text(
                'Chưa có giao dịch nhập xuất nào gần đây',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final activity in activities) ...[
                _ActivityItemCard(activity: activity),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _ActivityItemCard extends StatelessWidget {
  const _ActivityItemCard({required this.activity});

  final _DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final isImport = activity.isImport;
    final color = isImport ? AppTheme.primaryColor : const Color(0xFFD97706);
    final bgColor = isImport ? AppTheme.primaryLight : const Color(0xFFFEF3C7);
    final formattedDate = DateFormatter.ddMMyyyy(activity.date);

    return InkWell(
      onTap: () => _showActivityDetailSheet(context, activity),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                isImport ? Icons.south_west_rounded : Icons.north_east_rounded,
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
                    activity.riceName,
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
                    '${activity.code} • $formattedDate',
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
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isImport ? "+" : "-"}${NumberFormatter.quantity(activity.quantity)} ${activity.unit}',
                  style: AppTheme.tabularFigures(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityDetailSheet(BuildContext context, _DashboardActivity activity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final isImport = activity.isImport;
        final color = isImport ? AppTheme.primaryColor : const Color(0xFFD97706);

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isImport ? AppTheme.primaryLight : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isImport ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isImport ? 'Phiếu Nhập Kho' : 'Phiếu Xuất Kho',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Mã: ${activity.code}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow('Loại gạo', activity.riceName),
              const SizedBox(height: 8),
              _detailRow(
                'Khối lượng',
                '${NumberFormatter.quantity(activity.quantity)} ${activity.unit}',
                valueColor: color,
                isBold: true,
              ),
              const SizedBox(height: 8),
              _detailRow('Thời gian', DateFormatter.ddMMyyyy(activity.date)),
              const SizedBox(height: 8),
              _detailRow('Trạng thái', 'Đã ghi nhận', valueColor: AppTheme.primaryColor),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// DATA MODELS & HELPERS
/// -----------------------------------------------------------------------
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

class _DayFlowData {
  const _DayFlowData({
    required this.dayLabel,
    required this.importKg,
    required this.exportKg,
  });

  final String dayLabel;
  final double importKg;
  final double exportKg;
}

class _RiceStockSummary {
  const _RiceStockSummary({
    required this.name,
    required this.code,
    required this.stockKg,
    required this.unit,
  });

  final String name;
  final String code;
  final double stockKg;
  final String unit;
}

List<_DayFlowData> _getWeekChartData(
  List<dynamic> importReceipts,
  List<dynamic> exportReceipts,
) {
  final now = DateTime.now();
  final list = <_DayFlowData>[];

  for (var i = 6; i >= 0; i--) {
    final d = now.subtract(Duration(days: i));
    final dayLabel = i == 0 ? 'Nay' : 'T${d.weekday == 7 ? "CN" : (d.weekday + 1)}';

    final importKg = importReceipts.where((r) {
      final rd = r.date as DateTime;
      return rd.year == d.year && rd.month == d.month && rd.day == d.day;
    }).fold<double>(0.0, (s, r) => s + (r.quantity as double));

    final exportKg = exportReceipts.where((r) {
      final rd = r.date as DateTime;
      return rd.year == d.year && rd.month == d.month && rd.day == d.day;
    }).fold<double>(0.0, (s, r) => s + (r.quantity as double));

    list.add(_DayFlowData(
      dayLabel: dayLabel,
      importKg: importKg,
      exportKg: exportKg,
    ));
  }
  return list;
}

List<_RiceStockSummary> _getTopStockRices(
  List<RiceModel> rices,
  BatchProvider batchProvider,
) {
  final list = rices.where((r) => r.isActive).map((r) {
    return _RiceStockSummary(
      name: r.name,
      code: r.code,
      stockKg: batchProvider.totalStockForRice(r.id),
      unit: r.unit,
    );
  }).toList();

  list.sort((a, b) => b.stockKg.compareTo(a.stockKg));
  return list.take(3).toList();
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
