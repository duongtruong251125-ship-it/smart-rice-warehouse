import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/contracts/app_settings.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/services/dashboard_service.dart';
import 'package:smart_rice_warehouse/logic/view_models/dashboard_view_model.dart';
import 'package:smart_rice_warehouse/logic/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/pressable_scale.dart';

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
  late DashboardViewModel _viewModel;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMetrics();
    });
  }

  void _syncMetrics() {
    if (!mounted) return;
    DashboardViewModel.refresh(
      rices: context.read<RiceProvider>(),
      batches: context.read<BatchProvider>(),
      exports: context.read<ExportProvider>(),
      alerts: context.read<AlertProvider>(),
      forecasts: context.read<ForecastProvider>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = DashboardViewModel(
      rices: context.watch<RiceProvider>(),
      batches: context.watch<BatchProvider>(),
      imports: context.watch<ImportProvider>(),
      exports: context.watch<ExportProvider>(),
      alerts: context.watch<AlertProvider>(),
      backgroundSyncEnabled: context.watch<AppSettings?>()?.backgroundSync,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().currentUser?.name ?? 'Admin';
    final totalTons = _viewModel.totalTons;
    final capacityPercent = _viewModel.capacityPercent;
    final availableBatches = _viewModel.availableBatches;
    final nearExpiryBatches = _viewModel.nearExpiryBatches;
    final expiredBatches = _viewModel.expiredBatches;
    final todayImportCount = _viewModel.todayImportCount;
    final todayImportKg = _viewModel.todayImportKg;
    final alertImportsCount = _viewModel.alertImportsCount;
    final todayExportCount = _viewModel.todayExportCount;
    final todayExportKg = _viewModel.todayExportKg;
    final alertExportsCount = _viewModel.alertExportsCount;
    final recentActivities = _viewModel.recentActivities;
    final topRices = _viewModel.topRices;
    final weekChartData = _viewModel.weekChartData;

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async => _syncMetrics(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER CHÀO HỎI & STATUS ONLINE
            _GreetingHeader(
              userName: userName,
              syncStatus: _viewModel.syncStatus,
              onRetrySync: () => DashboardViewModel.retryAllSync(
                rices: context.read<RiceProvider>(),
                batches: context.read<BatchProvider>(),
                imports: context.read<ImportProvider>(),
                exports: context.read<ExportProvider>(),
              ),
            ).animate().fadeIn(duration: 250.ms),

            AsyncStatusBanner(
              isLoading:
                  _viewModel.syncStatus.state == WarehouseSyncState.syncing,
              errorMessage: _viewModel.syncStatus.hasError
                  ? _viewModel.syncStatus.detailMessage
                  : null,
              onRetry: () => DashboardViewModel.retryAllSync(
                rices: context.read<RiceProvider>(),
                batches: context.read<BatchProvider>(),
                imports: context.read<ImportProvider>(),
                exports: context.read<ExportProvider>(),
              ),
            ),

            const SizedBox(height: 14),

            // 2. HERO BANNER THAO TÁC NHANH (ĐÃ BỎ CÁC SUB-BADGE NHỎ)
            _HeroQuickActionsBanner(
              onImport: () => Navigator.pushNamed(context, AppRoutes.addImport),
              onExport: () => Navigator.pushNamed(context, AppRoutes.addExport),
              onScanQr: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
              onInventoryCheck: () =>
                  Navigator.pushNamed(context, AppRoutes.inventoryCheck),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 18),

            // 3. THẺ THỐNG KÊ TỔNG QUAN TỒN KHO & TIÊU CHUẨN FEFO
            _WarehouseKpiCard(
              totalTons: totalTons,
              capacityPercent: capacityPercent,
              availableBatches: availableBatches,
              nearExpiryBatches: nearExpiryBatches,
              expiredBatches: expiredBatches,
              onViewBatches: () =>
                  Navigator.pushNamed(context, AppRoutes.batches),
              onViewInventory: () =>
                  Navigator.pushNamed(context, AppRoutes.inventory),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // 4. BIỂU ĐỒ MINI XU HƯỚNG 7 NGÀY (GIAO DIỆN PHONG PHÚ)
            _MiniWeeklyTrendCard(
              chartData: weekChartData,
              onViewReports: () =>
                  Navigator.pushNamed(context, AppRoutes.reports),
            ).animate().fadeIn(duration: 300.ms),

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
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // 6. THẺ TOP GIỐNG GẠO TỒN KHO NHIỀU NHẤT
            if (topRices.isNotEmpty) ...[
              _TopStockRiceCard(
                topRices: topRices,
                onViewAllRices: () =>
                    Navigator.pushNamed(context, AppRoutes.rice),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 20),
            ],

            // 7. DANH SÁCH BIẾN ĐỘNG GẦN ĐÂY VỚI MODAL CHI TIẾT
            _RecentActivitySection(
              activities: recentActivities,
              onViewAll: () => Navigator.pushNamed(context, AppRoutes.import),
            ).animate().fadeIn(duration: 300.ms),
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
  const _GreetingHeader({
    required this.userName,
    required this.syncStatus,
    required this.onRetrySync,
  });

  final String userName;
  final WarehouseSyncStatus syncStatus;
  final VoidCallback onRetrySync;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdayNames = ['Hai', 'Ba', 'Tư', 'Năm', 'Sáu', 'Bảy', 'Chủ Nhật'];
    final weekdayStr = 'Thứ ${weekdayNames[now.weekday - 1]}';
    final isStaff = context.watch<AuthProvider?>()?.isStaff ?? false;
    final rolePrefix = isStaff ? 'Nhân viên kho' : 'Quản trị viên';
    final dateStr =
        '$rolePrefix • $weekdayStr, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final isDark = AppTheme.isDark(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                isDark ? AppTheme.darkHeroGradient : AppTheme.primaryGradient,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.waving_hand_rounded,
                      size: 14, color: Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SyncStatusBadge(
          status: syncStatus,
          onRetry: onRetrySync,
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
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient:
            isDark ? AppTheme.darkHeroGradient : AppTheme.heroEmeraldGradient,
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
    final isDark = AppTheme.isDark(context);

    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.94,
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
                color: isDark ? AppTheme.darkCardElevated : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isDark
                    ? Border.all(color: AppTheme.darkBorder, width: 1)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hiện trạng Tồn kho & FEFO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              InkWell(
                onTap: onViewInventory,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Thẻ kho',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkSafeText
                              : AppTheme.primaryColor,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkSafeText
                            : AppTheme.primaryColor,
                      ),
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
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tấn',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkCardElevated
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: isDark
                      ? Border.all(color: AppTheme.darkBorder, width: 1)
                      : null,
                ),
                child: Text(
                  'Lấp đầy: ${(capacityPercent * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryColor(context),
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
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                capacityPercent > 0.85
                    ? (isDark ? AppTheme.darkDangerText : AppTheme.dangerColor)
                    : (isDark ? AppTheme.darkSafeText : AppTheme.primaryColor),
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
                  color:
                      isDark ? AppTheme.darkSafeText : const Color(0xFF10B981),
                  bgColor:
                      isDark ? AppTheme.darkSafeBg : const Color(0xFFECFDF5),
                  borderColor: isDark
                      ? AppTheme.darkSafeBorder
                      : const Color(0xFFA7F3D0),
                  onTap: onViewBatches,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FefoMiniPill(
                  label: 'Cận hạn 30d',
                  count: nearExpiryBatches,
                  color: isDark
                      ? AppTheme.darkWarningText
                      : const Color(0xFFD97706),
                  bgColor:
                      isDark ? AppTheme.darkWarningBg : const Color(0xFFFFFBEB),
                  borderColor: isDark
                      ? AppTheme.darkWarningBorder
                      : const Color(0xFFFDE68A),
                  onTap: onViewBatches,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FefoMiniPill(
                  label: 'Quá hạn',
                  count: expiredBatches,
                  color: isDark
                      ? AppTheme.darkDangerText
                      : const Color(0xFFDC2626),
                  bgColor:
                      isDark ? AppTheme.darkDangerBg : const Color(0xFFFEF2F2),
                  borderColor: isDark
                      ? AppTheme.darkDangerBorder
                      : const Color(0xFFFECACA),
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
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.96,
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

  final List<DayFlowData> chartData;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final maxVal = chartData.fold<double>(
        0.0, (curr, d) => math.max(curr, math.max(d.importKg, d.exportKg)));
    final safeMax = maxVal <= 0 ? 1000.0 : maxVal * 1.2;

    final importColor =
        isDark ? const Color(0xFF34D399) : AppTheme.primaryColor;
    final exportColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Biến động Xuất / Nhập 7 ngày qua',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              InkWell(
                onTap: onViewReports,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkSafeText
                              : AppTheme.primaryColor,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkSafeText
                            : AppTheme.primaryColor,
                      ),
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
              _indicatorItem(context, importColor, 'Nhập kho (kg)'),
              _indicatorItem(context, exportColor, 'Xuất kho (kg)'),
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
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= chartData.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            chartData[idx].dayLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryColor(context),
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
                          color: importColor,
                          width: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: chartData[i].exportKg,
                          color: exportColor,
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

  Widget _indicatorItem(BuildContext context, Color color, String label) {
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
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondaryColor(context),
          ),
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
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Điều độ Giao dịch Hôm nay',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryColor(context),
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
                accentColor:
                    isDark ? const Color(0xFF34D399) : AppTheme.primaryColor,
                lightColor:
                    isDark ? AppTheme.darkSafeBg : AppTheme.primaryLight,
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
                accentColor:
                    isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                lightColor:
                    isDark ? AppTheme.darkWarningBg : const Color(0xFFFEF3C7),
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
    final isDark = AppTheme.isDark(context);
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
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
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
                    border: isDark
                        ? Border.all(
                            color: accentColor.withValues(alpha: 0.3), width: 1)
                        : null,
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const Spacer(),
                if (alertCount > 0)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkDangerBg
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: isDark
                            ? Border.all(
                                color: AppTheme.darkDangerBorder, width: 1)
                            : null,
                      ),
                      child: Text(
                        '$alertCount lưu ý',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkDangerText
                              : const Color(0xFFDC2626),
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
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
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'phiếu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
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

  final List<RiceStockSummary> topRices;
  final VoidCallback onViewAllRices;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rice_bowl_outlined,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Top Giống Gạo Tồn Kho Lớn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              InkWell(
                onTap: onViewAllRices,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Danh mục',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkSafeText
                              : AppTheme.primaryColor,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkSafeText
                            : AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < topRices.length; i++) ...[
            _topRiceRow(context, topRices[i], i + 1),
            if (i < topRices.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _topRiceRow(BuildContext context, RiceStockSummary item, int rank) {
    final isDark = AppTheme.isDark(context);
    final colors = [
      isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    ];
    final color = colors[(rank - 1) % colors.length];

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            shape: BoxShape.circle,
            border: isDark
                ? Border.all(color: color.withValues(alpha: 0.35), width: 1)
                : null,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: color),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Mã: ${item.code}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor(context),
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

  final List<DashboardActivity> activities;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Biến động Gần đây',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
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
              child: Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkSafeText : AppTheme.primaryColor,
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
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Center(
              child: Text(
                'Chưa có giao dịch nhập xuất nào gần đây',
                style: TextStyle(
                    color: AppTheme.textSecondaryColor(context),
                    fontSize: 12.5),
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

  final DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isImport = activity.isImport;
    final color = isImport
        ? (isDark ? const Color(0xFF34D399) : AppTheme.primaryColor)
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final bgColor = isImport
        ? (isDark ? AppTheme.darkSafeBg : AppTheme.primaryLight)
        : (isDark ? AppTheme.darkWarningBg : const Color(0xFFFEF3C7));
    final formattedDate = DateFormatter.ddMMyyyy(activity.date);

    return InkWell(
      onTap: () => _showActivityDetailSheet(context, activity),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
                border: isDark
                    ? Border.all(color: color.withValues(alpha: 0.35), width: 1)
                    : null,
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activity.code} • $formattedDate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
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

  void _showActivityDetailSheet(
      BuildContext context, DashboardActivity activity) {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final isImport = activity.isImport;
        final color = isImport
            ? (isDark ? const Color(0xFF34D399) : AppTheme.primaryColor)
            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
        final bgColor = isImport
            ? (isDark ? AppTheme.darkSafeBg : AppTheme.primaryLight)
            : (isDark ? AppTheme.darkWarningBg : const Color(0xFFFEF3C7));

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
                    color:
                        isDark ? const Color(0xFF334155) : Colors.grey.shade300,
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
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isDark
                          ? Border.all(
                              color: color.withValues(alpha: 0.35), width: 1)
                          : null,
                    ),
                    child: Icon(
                      isImport
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        Text(
                          'Mã: ${activity.code}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondaryColor(context),
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
              _detailRow(context, 'Loại gạo', activity.riceName),
              const SizedBox(height: 8),
              _detailRow(
                context,
                'Khối lượng',
                '${NumberFormatter.quantity(activity.quantity)} ${activity.unit}',
                valueColor: color,
                isBold: true,
              ),
              const SizedBox(height: 8),
              _detailRow(
                  context, 'Thời gian', DateFormatter.ddMMyyyy(activity.date)),
              const SizedBox(height: 8),
              _detailRow(
                context,
                'Trạng thái',
                'Đã ghi nhận',
                valueColor:
                    isDark ? AppTheme.darkSafeText : AppTheme.primaryColor,
              ),
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
                  child: const Text('Đóng',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12.5, color: AppTheme.textSecondaryColor(context)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------
/// DATA MODELS & HELPERS
/// -----------------------------------------------------------------------
