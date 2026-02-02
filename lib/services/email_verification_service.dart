// lib/services/email_verification_service.dart
import 'dart:math';

class EmailVerificationService {
  final Map<String, _VerificationEntry> _codes = {};
  final Random _random = Random();

  String generateCode(String email) {
    final code = (_random.nextInt(9000) + 1000).toString();
    _codes[email.trim().toLowerCase()] = _VerificationEntry(
      code: code,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
    return code;
  }

  bool verifyCode(String email, String code) {
    final key = email.trim().toLowerCase();
    final entry = _codes[key];
    if (entry == null) return false;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _codes.remove(key);
      return false;
    }
    final isMatch = entry.code == code.trim();
    if (isMatch) {
      _codes.remove(key);
    }
    return isMatch;
  }
}

class _VerificationEntry {
  final String code;
  final DateTime expiresAt;

  _VerificationEntry({required this.code, required this.expiresAt});
}