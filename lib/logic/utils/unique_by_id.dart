/// Keeps the first item for each ID while preserving the source order.
///
/// Catalog rows may be repeated in cached or synchronized lists. UI selectors
/// need one option per stable database ID to keep their selected value valid.
List<T> uniqueById<T>(Iterable<T> items, String Function(T item) idOf) {
  final seenIds = <String>{};
  return items.where((item) => seenIds.add(idOf(item))).toList(growable: false);
}
