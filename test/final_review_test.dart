import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/core/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/app.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';

void main() {
  test('all declared application routes are registered', () {
    const expectedRoutes = <String>{
      AppRoutes.splash,
      AppRoutes.login,
      AppRoutes.home,
      AppRoutes.rice,
      AppRoutes.addRice,
      AppRoutes.editRice,
      AppRoutes.suppliers,
      AppRoutes.addSupplier,
      AppRoutes.editSupplier,
      AppRoutes.customers,
      AppRoutes.addCustomer,
      AppRoutes.editCustomer,
      AppRoutes.batches,
      AppRoutes.import,
      AppRoutes.addImport,
      AppRoutes.export,
      AppRoutes.addExport,
      AppRoutes.inventory,
      AppRoutes.reports,
      AppRoutes.profile,
    };

    expect(AppRoutes.routes.keys.toSet(), expectedRoutes);
  });

  test('authentication and CRUD providers preserve expected behavior', () {
    final authProvider = AuthProvider();
    expect(
      authProvider.login(email: 'admin@gmail.com', password: 'wrong-password'),
      isFalse,
    );
    expect(
      authProvider.login(email: 'ADMIN@gmail.com', password: '123456'),
      isTrue,
    );
    authProvider.logout();
    expect(authProvider.isLoggedIn, isFalse);

    final riceProvider = RiceProvider();
    final riceTemplate = riceProvider.rices.first;
    final rice = riceTemplate.copyWith(
      id: 'rice-review',
      code: 'REVIEW',
      name: 'Gạo kiểm thử',
    );
    expect(riceProvider.addRice(rice), isTrue);
    expect(riceProvider.addRice(rice.copyWith(id: 'duplicate')), isFalse);
    expect(riceProvider.searchRice('kiểm thử'), contains(rice));
    expect(
      riceProvider.updateRice(rice.copyWith(name: 'Gạo đã cập nhật')),
      isTrue,
    );
    expect(riceProvider.deleteRice(rice.id), isTrue);

    final supplierProvider = SupplierProvider();
    final supplier = supplierProvider.suppliers.first.copyWith(
      id: 'supplier-review',
      name: 'Nhà cung cấp kiểm thử',
    );
    supplierProvider.addSupplier(supplier);
    expect(supplierProvider.searchSuppliers('kiểm thử'), contains(supplier));
    expect(
      supplierProvider.updateSupplier(supplier.copyWith(phone: '0900000000')),
      isTrue,
    );
    expect(supplierProvider.deleteSupplier(supplier.id), isTrue);

    final customerProvider = CustomerProvider();
    final customer = customerProvider.customers.first.copyWith(
      id: 'customer-review',
      name: 'Khách hàng kiểm thử',
    );
    customerProvider.addCustomer(customer);
    expect(customerProvider.searchCustomers('kiểm thử'), contains(customer));
    expect(
      customerProvider.updateCustomer(customer.copyWith(phone: '0911111111')),
      isTrue,
    );
    expect(customerProvider.deleteCustomer(customer.id), isTrue);
  });

  testWidgets('splash, login and five-tab navigation work on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final batchProvider = BatchProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => RiceProvider()),
          ChangeNotifierProvider(create: (_) => SupplierProvider()),
          ChangeNotifierProvider(create: (_) => CustomerProvider()),
          ChangeNotifierProvider.value(value: batchProvider),
          ChangeNotifierProvider(
            create: (_) => ImportProvider(batchProvider, null),
          ),
          ChangeNotifierProvider(
            create: (_) => ExportProvider(batchProvider, null),
          ),
        ],
        child: SmartRiceWarehouseApp(settings: SettingsService()),
      ),
    );

    expect(find.text('Smart Rice Warehouse'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);
    final loginLayoutException = tester.takeException();
    expect(
      loginLayoutException,
      isNull,
      reason: 'The login screen must fit a 320px-wide screen.',
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin@gmail.com');
    await tester.enterText(fields.at(1), '123456');
    final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Xin chào, Admin'), findsOneWidget);
    final initialLayoutException = tester.takeException();
    expect(
      initialLayoutException,
      isNull,
      reason: 'The initial home tab must fit a 320px-wide screen.',
    );

    for (final label in <String>[
      'Kho hàng',
      'Nhập/Xuất',
      'Báo cáo',
      'Tài khoản',
      'Trang chủ',
    ]) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Tab $label must not overflow on a 320px-wide screen.',
      );
    }

    expect(find.text('Xin chào, Admin'), findsOneWidget);
  });
}
