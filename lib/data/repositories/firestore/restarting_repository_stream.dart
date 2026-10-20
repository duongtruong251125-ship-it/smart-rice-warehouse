import 'dart:async';
import 'package:flutter/foundation.dart';

/// Serializes cancellation before replacement. A callback belongs to exactly
/// one generation, even when an old source is slow to cancel or ignores cancel.
Stream<T> restartingRepositoryStream<T>({
  required Stream<T> Function() open,
  Stream<Object?>? reconnect,
  Listenable? policyChanges,
  bool Function()? shouldListen,
  required Object Function(Object) mapError,
}) {
  late StreamController<T> controller;
  StreamSubscription<T>? subscription;
  StreamSubscription<Object?>? signal;
  var generation = 0;
  var closed = false;
  Future<void> work = Future<void>.value();

  void restart() {
    final revision = ++generation;
    work = work.then((_) async {
      final previous = subscription;
      subscription = null;
      await previous?.cancel();
      if (closed || revision != generation || shouldListen?.call() == false) {
        return;
      }
      subscription = open().listen((value) {
        if (!closed && revision == generation) controller.add(value);
      }, onError: (Object error, StackTrace stack) {
        if (!closed && revision == generation) {
          controller.addError(mapError(error), stack);
        }
      });
    }).catchError((Object error, StackTrace stack) {
      if (!closed && revision == generation) {
        controller.addError(mapError(error), stack);
      }
    });
  }

  controller = StreamController<T>(onListen: () {
    policyChanges?.addListener(restart);
    signal = reconnect?.listen((_) => restart(),
        onError: (Object error, StackTrace stack) {
      if (!closed) controller.addError(mapError(error), stack);
    });
    restart();
  }, onCancel: () async {
    closed = true;
    ++generation;
    policyChanges?.removeListener(restart);
    await signal?.cancel();
    await work;
    await subscription?.cancel();
  });
  return controller.stream;
}
