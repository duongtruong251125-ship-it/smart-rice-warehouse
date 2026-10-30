import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_row_codec.dart';

void main() {
  test('encodes model JSON keys as snake_case recursively', () {
    final row = SupabaseRowCodec.encode({
      'createdAt': '2026-10-29T00:00:00.000Z',
      'characteristicIds': ['color-test'],
      'items': [
        {'batchId': 'batch-1', 'expectedQuantity': 5.0},
      ],
    });

    expect(row['created_at'], '2026-10-29T00:00:00.000Z');
    expect(row['characteristic_ids'], ['color-test']);
    expect(row['items'], [
      {'batch_id': 'batch-1', 'expected_quantity': 5.0},
    ]);
  });

  test('decodes Postgres rows and leaves values unchanged', () {
    final model = SupabaseRowCodec.decode({
      'created_at': '2026-10-29T00:00:00.000Z',
      'is_active': true,
      'current_batch_count': 2,
      'items': [
        {'batch_id': 'batch-1', 'actual_quantity': 3.0},
      ],
    });

    expect(model['createdAt'], '2026-10-29T00:00:00.000Z');
    expect(model['isActive'], isTrue);
    expect(model['currentBatchCount'], 2);
    expect(model['items'], [
      {'batchId': 'batch-1', 'actualQuantity': 3.0},
    ]);
  });
}
