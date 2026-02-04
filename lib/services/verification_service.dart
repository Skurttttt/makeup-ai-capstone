// lib/services/verification_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VerificationService {
  static final VerificationService _instance = VerificationService._internal();

  factory VerificationService() {
    return _instance;
  }

  VerificationService._internal();

  final _client = Supabase.instance.client;

  /// Send confirmation email using Supabase Auth resend
  Future<void> sendConfirmationEmail(String email) async {
    try {
      final confirmUrl = dotenv.env['CONFIRM_URL'];
      final redirectTo = (confirmUrl != null && confirmUrl.isNotEmpty && confirmUrl != 'https://your-domain.com/confirm')
          ? confirmUrl
          : null;

      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectTo,
      );

      debugPrint('✅ Confirmation email sent to $email');
    } catch (e) {
      throw 'Failed to send confirmation email: $e';
    }
  }
}
