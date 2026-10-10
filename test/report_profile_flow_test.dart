import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/screens/profile/profile_tab.dart';

void main() {
  test('report totals and inventory value react to import and export', () {
    final batchProvider = BatchProvider();
    final importProvider = ImportProvider(batchProvider);
    final exportProvider = ExportProvider(batchProvider);
    final riceProvider = RiceProvider();
    final rice = riceProvider.findById('rice-st25')!;
    final now = DateTime.now();
    final initialImportTotal = importProvider.totalAmountForMonth(now);
    final initialExportTotal = exportProvider.totalAmountForMonth(now);
    final initialInventoryValue =
        batchProvider.inventoryValue(riceProvider.rices);

    expect(
      importProvider.createImportReceipt(
        receipt: ImportReceiptModel(
          id: 'report-import',
          code: 'PN-REPORT',
          supplierId: 'supplier-lua-viet',
          supplierName: 'Công ty Lúa Việt',
          date: now,
          riceId: rice.id,
          riceName: rice.name,
          quantity: 10,
          purchasePrice: rice.purchasePrice,
          totalAmount: 10 * rice.purchasePrice,
          batchCode: 'LO-REPORT',
          manufactureDate: now,
          expiryDate: DateTime(now.year + 1, now.month, now.day),
        ),
        batch: BatchModel(
          id: 'batch-report',
          code: 'LO-REPORT',
          riceId: rice.id,
          riceName: rice.name,
          quantity: 10,
          importDate: now,
          manufactureDate: now,
          expiryDate: DateTime(now.year + 1, now.month, now.day),
          status: BatchStatus.available,
        ),
      ),
      isTrue,
    );
    expect(
      importProvider.totalAmountForMonth(now),
      initialImportTotal + 10 * rice.purchasePrice,
    );
    expect(
      batchProvider.inventoryValue(riceProvider.rices),
      initialInventoryValue + 10 * rice.purchasePrice,
    );

    expect(
      exportProvider.createExportReceipt(
        ExportReceiptModel(
          id: 'report-export',
          code: 'PX-REPORT',
          customerId: 'customer-minh-phat',
          customerName: 'Đại lý Minh Phát',
          date: now,
          riceId: rice.id,
          riceName: rice.name,
          quantity: 4,
          sellingPrice: rice.sellingPrice,
          totalAmount: 4 * rice.sellingPrice,
          note: '',
        ),
      ),
      isTrue,
    );
    expect(
      exportProvider.totalAmountForMonth(now),
      initialExportTotal + 4 * rice.sellingPrice,
    );
    expect(
      batchProvider.inventoryValue(riceProvider.rices),
      initialInventoryValue + 6 * rice.purchasePrice,
    );
  });

  testWidgets('logout clears auth state and the main navigation stack', (
    tester,
  ) async {
    final authProvider = AuthProvider();
    authProvider.login(email: 'admin@gmail.com', password: '123456');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp(
          initialRoute: '/main-test',
          routes: {
            '/main-test': (_) => const Scaffold(body: ProfileTab()),
            AppRoutes.login: (_) => const Scaffold(
                  body: Center(child: Text('LOGIN_SCREEN')),
                ),
          },
        ),
      ),
    );

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(authProvider.isLoggedIn, isFalse);
    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
    final loginContext = tester.element(find.text('LOGIN_SCREEN'));
    expect(Navigator.of(loginContext).canPop(), isFalse);
  });
}
