/// Conversion helpers for model JSON and Postgres snake_case rows.
abstract final class SupabaseRowCodec {
  static Map<String, Object?> encode(Map<String, Object?> source) =>
      _convertMap(source, _toSnakeCase);

  static Map<String, dynamic> decode(Map<String, dynamic> source) =>
      _convertMap(source, _toCamelCase);

  static Map<String, Object?> _convertMap(
    Map<String, Object?> source,
    String Function(String) convertKey,
  ) =>
      Map.fromEntries(source.entries.map((entry) => MapEntry(
            convertKey(entry.key),
            _convertValue(entry.value, convertKey),
          )));

  static Object? _convertValue(
    Object? value,
    String Function(String) convertKey,
  ) {
    if (value is Map<String, Object?>) return _convertMap(value, convertKey);
    if (value is Map) {
      return _convertMap(
        value.map((key, value) => MapEntry(key.toString(), value)),
        convertKey,
      );
    }
    if (value is List) {
      return value.map((item) => _convertValue(item, convertKey)).toList();
    }
    return value;
  }

  static String _toSnakeCase(String value) => value.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      );

  static String _toCamelCase(String value) => value.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
}
