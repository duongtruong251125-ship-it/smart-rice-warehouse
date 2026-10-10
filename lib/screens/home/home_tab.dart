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
    final userName = context.watch<AuthProvider>().currentUser?.name ?? 'Admin';

    final today = DateTime.now();
    final totalStockKg = batchProvider.totalStock;

    // Quy đổi số liệu kho
    final totalTons = totalStockKg / 1000.0;
    final capacityRatio = totalStockKg / _warehouseCapacityKg;

    // Thống kê ngày hôm nay
    final todayImports = importProvider.receipts
        .where((r) =>
            r.date.year == today.year &&
            r.date.month == today.month &&
            r.date.day == today.day)
        .toList(growable: false);
    final todayImportKg = todayImports.fold(0.0, (sum, r) => sum + r.quantity);

    final todayExports = exportProvider.receipts
        .where((r) =>
            r.date.year == today.year &&
            r.date.month == today.month &&
            r.date.day == today.day)
        .toList(growable: false);
    final todayExportKg = todayExports.fold(0.0, (sum, r) => sum + r.quantity);

    final recentActivities = _getRecentActivities(
      rices: riceProvider.rices,
      importProvider: importProvider,
      exportProvider: exportProvider,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER XINH ĐẸP CÓ GRADIENT
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, $userName 👋',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sẵn sàng quản lý kho!',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF0F766E), size: 30),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // THẺ TỔNG QUAN TỒN KHO NỔI TRÊN NỀN GRADIENT
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F766E), size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tổng Tồn Kho Hiện Tại', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '${totalTons.toStringAsFixed(1)} Tấn',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION: CHỨC NĂNG NHANH (QUICK ACTIONS)
                const Text(
                  'Thao tác nhanh',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                const _ModernQuickActionsGrid(),
                
                const SizedBox(height: 32),
                
                // SECTION: CẢNH BÁO QUAN TRỌNG
                if (alertProvider.alerts.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cần chú ý',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.alerts),
                        child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Có ${alertProvider.alerts.length} cảnh báo về kho',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Gạo sắp hết hạn hoặc tồn kho dưới mức tối thiểu. Hãy kiểm tra ngay!',
                                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // SECTION: HOẠT ĐỘNG GẦN ĐÂY
                const Text(
                  'Hoạt động gần đây',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                _RecentActivityList(activities: recentActivities),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
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





class _ModernQuickActionsGrid extends StatelessWidget {
  const _ModernQuickActionsGrid();

  static const _actions = [
    _QuickActionItem(label: 'Nhập kho', icon: Icons.south_west_rounded, color: Color(0xFF0F766E), bgColor: Color(0xFFCCFBF1), route: AppRoutes.addImport),
    _QuickActionItem(label: 'Xuất kho', icon: Icons.north_east_rounded, color: Color(0xFFD97706), bgColor: Color(0xFFFEF3C7), route: AppRoutes.addExport),
    _QuickActionItem(label: 'Quét QR', icon: Icons.qr_code_scanner_rounded, color: Color(0xFF0F172A), bgColor: Color(0xFFE2E8F0), route: AppRoutes.qrScanner),
    _QuickActionItem(label: 'Kiểm kê', icon: Icons.fact_check_rounded, color: Color(0xFF2563EB), bgColor: Color(0xFFDBEAFE), route: AppRoutes.inventoryCheck),
    _QuickActionItem(label: 'Thống kê', icon: Icons.bar_chart_rounded, color: Color(0xFF9333EA), bgColor: Color(0xFFF3E8FF), route: AppRoutes.reports),
    _QuickActionItem(label: 'Mở rộng', icon: Icons.widgets_rounded, color: Color(0xFFEC4899), bgColor: Color(0xFFFCE7F3), route: AppRoutes.home),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final item = _actions[index];
        return InkWell(
          onTap: () {
            if (item.route == AppRoutes.home) {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('Công cụ mở rộng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.person, color: Color(0xFF0F766E)),
                        title: const Text('Tài khoản cá nhân'),
                        onTap: () { Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.profile); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.category_rounded, color: Color(0xFF9333EA)),
                        title: const Text('Quản lý Lô hàng'),
                        onTap: () { Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.batches); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.local_shipping_rounded, color: Color(0xFFD97706)),
                        title: const Text('Nhà cung cấp'),
                        onTap: () { Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.suppliers); },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            } else {
              Navigator.of(context).pushNamed(item.route);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: item.bgColor, shape: BoxShape.circle),
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({required this.label, required this.icon, required this.color, required this.bgColor, required this.route});
  final String label; final IconData icon; final Color color; final Color bgColor; final String route;
}
