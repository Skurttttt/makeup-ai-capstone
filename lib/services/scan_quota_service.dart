// lib/services/scan_quota_service.dart
//
// Centralised gate for the daily face-scan quota and automatic cloud
// auto-save of scan results. Backed by the public.usage_tracking and
// public.scans tables.
//
// Tiers (matches subscription_plans rows):
//   • regular  – 5 scans / day, no auto-save to cloud.
//   • pro      – unlimited scans, auto-save to cloud.
//   • premium  – unlimited scans, auto-save to cloud, HD/no watermark.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanUsage {
  final String tier; // 'regular' | 'pro' | 'premium'
  final int dailyLimit; // -1 = unlimited
  final int usedToday;
  final bool canAutoSaveToCloud;

  const ScanUsage({
    required this.tier,
    required this.dailyLimit,
    required this.usedToday,
    required this.canAutoSaveToCloud,
  });

  bool get isUnlimited => dailyLimit < 0;
  bool get hasRemaining => isUnlimited || usedToday < dailyLimit;
  int get remaining =>
      isUnlimited ? -1 : (dailyLimit - usedToday).clamp(0, dailyLimit);
}

class ScanQuotaService {
  ScanQuotaService._();
  static final ScanQuotaService instance = ScanQuotaService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _today() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Resolves the current user's active plan into a tier + capability set.
  Future<ScanUsage> getUsage() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const ScanUsage(
        tier: 'regular',
        dailyLimit: 5,
        usedToday: 0,
        canAutoSaveToCloud: false,
      );
    }

    String tier = 'regular';
    int limit = 5;
    bool canSave = false;

    try {
      final subs = await _client
          .from('user_subscriptions')
          .select(
              'status, current_period_end, subscription_plans(name, daily_scan_limit, can_save_results)')
          .eq('user_id', user.id)
          .eq('status', 'active');

      Map<String, dynamic>? activePlan;
      for (final s in subs) {
        final plan = s['subscription_plans'] as Map<String, dynamic>?;
        if (plan == null) continue;
        activePlan = plan;
      }

      if (activePlan != null) {
        final raw =
            (activePlan['name'] ?? '').toString().toLowerCase();
        if (raw.contains('premium') || raw.contains('lifetime')) {
          tier = 'premium';
        } else if (raw.contains('pro')) {
          tier = 'pro';
        }
        final l = activePlan['daily_scan_limit'];
        if (l is int) limit = l;
        if (l is num) limit = l.toInt();
        canSave = activePlan['can_save_results'] == true;
      }
    } catch (e) {
      debugPrint('ScanQuotaService.getUsage plan lookup failed: $e');
    }

    // Pro/Premium are always unlimited regardless of the plan row.
    if (tier != 'regular') {
      limit = -1;
      canSave = true;
    }

    int used = 0;
    try {
      final row = await _client
          .from('usage_tracking')
          .select('scans_today')
          .eq('user_id', user.id)
          .eq('tracking_date', _today())
          .maybeSingle();
      used = (row?['scans_today'] as int?) ?? 0;
    } catch (e) {
      debugPrint('ScanQuotaService.getUsage usage lookup failed: $e');
    }

    return ScanUsage(
      tier: tier,
      dailyLimit: limit,
      usedToday: used,
      canAutoSaveToCloud: canSave,
    );
  }

  /// Returns true if the user is allowed to scan right now.
  Future<bool> hasScansRemaining() async {
    final u = await getUsage();
    return u.hasRemaining;
  }

  /// Increments today's scan counter. Call this only after a scan has
  /// actually completed (face detected + look generated).
  /// Returns the updated usage snapshot.
  Future<ScanUsage> consumeScan() async {
    final user = _client.auth.currentUser;
    if (user == null) return getUsage();

    final today = _today();
    try {
      final existing = await _client
          .from('usage_tracking')
          .select('id, scans_today')
          .eq('user_id', user.id)
          .eq('tracking_date', today)
          .maybeSingle();

      if (existing == null) {
        await _client.from('usage_tracking').insert({
          'user_id': user.id,
          'tracking_date': today,
          'scans_today': 1,
        });
      } else {
        final current = (existing['scans_today'] as int?) ?? 0;
        await _client
            .from('usage_tracking')
            .update({'scans_today': current + 1})
            .eq('id', existing['id']);
      }
    } catch (e) {
      debugPrint('ScanQuotaService.consumeScan failed: $e');
    }
    return getUsage();
  }

  /// Auto-saves a scan to the cloud `scans` table when the user's plan
  /// allows it (Pro/Premium). Silently skips for free users.
  Future<void> autoSaveScan({
    required String lookName,
    String? imagePath,
    String? imageUrl,
    String? skinTone,
    String? faceShape,
    Map<String, dynamic>? faceData,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final usage = await getUsage();
    if (!usage.canAutoSaveToCloud) return;

    try {
      await _client.from('scans').insert({
        'user_id': user.id,
        'look_name': lookName,
        if (imagePath != null) 'image_path': imagePath,
        if (imageUrl != null) 'image_url': imageUrl,
        if (skinTone != null) 'skin_tone': skinTone,
        if (faceShape != null) 'face_shape': faceShape,
        if (faceData != null) 'face_data': faceData,
      });
    } catch (e) {
      debugPrint('ScanQuotaService.autoSaveScan failed: $e');
    }
  }
}
