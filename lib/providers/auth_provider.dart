import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    String? email,
    String? passwordHash,
    bool rememberedSession = false,
    this.onPersist,
  })  : _email = (email ?? 'admin@gmail.com').trim().toLowerCase(),
        _passwordHash = passwordHash ?? _hash('123456'),
        _rememberedSession = rememberedSession {
    if (rememberedSession) _currentUser = MockData.adminUser;
  }

  final String _email;
  String _passwordHash;
  bool _rememberedSession;
  final void Function(String email, String passwordHash, bool remembered)?
      onPersist;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool login({
    required String email,
    required String password,
    bool remember = false,
  }) {
    final isValid = email.trim().toLowerCase() == _email &&
        _hash(password) == _passwordHash;

    if (!isValid) {
      return false;
    }

    _currentUser = MockData.adminUser;
    _rememberedSession = remember;
    _persist();
    notifyListeners();
    return true;
  }

  void logout() {
    if (_currentUser == null) {
      return;
    }

    _currentUser = null;
    _rememberedSession = false;
    _persist();
    notifyListeners();
  }

  bool changePassword({required String current, required String replacement}) {
    if (_hash(current) != _passwordHash || replacement.length < 6) return false;
    _passwordHash = _hash(replacement);
    _persist();
    return true;
  }

  bool resetPassword(String email) {
    if (email.trim().toLowerCase() != _email) return false;
    _passwordHash = _hash('123456');
    _rememberedSession = false;
    _persist();
    return true;
  }

  void _persist() => onPersist?.call(_email, _passwordHash, _rememberedSession);

  static String _hash(String password) =>
      sha256.convert(utf8.encode('smart-rice-warehouse::$password')).toString();
}
