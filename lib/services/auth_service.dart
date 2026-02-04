// lib/services/auth_service.dart
import 'package:flutter/material.dart';

enum UserRole { admin, user, client }

class AuthService extends ChangeNotifier {
  UserRole _userRole = UserRole.user;
  String? _userId;
  bool _isAuthenticated = false;

  UserRole get userRole => _userRole;
  String? get userId => _userId;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _userRole == UserRole.admin;

  Future<void> login({required String email, required String password, required UserRole role}) async {
    try {
      // Simulate login delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock authentication
      _userId = email.split('@')[0];
      _userRole = role;
      _isAuthenticated = true;

      notifyListeners();
    } catch (e) {
      throw 'Login failed: $e';
    }
  }

  Future<void> logout() async {
    _userId = null;
    _userRole = UserRole.user;
    _isAuthenticated = false;
    notifyListeners();
  }

  void setUserRole(UserRole role) {
    _userRole = role;
    notifyListeners();
  }

  Future<bool> checkSession() async {
    // Check if user still has valid session
    await Future.delayed(const Duration(milliseconds: 300));
    return _isAuthenticated;
  }
}
