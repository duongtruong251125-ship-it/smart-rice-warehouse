import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/presentation/screens/import/import_form_screen.dart';

void main() {
  testWidgets('import selection survives refreshed catalog model instances',
      (tester) async {
    final supplier = MockData.suppliers.first;
    final rice = MockData.rices.first;
    final suppliers = SupplierProvider(initial: [supplier]);
    final rices = RiceProvider(initial: [rice]);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: suppliers),
        ChangeNotifierProvider.value(value: rices),
        ChangeNotifierProvider(create: (_) => BatchProvider(initial: const [])),
      ],
      child: const MaterialApp(home: ImportFormScreen()),
    ));
    await tester.pumpAndSettle();
    final dropdowns = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField,
    );
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(supplier.name).last);
    await tester.pumpAndSettle();
    suppliers.updateSupplier(supplier.copyWith(phone: '0900000000'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${rice.name} (${rice.code})').last);
    await tester.pumpAndSettle();
    rices.updateRice(rice.copyWith(purchasePrice: rice.purchasePrice + 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
