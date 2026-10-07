import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  static const String _mockEmail = 'admin@gmail.com';
  static const String _mockPassword = '123456';

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool login({required String email, required String password}) {
    final isValid =
        email.trim().toLowerCase() == _mockEmail && password == _mockPassword;

    if (!isValid) {
      return false;
    }

    _currentUser = MockData.adminUser;
    notifyListeners();
    return true;
  }

  void logout() {
    if (_currentUser == null) {
      return;
    }

    _currentUser = null;
    notifyListeners();
  }
}
