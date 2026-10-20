import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared model conversion contract used by Firestore repositories.
abstract interface class FirestoreModelMapper<T> {
  T fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  );

  Map<String, Object?> toFirestore(T value, SetOptions? options);
}

/// Common codecs for values whose representation differs between SQLite JSON
/// and Cloud Firestore.
abstract final class FirestoreFieldCodec {
  static DateTime? dateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    throw FormatException('Unsupported Firestore date value: $value');
  }

  static DateTime requiredDateTime(Object? value, String fieldName) {
    final parsed = dateTime(value);
    if (parsed == null) {
      throw FormatException('Missing or invalid timestamp field: $fieldName');
    }
    return parsed;
  }

  static Timestamp timestamp(DateTime value) => Timestamp.fromDate(value);

  static double number(Object? value, {double fallback = 0}) {
    return value is num ? value.toDouble() : fallback;
  }

  static Map<String, Object?> withoutNullValues(
    Map<String, Object?> source,
  ) {
    return Map<String, Object?>.fromEntries(
      source.entries.where((entry) => entry.value != null),
    );
  }
}
