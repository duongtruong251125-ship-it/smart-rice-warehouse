import 'package:flutter/foundation.dart';

/// Only controls business listeners while the app is backgrounded.
/// Auth/profile listeners and foreground transactions are never disabled.
class BusinessSyncPolicy extends ChangeNotifier {
  BusinessSyncPolicy({bool backgroundSyncEnabled = true})
      : _backgroundSyncEnabled = backgroundSyncEnabled;

  bool _backgroundSyncEnabled;
  bool _foreground = true;
  bool get shouldListen => _foreground || _backgroundSyncEnabled;

  void configure({bool? backgroundSyncEnabled, bool? foreground}) {
    final previous = shouldListen;
    _backgroundSyncEnabled = backgroundSyncEnabled ?? _backgroundSyncEnabled;
    _foreground = foreground ?? _foreground;
    if (previous != shouldListen) notifyListeners();
  }
}
