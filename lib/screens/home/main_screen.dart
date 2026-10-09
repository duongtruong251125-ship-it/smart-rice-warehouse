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
    'Nhập/Xuất',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.rice_bowl_rounded,
                size: 17,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _titles[_selectedIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quét mã QR Lô gạo',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.qrScanner),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          Consumer<AlertProvider>(
            builder: (context, alertProvider, _) {
              final unread = alertProvider.unreadCount;
              return IconButton(
                tooltip: 'Cảnh báo & Thông báo',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.alerts),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.borderColor, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Kho hàng',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Nhập/Xuất',
            ),
            NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined_rounded),
              selectedIcon: Icon(Icons.insert_chart_rounded),
              label: 'Báo cáo',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}

