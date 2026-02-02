// lib/services/social_auth_service.dart
import 'package:flutter/foundation.dart';

class GoogleSignInAccount {
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String id;

  GoogleSignInAccount({
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.id,
  });
}

class SocialAuthService {
  // Google Sign In
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      debugPrint('Google Sign-In initiated');
      // Not configured in this project. Require real OAuth setup.
      throw Exception('Google Sign-In is not configured yet.');
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOutGoogle() async {
    try {
      debugPrint('Google Sign-Out');
    } catch (e) {
      debugPrint('Google Sign-Out Error: $e');
    }
  }

  // Apple Sign In
  Future<dynamic> signInWithApple() async {
    try {
      debugPrint('Apple Sign-In initiated');
      // Not configured in this project. Require real OAuth setup.
      throw Exception('Apple Sign-In is not configured yet.');
    } catch (e) {
      debugPrint('Apple Sign-In Error: $e');
      return null;
    }
  }

  // Extract user info from Google sign-in
  static Map<String, String?> getGoogleUserInfo(GoogleSignInAccount account) {
    return {
      'email': account.email,
      'displayName': account.displayName,
      'photoUrl': account.photoUrl,
      'id': account.id,
    };
  }

  // Extract user info from Apple sign-in
  static Map<String, String?> getAppleUserInfo(dynamic credential) {
    return {
      'email': credential['email'] ?? '',
      'displayName': credential['displayName'] ?? 'Apple User',
      'id': credential['id'] ?? '',
    };
  }
}
