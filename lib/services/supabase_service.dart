// lib/services/supabase_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // ==================== AUTHENTICATION ====================

  /// Sign up new user
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return response;
    } catch (e) {
      throw 'Signup failed: $e';
    }
  }

  /// Sign in user
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw 'Login failed: $e';
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw 'Logout failed: $e';
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return client.auth.currentUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  /// Get user session
  Session? getSession() {
    return client.auth.currentSession;
  }

  // ==================== USER PROFILE ====================

  /// Create user profile
  Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String role = 'user',
  }) async {
    try {
      final response = await client.from('accounts').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      return response.first;
    } catch (e) {
      throw 'Failed to create profile: $e';
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('accounts')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      throw 'Failed to fetch profile: $e';
    }
  }

  /// Check if email already exists in accounts
  Future<bool> emailExists(String email) async {
    try {
      final response = await client
          .from('accounts')
          .select('id')
          .eq('email', email)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      throw 'Failed to check email: $e';
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await client
          .from('accounts')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  // ==================== SCAN HISTORY ====================

  /// Save face scan
  Future<Map<String, dynamic>> saveScan({
    required String userId,
    required String lookName,
    required String imagePath,
    required Map<String, dynamic> faceData,
  }) async {
    try {
      final response = await client.from('scans').insert({
        'user_id': userId,
        'look_name': lookName,
        'image_path': imagePath,
        'face_data': faceData,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      return response.first;
    } catch (e) {
      throw 'Failed to save scan: $e';
    }
  }

  /// Get user's scan history
  Future<List<Map<String, dynamic>>> getScanHistory(String userId) async {
    try {
      final response = await client
          .from('scans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to fetch scan history: $e';
    }
  }

  /// Delete scan
  Future<void> deleteScan(String scanId) async {
    try {
      await client.from('scans').delete().eq('id', scanId);
    } catch (e) {
      throw 'Failed to delete scan: $e';
    }
  }

  // ==================== USER FAVORITES ====================

  /// Add favorite look
  Future<Map<String, dynamic>> addFavoriteLook({
    required String userId,
    required String lookName,
  }) async {
    try {
      final response = await client.from('favorites').insert({
        'user_id': userId,
        'look_name': lookName,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      return response.first;
    } catch (e) {
      throw 'Failed to add favorite: $e';
    }
  }

  /// Get user's favorite looks
  Future<List<Map<String, dynamic>>> getFavoriteLooks(String userId) async {
    try {
      final response = await client
          .from('favorites')
          .select()
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to fetch favorites: $e';
    }
  }

  /// Remove favorite look
  Future<void> removeFavoriteLook(String favoriteId) async {
    try {
      await client.from('favorites').delete().eq('id', favoriteId);
    } catch (e) {
      throw 'Failed to remove favorite: $e';
    }
  }

  // ==================== ADMIN FUNCTIONS ====================

  /// Get all users (admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
        final response = await client
          .from('accounts')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to fetch users: $e';
    }
  }

  /// Get analytics data (admin only)
  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
        final totalUsers = await client
          .from('accounts')
          .select()
          .then((data) => data.length);

      final totalScans = await client
          .from('scans')
          .select()
          .then((data) => data.length);

      return {
        'total_users': totalUsers,
        'total_scans': totalScans,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw 'Failed to fetch analytics: $e';
    }
  }

  // ==================== FILE UPLOAD ====================

  /// Upload scan image to storage
  Future<String> uploadScanImage({
    required String userId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();

      final path = '$userId/scans/$fileName';

      await client.storage.from('scan-images').uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = client.storage
          .from('scan-images')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      throw 'Failed to upload image: $e';
    }
  }

  /// Get public URL for uploaded file
  String getPublicImageUrl(String path) {
    return client.storage.from('scan-images').getPublicUrl(path);
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  // ==================== SUBSCRIPTIONS ====================

  Future<void> _expireExpiredSubscriptions(List<Map<String, dynamic>> subscriptions) async {
    final now = DateTime.now();
    final List<Future<void>> updates = [];

    for (final subscription in subscriptions) {
      final status = (subscription['status'] ?? '').toString().toLowerCase();
      final currentPeriodEnd = subscription['current_period_end']?.toString();

      if (status != 'active' || currentPeriodEnd == null) {
        continue;
      }

      final parsedEnd = DateTime.tryParse(currentPeriodEnd);
      if (parsedEnd == null || !parsedEnd.isBefore(now)) {
        continue;
      }

      final id = subscription['id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }

      updates.add(
        client
            .from('user_subscriptions')
            .update({'status': 'expired'})
            .eq('id', id)
            .then((_) => null),
      );
    }

    if (updates.isNotEmpty) {
      await Future.wait(updates);
    }
  }

  /// Get all subscriptions (admin only)
  /// Get all subscription plans (for admin to manage)
  Future<List<Map<String, dynamic>>> getAllPlans() async {
    try {
      final response = await client
          .from('subscription_plans')
          .select()
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to fetch plans: $e';
    }
  }

  /// Get user's subscriptions with plan details
  Future<List<Map<String, dynamic>>> getUserSubscriptions(String userId) async {
    try {
      final response = await client
          .from('user_subscriptions')
          .select('*, subscription_plans(name, display_name, price, currency, billing_period, badge_text, badge_color, daily_scan_limit, available_looks, can_save_results, can_export_hd, remove_watermark)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final subscriptions = List<Map<String, dynamic>>.from(response);
      await _expireExpiredSubscriptions(subscriptions);
      return subscriptions;
    } catch (e) {
      throw 'Failed to fetch user subscriptions: $e';
    }
  }

  /// Get all subscriptions (for admin)
  Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final response = await client
          .from('user_subscriptions')
          .select('id, user_id, plan_id, status, started_at, current_period_start, current_period_end, amount_paid, created_at, updated_at, accounts(full_name, email), subscription_plans(name, display_name, price, currency, billing_period)')
          .order('created_at', ascending: false);
      final subscriptions = List<Map<String, dynamic>>.from(response);
      
      // Use amount_paid as the primary price source
      for (var sub in subscriptions) {
        if (sub['amount_paid'] != null) {
          sub['price'] = sub['amount_paid'];
        } else if (sub['subscription_plans'] != null && sub['subscription_plans']['price'] != null) {
          sub['price'] = sub['subscription_plans']['price'];
        }
      }
      
      return subscriptions;
    } catch (e) {
      throw 'Failed to fetch subscriptions: $e';
    }
  }

  /// Create a subscription plan (admin only)
  Future<Map<String, dynamic>> createPlan({
    required String name,
    required double price,
    String? description,
    String billingPeriod = 'month',
    String? displayName,
    String? badgeText,
    String? badgeColor,
    int dailyScanLimit = -1,
    List<String>? availableLooks,
    bool canSaveResults = false,
    bool canExportHd = false,
    bool removeWatermark = false,
  }) async {
    try {
      final response = await client.from('subscription_plans').insert({
        'name': name,
        'display_name': displayName ?? name,
        'price': price,
        'currency': 'PHP',
        'description': description,
        'billing_period': billingPeriod,
        'badge_text': badgeText,
        'badge_color': badgeColor,
        'daily_scan_limit': dailyScanLimit,
        'available_looks': availableLooks ?? [],
        'can_save_results': canSaveResults,
        'can_export_hd': canExportHd,
        'remove_watermark': removeWatermark,
        'is_active': true,
      }).select();
      return response.first;
    } catch (e) {
      throw 'Failed to create plan: $e';
    }
  }

  /// Update a subscription plan (admin only)
  Future<Map<String, dynamic>> updatePlan({
    required String planId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await client
          .from('subscription_plans')
          .update(updates)
          .eq('id', planId)
          .select();
      return response.first;
    } catch (e) {
      throw 'Failed to update plan: $e';
    }
  }

  /// Delete a subscription plan (admin only)
  Future<void> deletePlan(String planId) async {
    try {
      await client.from('subscription_plans').delete().eq('id', planId);
    } catch (e) {
      throw 'Failed to delete plan: $e';
    }
  }

  /// Create user subscription from plan
  Future<Map<String, dynamic>> createUserSubscription({
    required String accountId,
    required String planId,
    required String status,
    required DateTime currentPeriodEnd,
    double? amountPaid,
  }) async {
    try {
      final response = await client.from('user_subscriptions').insert({
        'user_id': accountId,
        'plan_id': planId,
        'status': status,
        'current_period_end': currentPeriodEnd.toIso8601String(),
        if (amountPaid != null) 'amount_paid': amountPaid,
      }).select();
      return response.first;
    } catch (e) {
      throw 'Failed to create user subscription: $e';
    }
  }

  /// Update subscription (admin only)
  Future<Map<String, dynamic>> updateSubscription({
    required String subscriptionId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await client
          .from('user_subscriptions')
          .update(updates)
          .eq('id', subscriptionId)
          .select();

      if (response.isEmpty) {
        throw 'Subscription not found or access denied';
      }
      return response.first;
    } catch (e) {
      throw 'Failed to update subscription: $e';
    }
  }

  /// Delete subscription (admin only)
  Future<void> deleteSubscription(String subscriptionId) async {
    try {
      await client
          .from('user_subscriptions')
          .delete()
          .eq('id', subscriptionId);
    } catch (e) {
      throw 'Failed to delete subscription: $e';
    }
  }

  // ==================== AUDIT LOGS ====================

  /// Log admin action
  Future<void> logAdminAction({
    required String action,
    required String target,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ Cannot log action: No user logged in');
        return;
      }
      
      await client.from('audit_logs').insert({
        'actor_id': currentUser.id,
        'action': action,
        'target': target,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Don't throw - just log the error so the main operation isn't blocked
      debugPrint('⚠️ Failed to log admin action: $e');
    }
  }

  /// Get audit logs (admin only)
  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    try {
      final response = await client
          .from('audit_logs')
          .select('*, accounts(full_name, email)')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to fetch audit logs: $e';
    }
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  /// Listen to user profile changes
  RealtimeChannel subscribeToUserProfile(String userId) {
    return client
        .channel('accounts:id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            // Handle profile changes
          },
        )
        .subscribe();
  }

  /// Listen to subscription changes
  RealtimeChannel subscribeToSubscriptions(String userId, {VoidCallback? onChange}) {
    return client
        .channel('user_subscriptions:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onChange?.call();
          },
        )
        .subscribe();
  }

  /// Listen to new scans
  RealtimeChannel subscribeToNewScans(String userId) {
    return client
        .channel('scans:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Handle new scans
          },
        )
        .subscribe();
  }

  /// Unsubscribe from channel
  Future<void> unsubscribeFromChannel(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
