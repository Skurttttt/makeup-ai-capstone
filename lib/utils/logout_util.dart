import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_supabase_page.dart';
import '../services/supabase_service.dart';

Future<void> showLogoutConfirmationDialog(
  BuildContext context, {
  String role = 'user',
}) async {
  return showDialog(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
          ),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            final navigator = Navigator.of(dialogContext, rootNavigator: true);
            navigator.pop();

            // Log logout action before signing out
            try {
              final supabaseService = SupabaseService();
              await supabaseService.logAdminAction(
                action: '${role}_logout',
                target: 'auth',
                metadata: {
                  'email': Supabase.instance.client.auth.currentUser?.email,
                  'logout_time': DateTime.now().toIso8601String(),
                },
              );
            } catch (e) {
              debugPrint('Failed to log logout audit: $e');
            }

            await Supabase.instance.client.auth.signOut();
            // Clear remember-me so the next app start shows login
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('remember_me', false);

            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Logout', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
