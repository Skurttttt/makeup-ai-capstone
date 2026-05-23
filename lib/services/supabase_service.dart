// lib/services/supabase_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  bool? _supportRequestsAvailable;
  bool? _feedbacksAvailable;

  /// Check whether `support_requests` table exists (cached).
  Future<bool> _ensureSupportRequestsAvailable() async {
    if (_supportRequestsAvailable != null) return _supportRequestsAvailable!;
    try {
      await client.from('support_requests').select('id').limit(1);
      _supportRequestsAvailable = true;
      return true;
    } catch (e) {
      _supportRequestsAvailable = false;
      debugPrint('⚠️ support_requests table not available: $e');
      return false;
    }
  }

  Future<bool> _ensureFeedbacksAvailable() async {
    if (_feedbacksAvailable != null) return _feedbacksAvailable!;
    try {
      await client.from('feedbacks').select('id').limit(1);
      _feedbacksAvailable = true;
      return true;
    } catch (e) {
      _feedbacksAvailable = false;
      debugPrint('⚠️ feedbacks table not available: $e');
      return false;
    }
  }

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
      // Prevent admins/super_admins from creating plain 'user' accounts programmatically
      final currentUid = client.auth.currentUser?.id;
      if (currentUid != null && role == 'user') {
        try {
          final caller = await client.from('accounts').select('role').eq('id', currentUid).single();
          final callerRole = caller['role']?.toString();
          if (callerRole == 'admin' || callerRole == 'super_admin') {
            throw 'Admins cannot create role "user" accounts; users must register through the app.';
          }
        } catch (e) {
          // If lookup fails, allow continuation if it's the same user registering.
        }
      }
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

  // ==================== DELIVERY PROOF ====================

  /// Upload a photo proof of delivery.
  /// Automatically awards score_photo (+0.25) and score_gps (+0.25 if GPS provided).
  /// The DB trigger auto-verifies if combined confidence >= 0.75.
  Future<Map<String, dynamic>> uploadDeliveryProof({
    required String userId,
    required String fileName,
    required Uint8List fileBytes,
    String? orderId,
    String? trackingNumber,
    double? exifLat,
    double? exifLng,
    String? exifTimestamp,
  }) async {
    try {
      final safeTs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final path = '$userId/delivery_proofs/${safeTs}_$fileName';

      await client.storage.from('delivery-proofs').uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = client.storage.from('delivery-proofs').getPublicUrl(path);

      // score_photo is always awarded; score_gps only if GPS was provided
      final scorePhoto = 0.25;
      final scoreGps   = (exifLat != null && exifLng != null) ? 0.25 : 0.0;

      final existing = orderId != null
          ? await client
              .from('delivery_proofs')
              .select('id')
              .eq('order_id', orderId)
              .maybeSingle()
          : null;

      Map<String, dynamic> result;
      if (existing != null) {
        // Update existing proof row rather than creating a duplicate
        result = await client
            .from('delivery_proofs')
            .update({
              'image_path': path,
              'image_url': publicUrl,
              'exif_lat': exifLat,
              'exif_lng': exifLng,
              'exif_timestamp': exifTimestamp,
              'score_photo': scorePhoto,
              'score_gps': scoreGps,
            })
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        result = await client
            .from('delivery_proofs')
            .insert({
              'order_id': orderId,
              'tracking_number': trackingNumber,
              'user_id': userId,
              'image_path': path,
              'image_url': publicUrl,
              'exif_lat': exifLat,
              'exif_lng': exifLng,
              'exif_timestamp': exifTimestamp,
              'score_photo': scorePhoto,
              'score_gps': scoreGps,
            })
            .select()
            .single();
      }

      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw 'Failed to upload delivery proof: $e';
    }
  }

  /// One-tap customer confirmation (no photo needed).
  /// Awards score_confirm (+0.20) via DB function.
  Future<void> confirmDelivery({
    required String orderId,
    required String userId,
  }) async {
    try {
      await client.rpc('confirm_delivery', params: {
        'p_order_id': orderId,
        'p_user_id': userId,
      });
    } catch (e) {
      throw 'Failed to confirm delivery: $e';
    }
  }

  /// Verify an OTP code from the packing slip.
  /// Awards score_otp (+0.40) via DB function and returns true/false.
  Future<bool> verifyDeliveryOtp({
    required String orderId,
    required String code,
  }) async {
    try {
      final result = await client.rpc('verify_delivery_otp', params: {
        'p_order_id': orderId,
        'p_code': code,
      });
      return result == true;
    } catch (e) {
      throw 'Failed to verify OTP: $e';
    }
  }

  /// Generate and store an OTP for an order (call when order is created/shipped).
  Future<String> generateDeliveryOtp({required String orderId}) async {
    try {
      // 6-digit numeric OTP, valid for 7 days
      final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
          .toString();
      await client.from('delivery_otps').insert({
        'order_id': orderId,
        'code': code,
        'expires_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
      });
      return code;
    } catch (e) {
      throw 'Failed to generate OTP: $e';
    }
  }

  /// Get delivery proof for a specific order.
  Future<Map<String, dynamic>?> getDeliveryProofForOrder(String orderId) async {
    try {
      final response = await client
          .from('delivery_proofs')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      return null;
    }
  }

  /// Get delivery proofs for a user (or all if admin).
  Future<List<Map<String, dynamic>>> getDeliveryProofs({String? userId}) async {
    try {
      var query = client.from('delivery_proofs').select('*, accounts(full_name, email)');
      if (userId != null) query = query.eq('user_id', userId);
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to fetch delivery proofs: $e';
    }
  }

  /// Admin manually updates status of a proof (verify / reject).
  Future<Map<String, dynamic>> updateDeliveryProofStatus({
    required String proofId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final response = await client
          .from('delivery_proofs')
          .update({
            'status': status,
            if (rejectionReason != null) 'rejection_reason': rejectionReason,
          })
          .eq('id', proofId)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw 'Failed to update delivery proof: $e';
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

      await client.storage
          .from('scan-images')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = client.storage.from('scan-images').getPublicUrl(path);

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

  Future<void> _expireExpiredSubscriptions(
    List<Map<String, dynamic>> subscriptions,
  ) async {
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
      final modernResponse = await client
          .from('user_subscriptions')
          .select(
            '*, subscription_plans(name, display_name, price, currency, billing_period, badge_text, badge_color, daily_scan_limit, available_looks, can_save_results, can_export_hd, remove_watermark)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final modernSubscriptions =
          List<Map<String, dynamic>>.from(modernResponse)
              .map(
                (subscription) => {
                  ...subscription,
                  '_source': 'user_subscriptions',
                },
              )
              .toList();
      await _expireExpiredSubscriptions(modernSubscriptions);

      final legacyResponse = await client
          .from('subscriptions')
          .select(
            'id, account_id, plan, plan_id, status, current_period_end, created_at',
          )
          .eq('account_id', userId)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final legacySubscriptions =
          List<Map<String, dynamic>>.from(legacyResponse).map((legacy) {
            final statusRaw = (legacy['status'] ?? 'active').toString();
            final statusLower = statusRaw.toLowerCase();
            final periodEnd = legacy['current_period_end']?.toString();
            final parsedEnd = periodEnd == null
                ? null
                : DateTime.tryParse(periodEnd);

            final normalizedStatus =
                (statusLower == 'active' &&
                    parsedEnd != null &&
                    parsedEnd.isBefore(now))
                ? 'expired'
                : statusRaw;

            final legacyPlanName = (legacy['plan'] ?? 'legacy_plan').toString();
            final displayName = legacyPlanName
                .split('_')
                .where((part) => part.trim().isNotEmpty)
                .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
                .join(' ');

            return {
              'id': legacy['id'],
              'user_id': legacy['account_id'],
              'plan_id': legacy['plan_id'],
              'status': normalizedStatus,
              'current_period_end': legacy['current_period_end'],
              'created_at': legacy['created_at'],
              '_source': 'subscriptions',
              'subscription_plans': {
                'name': legacyPlanName,
                'display_name': displayName.isEmpty
                    ? legacyPlanName
                    : displayName,
                'price': 0,
                'currency': 'PHP',
                'billing_period': '',
              },
            };
          }).toList();

      final merged = [...modernSubscriptions, ...legacySubscriptions];
      merged.sort((a, b) {
        final aDate =
            DateTime.tryParse((a['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse((b['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return merged;
    } catch (e) {
      throw 'Failed to fetch user subscriptions: $e';
    }
  }

  /// Get all subscriptions (for admin)
  Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final response = await client
          .from('user_subscriptions')
          .select(
            'id, user_id, plan_id, status, started_at, current_period_start, current_period_end, amount_paid, created_at, updated_at, accounts(full_name, email), subscription_plans(name, display_name, price, currency, billing_period)',
          )
          .order('created_at', ascending: false);
      final subscriptions = List<Map<String, dynamic>>.from(response);

      // Use amount_paid as the primary price source
      for (var sub in subscriptions) {
        if (sub['amount_paid'] != null) {
          sub['price'] = sub['amount_paid'];
        } else if (sub['subscription_plans'] != null &&
            sub['subscription_plans']['price'] != null) {
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
      await client.from('user_subscriptions').delete().eq('id', subscriptionId);
    } catch (e) {
      throw 'Failed to delete subscription: $e';
    }
  }

  // ==================== PAYMENTS (XENDIT) ====================

  Future<Map<String, dynamic>> createXenditCheckoutForPlan({
    required String planId,
    String? paymentMethod,
    String? successUrl,
    String? cancelUrl,
  }) async {
    try {
      final response = await client.functions.invoke(
        'create-xendit-checkout',
        body: {
          'kind': 'subscription',
          'plan_id': planId,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (successUrl != null) 'success_url': successUrl,
          if (cancelUrl != null) 'cancel_url': cancelUrl,
        },
      );

      if (response.status != 200) {
        final respData = response.data;
        final msg =
            'Function error (status: ${response.status}): ${respData ?? response.toString()}';
        debugPrint(msg);
        throw msg;
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw 'Failed to create Xendit checkout session: $e';
    }
  }

  Future<Map<String, dynamic>> createXenditCheckoutForOrder({
    required List<Map<String, dynamic>> items,
    String? paymentMethod,
    String? successUrl,
    String? cancelUrl,
  }) async {
    try {
      final response = await client.functions.invoke(
        'create-xendit-checkout',
        body: {
          'kind': 'order',
          'items': items,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (successUrl != null) 'success_url': successUrl,
          if (cancelUrl != null) 'cancel_url': cancelUrl,
        },
      );

      if (response.status != 200) {
        final respData = response.data;
        final msg =
            'Function error (status: ${response.status}): ${respData ?? response.toString()}';
        debugPrint(msg);
        throw msg;
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw 'Failed to create Xendit checkout session: $e';
    }
  }

  Future<Map<String, dynamic>> payExistingOrder({
    required String orderId,
    String? paymentMethod,
    String? successUrl,
    String? cancelUrl,
  }) async {
    try {
      final response = await client.functions.invoke(
        'create-xendit-checkout',
        body: {
          'kind': 'pay_order',
          'order_id': orderId,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (successUrl != null) 'success_url': successUrl,
          if (cancelUrl != null) 'cancel_url': cancelUrl,
        },
      );

      if (response.status != 200) {
        final respData = response.data;
        final msg =
            'Function error (status: ${response.status}): ${respData ?? response.toString()}';
        debugPrint(msg);
        throw msg;
      }

      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw 'Failed to create payment for order: $e';
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

  // ==================== SUPPORT REQUESTS ====================

  /// Insert a support request from the client app.
  Future<Map<String, dynamic>?> insertSupportRequest({
    required String subject,
    required String message,
  }) async {
    final ok = await _ensureSupportRequestsAvailable();
    if (!ok) return null;
    try {
      final userId = client.auth.currentUser?.id;
      final email = client.auth.currentUser?.email;
      final response = await client.from('support_requests').insert({
        if (userId != null) 'user_id': userId,
        if (email != null) 'email': email,
        'subject': subject.trim().isEmpty ? 'Support Request' : subject.trim(),
        'message': message.trim(),
      }).select().single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('⚠️ Failed to save support request: $e');
      return null;
    }
  }

  /// Insert a feedback entry from the client app.
  Future<Map<String, dynamic>?> insertFeedback({
    int? rating,
    required String message,
  }) async {
    final ok = await _ensureFeedbacksAvailable();
    if (!ok) return null;
    try {
      final userId = client.auth.currentUser?.id;
      final email = client.auth.currentUser?.email;
      final response = await client.from('feedbacks').insert({
        if (userId != null) 'user_id': userId,
        if (email != null) 'email': email,
        if (rating != null) 'rating': rating,
        'message': message.trim(),
      }).select().single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('⚠️ Failed to save feedback: $e');
      return null;
    }
  }

  /// Admin: fetch support requests for review
  Future<List<Map<String, dynamic>>> getSupportRequests({int limit = 200}) async {
    final ok = await _ensureSupportRequestsAvailable();
    if (!ok) return <Map<String, dynamic>>[];
    try {
      final response = await client
          .from('support_requests')
          .select('id, created_at, subject, message, status, email, user_id, accounts(full_name, email)')
          .order('created_at', ascending: false)
          .limit(limit);

      // Tag as support source
      final list = List<Map<String, dynamic>>.from(response);
      return list.map((m) => {'_source': 'support', ...m}).toList();
    } catch (e) {
      throw 'Failed to fetch support requests: $e';
    }
  }

  /// Admin: fetch feedback entries
  Future<List<Map<String, dynamic>>> getFeedbacks({int limit = 200}) async {
    final ok = await _ensureFeedbacksAvailable();
    if (!ok) return <Map<String, dynamic>>[];
    try {
      final response = await client
          .from('feedbacks')
          .select('id, created_at, rating, message, status, email, user_id, accounts(full_name, email)')
          .order('created_at', ascending: false)
          .limit(limit);

      final list = List<Map<String, dynamic>>.from(response);
      return list.map((m) => {'_source': 'feedback', ...m}).toList();
    } catch (e) {
      throw 'Failed to fetch feedbacks: $e';
    }
  }

  /// Admin: update support request status (e.g. open, in_progress, resolved)
  Future<Map<String, dynamic>> updateSupportRequestStatus({
    required String requestId,
    required String status,
  }) async {
    final ok = await _ensureSupportRequestsAvailable();
    if (!ok) throw 'support_requests table not available';
    try {
      final response = await client
          .from('support_requests')
          .update({'status': status})
          .eq('id', requestId)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw 'Failed to update support request status: $e';
    }
  }

  /// Admin: update feedback status
  Future<Map<String, dynamic>> updateFeedbackStatus({
    required String feedbackId,
    required String status,
  }) async {
    final ok = await _ensureFeedbacksAvailable();
    if (!ok) throw 'feedbacks table not available';
    try {
      final response = await client
          .from('feedbacks')
          .update({'status': status})
          .eq('id', feedbackId)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw 'Failed to update feedback status: $e';
    }
  }

  // ==================== ADMIN NOTIFICATIONS ====================

  /// Fetch recent notifications: new subscriptions, orders, support requests.
  /// Returns a merged+sorted list, each item has a '_type' key.
  Future<List<Map<String, dynamic>>> getAdminNotifications(
      {int limit = 30}) async {
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();

    final List<Map<String, dynamic>> all = [];

    // New subscriptions
    try {
      final subs = await client
          .from('user_subscriptions')
          .select(
              'id, created_at, status, accounts(full_name, email), subscription_plans(name, display_name)')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(15);
      for (final s in subs) {
        all.add({'_type': 'subscription', ...Map<String, dynamic>.from(s)});
      }
    } catch (_) {}

    // Marketplace orders
    try {
      final orders = await client
          .from('orders')
          .select('id, created_at, status, total, accounts:buyer_id(full_name, email)')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(15);
      for (final o in orders) {
        all.add({'_type': 'order', ...Map<String, dynamic>.from(o)});
      }
    } catch (_) {}

    // Support requests
    try {
      final reqs = await client
          .from('support_requests')
          .select('id, created_at, subject, message, status, accounts(full_name, email)')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(15);
      for (final r in reqs) {
        all.add({'_type': 'support', ...Map<String, dynamic>.from(r)});
      }
    } catch (_) {}

    // Feedbacks
    try {
      final fbs = await client
          .from('feedbacks')
          .select('id, created_at, rating, message, status, accounts(full_name, email)')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(15);
      for (final f in fbs) {
        all.add({'_type': 'feedback', ...Map<String, dynamic>.from(f)});
      }
    } catch (_) {}

    // New accounts
    try {
      final accounts = await client
          .from('accounts')
          .select('id, created_at, full_name, email')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(15);
      for (final a in accounts) {
        all.add({'_type': 'account_created', ...Map<String, dynamic>.from(a)});
      }
    } catch (_) {}

    // Audit logs (e.g., password changes)
    try {
      final logs = await client
          .from('audit_logs')
          .select('id, created_at, action, target, metadata, accounts(full_name, email)')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(30);
      for (final l in logs) {
        // Only include password change actions and other important items
        final action = (l['action'] as String?) ?? '';
        if (action.contains('password')) {
          all.add({'_type': 'audit', ...Map<String, dynamic>.from(l)});
        }
      }
    } catch (_) {}

    all.sort((a, b) {
      final aT =
          DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final bT =
          DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return bT.compareTo(aT);
    });

    return all.take(limit).toList();
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
  RealtimeChannel subscribeToSubscriptions(
    String userId, {
    VoidCallback? onChange,
  }) {
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
