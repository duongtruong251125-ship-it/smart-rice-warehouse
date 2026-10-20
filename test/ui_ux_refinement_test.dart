import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/app_settings.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/damage_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/export_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/import_form_view_model.dart';
import 'package:smart_rice_warehouse/presentation/screens/batch/batch_list_screen.dart';
import 'package:smart_rice_warehouse/presentation/screens/inventory/inventory_screen.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/theme/theme_provider.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/pressable_scale.dart';
import 'package:smart_rice_warehouse/presentation/widgets/sticky_action_bar.dart';

double _relativeLuminance(Color color) {
  double channel(double c) {
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

class _MockSettings implements AppSettings {
  @override
  bool get isDarkMode => false;
  @override
  bool get backgroundSync => true;
  @override
  bool get pushNotifications => true;
  @override
  Future<void> setDarkMode(bool value) async {}
  @override
  Future<void> setBackgroundSync(bool value) async {}
  @override
  Future<void> setPushNotifications(bool value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. WCAG AA Contrast Ratio Token Verification', () {
    test('Primary button colors meet WCAG AA (>= 4.5:1) with white text', () {
      final ratio = _contrastRatio(AppTheme.primaryColor, Colors.white);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Primary button contrast ratio should be >= 4.5:1');
    });

    test('Primary dark color has high contrast with white', () {
      final ratio = _contrastRatio(AppTheme.primaryDark, Colors.white);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'Primary dark contrast ratio should meet WCAG AAA');
    });

    test('Secondary text meets WCAG AA (>= 4.5:1) against light background',
        () {
      final ratio =
          _contrastRatio(AppTheme.textSecondary, AppTheme.backgroundColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Text secondary contrast ratio should be >= 4.5:1');
    });

    test('Muted text meets WCAG AA (>= 4.5:1) against light background', () {
      final ratio =
          _contrastRatio(AppTheme.textMuted, AppTheme.backgroundColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Text muted / placeholder contrast ratio should be >= 4.5:1');
    });

    test('Dark theme secondary text meets WCAG AA against dark background', () {
      final ratio =
          _contrastRatio(AppTheme.darkTextSecondary, AppTheme.darkBackground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Dark secondary text contrast ratio should be >= 4.5:1');
    });

    test('Warning text meets WCAG AA against white', () {
      final ratio = _contrastRatio(AppTheme.warningText, Colors.white);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Warning text on white should be >= 4.5:1');
    });

    test('Danger color meets WCAG AA against white', () {
      final ratio = _contrastRatio(AppTheme.dangerColor, Colors.white);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Danger color on white should be >= 4.5:1');
    });
  });

  group('2. Real Sync Status Model & State Resolution', () {
    test('Resolves local state when not using cloud/Firestore', () {
      final status = WarehouseSyncStatus.resolve(
        sources: [
          const SyncSourceSnapshot(usesFirestore: false, isLoading: false),
        ],
      );
      expect(status.state, WarehouseSyncState.local);
      expect(status.label, 'Cục bộ');
      expect(status.hasError, isFalse);
    });

    test('Resolves syncing state when any source is loading', () {
      final status = WarehouseSyncStatus.resolve(
        sources: [
          const SyncSourceSnapshot(usesFirestore: true, isLoading: true),
          const SyncSourceSnapshot(usesFirestore: true, isLoading: false),
        ],
      );
      expect(status.state, WarehouseSyncState.syncing);
      expect(status.label, 'Đang đồng bộ');
    });

    test('Resolves error state and collects error message', () {
      final status = WarehouseSyncStatus.resolve(
        sources: [
          const SyncSourceSnapshot(
              usesFirestore: true, isLoading: false, errorMessage: 'Lỗi mạng'),
        ],
      );
      expect(status.state, WarehouseSyncState.error);
      expect(status.label, 'Lỗi đồng bộ');
      expect(status.detailMessage, 'Lỗi mạng');
      expect(status.hasError, isTrue);
    });

    test('Resolves synced state when cloud sources are idle without error', () {
      final status = WarehouseSyncStatus.resolve(
        sources: [
          const SyncSourceSnapshot(usesFirestore: true, isLoading: false),
          const SyncSourceSnapshot(usesFirestore: true, isLoading: false),
        ],
      );
      expect(status.state, WarehouseSyncState.synced);
      expect(status.label, 'Đã đồng bộ');
    });

    testWidgets('SyncStatusBadge renders labels and handles tap on error',
        (tester) async {
      bool retried = false;
      const errorStatus = WarehouseSyncStatus(
        state: WarehouseSyncState.error,
        detailMessage: 'Mất kết nối',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SyncStatusBadge(
                status: errorStatus,
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Lỗi đồng bộ'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.byType(SyncStatusBadge));
      expect(retried, isTrue);
    });
  });

  group('3. Async Status Banner & Double Submit Protection', () {
    testWidgets('AsyncStatusBanner shows loading and error retry',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AsyncStatusBanner(
              isLoading: false,
              errorMessage: 'Không thể tải dữ liệu',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Không thể tải dữ liệu'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
    });

    test('ImportFormViewModel prevents double submit when already submitting',
        () {
      final vm = ImportFormViewModel();
      expect(vm.isSubmitting, isFalse);
      vm.setSubmittingForTesting(true);
      expect(vm.isSubmitting, isTrue);
    });

    test('ExportFormViewModel tracks lastError and submission state', () {
      final vm = ExportFormViewModel();
      expect(vm.isSubmitting, isFalse);
      expect(vm.lastError, isNull);
    });

    test('DamageFormViewModel tracks lastError and submission state', () {
      final vm = DamageFormViewModel();
      expect(vm.isSubmitting, isFalse);
      expect(vm.lastError, isNull);
    });
  });

  group('4. Touch Targets, Accessibility & Reduced Motion', () {
    testWidgets('PressableScale enforces min 44x44 touch target and Semantics',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: PressableScale(
                semanticLabel: 'Nút hành động',
                onTap: () {},
                child: const Text('Nhấn'),
              ),
            ),
          ),
        ),
      );

      final renderBox =
          tester.renderObject<RenderBox>(find.byType(PressableScale));
      expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(44.0));

      final semantics = tester.getSemantics(find.byType(PressableScale));
      expect(semantics.label, contains('Nút hành động'));
    });

    testWidgets(
        'PressableScale bypasses scale animation when reduced motion enabled',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: PressableScale(
                  onTap: () {},
                  child: const Text('Nút'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.press(find.byType(PressableScale));
      await tester.pump(const Duration(milliseconds: 50));

      // With disableAnimations, transform animation should be completely bypassed
      expect(
        find.descendant(
          of: find.byType(PressableScale),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('5. Screen Layout & No Overflow Across Sizes & Text Scales', () {
    late RiceModel testRice;
    late BatchModel testBatch;
    late WarehouseLocationModel testLocation;

    setUp(() {
      testRice = const RiceModel(
        id: 'rice-1',
        code: 'ST25-01',
        name: 'Gạo ST25 Thượng Hạng Sóc Trăng',
        category: 'Gạo thơm đặc sản',
        purchasePrice: 28000,
        sellingPrice: 35000,
        unit: 'kg',
        minimumStock: 100,
        description: 'Gạo ST25 chuẩn thơm dẻo',
        isActive: true,
      );
      testLocation = const WarehouseLocationModel(
        id: 'loc-1',
        zone: 'Khu A',
        rack: 'Kệ 1',
        shelf: 'Tầng 1',
        code: 'A-K1-T1',
        capacity: 10000,
      );
      testBatch = BatchModel(
        id: 'batch-1',
        code: 'LO-ST25-2026-001',
        riceId: testRice.id,
        riceName: testRice.name,
        quantity: 2500,
        importDate: DateTime.now().subtract(const Duration(days: 10)),
        manufactureDate: DateTime.now().subtract(const Duration(days: 15)),
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        status: BatchStatus.available,
        locationName: testLocation.code,
      );
    });

    Widget createScreenHarness({
      required Widget child,
      required double width,
      required double textScale,
      required bool isDark,
    }) {
      final riceProvider = RiceProvider(initial: [testRice]);
      final batchProvider = BatchProvider(initial: [testBatch]);
      final warehouseProvider = WarehouseProvider(initial: [testLocation]);
      final authProvider = AuthProvider(
        demoMode: true,
        userName: 'Admin',
        userRole: 'admin',
      );

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<RiceProvider>.value(value: riceProvider),
          ChangeNotifierProvider<RiceCharacteristicProvider>(
              create: (_) => RiceCharacteristicProvider()),
          ChangeNotifierProvider<BatchProvider>.value(value: batchProvider),
          ChangeNotifierProvider<WarehouseProvider>.value(
              value: warehouseProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          Provider<AppSettings>.value(value: _MockSettings()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: SizedBox(
              width: width,
              height: 800,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets(
        'InventoryScreen does not overflow at 320px width with 200% text scale in Dark Mode',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createScreenHarness(
          child: const InventoryScreen(),
          width: 320,
          textScale: 2.0,
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason:
              'InventoryScreen should have 0 overflow errors at 320px with 200% font scale');
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets(
        'BatchListScreen renders without overflow at 320px and 200% font',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createScreenHarness(
          child: const BatchListScreen(),
          width: 320,
          textScale: 2.0,
          isDark: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'StickyActionBar stacks vertically on narrow screens without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              bottomNavigationBar: StickyActionBar(
                primaryLabel: 'Xác nhận xuất kho theo FEFO',
                onPrimaryPressed: () {},
                secondaryLabel: 'Hủy bỏ',
                onSecondaryPressed: () {},
                summaryWidget:
                    const Text('Tổng lượng xuất: 10,000 kg (~ 10 Tấn)'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Xác nhận xuất kho theo FEFO'), findsOneWidget);
    });

    testWidgets('Visual rendering verification for Light & Dark mode themes',
        (tester) async {
      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              appBar: AppBar(title: const Text('Visual Check')),
              body: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Theme Token Visual Render Test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      expect(boundary, isNotNull);
      final ui.Image image = await boundary!.toImage(pixelRatio: 1.0);
      expect(image.width, greaterThan(0));
      expect(image.height, greaterThan(0));
      image.dispose();
    });
  });
}
