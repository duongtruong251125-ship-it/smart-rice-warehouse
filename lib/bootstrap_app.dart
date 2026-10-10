import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_rice_warehouse/app.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';
import 'package:smart_rice_warehouse/core/services/settings_service.dart';

class WarehouseBootstrapApp extends StatefulWidget {
  const WarehouseBootstrapApp({super.key});

  @override
  State<WarehouseBootstrapApp> createState() => _WarehouseBootstrapAppState();
}

class _WarehouseBootstrapAppState extends State<WarehouseBootstrapApp> {
  late Future<({AppDatabase database, AppSnapshot snapshot, SettingsService settings})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({AppDatabase database, AppSnapshot snapshot, SettingsService settings})> _load() async {
    final settings = SettingsService();
    await settings.init();
    final database = await AppDatabase.open();
    final snapshot = await database.loadSnapshot();
    return (database: database, snapshot: snapshot, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({AppDatabase database, AppSnapshot snapshot, SettingsService settings})>(
      future: _future,
      builder: (context, state) {
        if (state.hasData) {
          return SmartRiceWarehouseApp(
            database: state.data!.database,
            settings: state.data!.settings,
            snapshot: state.data!.snapshot,
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: _BootstrapScreen(
            error: state.error,
            onRetry: () => setState(() => _future = _load()),
          ),
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded,
                      size: 44, color: AppTheme.dangerColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Không thể mở dữ liệu kho',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kiểm tra dung lượng thiết bị rồi thử lại.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử mở lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang mở kho trung tâm'),
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(Icons.warehouse_rounded, color: AppTheme.primaryColor),
          ),
        ),
      ),
      body: Skeletonizer(
        enabled: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tổng quan tồn kho hôm nay',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Container(
              height: 128,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tồn kho khả dụng'),
                  SizedBox(height: 10),
                  Text('12.450 kg',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Đang đối chiếu dữ liệu lô và hạn sử dụng'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Các lô gần đây',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (var index = 0; index < 4; index++) ...[
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.inventory_2_rounded),
                  ),
                  title: Text('LO-ST25-00${index + 1}'),
                  subtitle: const Text('Gạo ST25 • HSD 12/10/2027'),
                  trailing: const Text('500 kg'),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
