import 'package:smart_rice_warehouse/repositories/contracts/read_repository.dart';

abstract interface class CrudRepository<T> implements ReadRepository<T> {
  Future<void> create(String id, T value);

  Future<void> update(String id, T value);

  Future<void> delete(String id);
}
