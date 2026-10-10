import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/screens/home/home_tab.dart';
import 'package:smart_rice_warehouse/screens/import/import_export_hub.dart';
import 'package:smart_rice_warehouse/screens/inventory/warehouse_hub.dart';
import 'package:smart_rice_warehouse/screens/profile/profile_tab.dart';
import 'package:smart_rice_warehouse/screens/reports/reports_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _titles = <String>[
    'Trang chủ',
    'Kho hàng',
    'Nhập / Xuất',
    'Báo cáo',
    'Tài khoản',
  ];

  static const _tabs = <Widget>[
    HomeTab(),
    WarehouseHub(),
    ImportExportHub(),
    ReportsTab(),
    ProfileTab(),
  ];

  int _selectedIndex = 0;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alertProvider = context.read<AlertProvider>();
      final unreadAlerts = alertProvider.alerts.where((a) => !a.isRead).toList();
      if (unreadAlerts.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Có thông báo mới!'),
              ],
            ),
            content: Text('Bạn có ${unreadAlerts.length} cảnh báo chưa đọc (Hàng sắp hết, sắp hết hạn, v.v.). Vui lòng kiểm tra!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.alerts);
                },
                child: const Text('Xem ngay'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warehouse_rounded,
                size: 22,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'KHO TRUNG TÂM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _titles[_selectedIndex],
                      key: ValueKey<String>(_titles[_selectedIndex]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quét mã QR Lô gạo',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.qrScanner),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 19,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Consumer<AlertProvider>(
            builder: (context, alertProvider, _) {
              final unread = alertProvider.unreadCount;
              return IconButton(
                tooltip: 'Cảnh báo & Thông báo',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.alerts),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(
                      '$unread',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    backgroundColor: AppTheme.dangerColor,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 19,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 15,
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -3),
            )
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFCCFBF1), // AppTheme.primaryLight
            indicatorShape: const CircleBorder(),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E));
              }
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF0F766E), size: 26);
              }
              return const IconThemeData(color: Colors.grey, size: 24);
            }),
          ),
          child: NavigationBar(
            height: 60,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Kho hàng'),
              NavigationDestination(icon: Icon(Icons.sync_alt_rounded), selectedIcon: Icon(Icons.sync_alt_rounded), label: 'Giao dịch'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Báo cáo'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Tài khoản'),
            ],
          ),
        ),
      ),
    );
  }
}