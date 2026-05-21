import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://iqaiebnoodjnoyaiyoez.supabase.co';

class PasswordResetService {
  /// Sends a 6-digit reset code to the user's email via Edge Function.
  static Future<void> sendResetCode(String email) async {
    final response = await Supabase.instance.client.functions.invoke(
      'send-reset-code',
      body: {'email': email},
    );
    if (response.data is Map && response.data['error'] != null) {
      throw response.data['error'].toString();
    }
  }

  /// Verifies the 6-digit code and updates the password via Edge Function.
  static Future<void> verifyCodeAndChangePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'verify-reset-code',
      body: {'email': email, 'code': code, 'newPassword': newPassword},
    );
    if (response.data is Map && response.data['error'] != null) {
      throw response.data['error'].toString();
    }
  }
}
