import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_paths.dart';

void main() {
  group('Firestore paths', () {
    test('uses stable collection and document names', () {
      expect(FirestorePaths.riceProducts, 'rice_products');
      expect(FirestorePaths.stockMovements, 'stock_movements');
      expect(
          FirestorePaths.riceProduct(' rice-001 '), 'rice_products/rice-001');
      expect(FirestorePaths.user('uid-001'), 'users/uid-001');
    });

    test('rejects unsafe document IDs', () {
      expect(() => FirestorePaths.batch(''), throwsArgumentError);
      expect(() => FirestorePaths.batch('batch/child'), throwsArgumentError);
    });
  });

  group('Firestore field codec', () {
    test('converts timestamps without changing the instant', () {
      final source = DateTime.utc(2026, 10, 15, 8, 30);
      final timestamp = FirestoreFieldCodec.timestamp(source);
      final restored = FirestoreFieldCodec.dateTime(timestamp)!;

      expect(timestamp, isA<Timestamp>());
      expect(restored.millisecondsSinceEpoch, source.millisecondsSinceEpoch);
    });

    test('supports legacy SQLite date and numeric representations', () {
      expect(
        FirestoreFieldCodec.dateTime('2026-10-15T08:30:00.000Z'),
        DateTime.utc(2026, 10, 15, 8, 30),
      );
      expect(FirestoreFieldCodec.number(12), 12.0);
      expect(FirestoreFieldCodec.number(12.5), 12.5);
      expect(FirestoreFieldCodec.number(null, fallback: 7), 7.0);
    });

    test('removes null values but keeps false and zero', () {
      final result = FirestoreFieldCodec.withoutNullValues({
        'missing': null,
        'enabled': false,
        'quantity': 0,
      });

      expect(result, {'enabled': false, 'quantity': 0});
    });
  });
}
