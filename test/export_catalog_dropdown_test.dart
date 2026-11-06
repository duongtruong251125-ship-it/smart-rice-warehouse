import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/presentation/screens/export/export_form_screen.dart';

void main() {
  testWidgets(
    'export selectors stay usable when synchronized catalogs repeat IDs',
    (tester) async {
      final customer = MockData.customers.first;
      final rice = MockData.rices.first;
      final batchProvider = BatchProvider(initial: const []);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: CustomerProvider(initial: [customer, customer]),
            ),
            ChangeNotifierProvider.value(
              value: RiceProvider(initial: [rice, rice]),
            ),
            ChangeNotifierProvider.value(value: batchProvider),
            ChangeNotifierProvider.value(value: ExportProvider(batchProvider)),
          ],
          child: const MaterialApp(home: ExportFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final dropdowns = find.byType(DropdownButtonFormField<String>);
      expect(dropdowns, findsNWidgets(2));

      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      expect(find.text(customer.name), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(customer.name));
      await tester.pumpAndSettle();
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      expect(find.textContaining(rice.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
