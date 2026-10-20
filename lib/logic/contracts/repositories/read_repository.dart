abstract interface class ReadRepository<T> {
  Stream<List<T>> watchAll();

  Stream<T?> watchById(String id);

  Future<List<T>> getAll();

  Future<T?> getById(String id);
}
