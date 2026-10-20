class RepositoryException implements Exception {
  const RepositoryException(
    this.message, {
    this.code,
    this.cause,
  });

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() {
    final suffix = code == null ? '' : ' ($code)';
    return 'RepositoryException$suffix: $message';
  }
}
