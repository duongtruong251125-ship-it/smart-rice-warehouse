import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/app.dart';

void main() {
  testWidgets('renders the application shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartRiceWarehouseApp());

    expect(find.text('Smart Rice Warehouse'), findsOneWidget);
  });
}
