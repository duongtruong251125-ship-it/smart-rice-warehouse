import 'package:flutter/foundation.dart';

/// In-flight I/O can finish after its screen/provider has been removed.
abstract class LifecycleNotifier extends ChangeNotifier {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
