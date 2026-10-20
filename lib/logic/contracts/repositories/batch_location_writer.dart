/// Changes location only; stock and lot identity are owned by the server.
abstract interface class BatchLocationWriter {
  Future<void> moveBatch({
    required String batchId,
    required String locationId,
    required String locationName,
  });
}
