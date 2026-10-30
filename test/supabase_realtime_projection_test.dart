import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_json_repository.dart';

void main() {
  test('re-emits a projection snapshot when its related table changes',
      () async {
    final source = StreamController<List<int>>();
    final relatedChanges = StreamController<Object?>();
    final snapshots = <List<int>>[];
    final subscription = reemitLatestOnRefresh(
      source.stream,
      relatedChanges.stream,
    ).listen(snapshots.add);

    source.add([1, 2]);
    await Future<void>.delayed(Duration.zero);
    relatedChanges.add(null);
    await Future<void>.delayed(Duration.zero);
    source.add([1, 2, 3]);
    await Future<void>.delayed(Duration.zero);

    expect(snapshots, [
      [1, 2],
      [1, 2],
      [1, 2, 3],
    ]);

    await subscription.cancel();
    await source.close();
    await relatedChanges.close();
  });
}
