import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanUsage {
  final String tier;
  final int dailyLimit;
  final int usedToday;
  final bool canAutoSaveToCloud;
  final DateTime nextResetAt;

  const ScanUsage({
    required this.tier,
    required this.dailyLimit,
    required this.usedToday,
    required this.canAutoSaveToCloud,
    required this.nextResetAt,
  });

  bool get isUnlimited => dailyLimit < 0;

  bool get hasRemaining {
    if (isUnlimited) return true;
    return usedToday < dailyLimit;
  }

  int get remaining {
    if (isUnlimited) return -1;
    return (dailyLimit - usedToday)
        .clamp(0, dailyLimit);
  }
}

class ScanQuotaService {
  ScanQuotaService._();

  static final ScanQuotaService instance =
      ScanQuotaService._();

  SupabaseClient get _client =>
      Supabase.instance.client;

  String _today() {
    final d = DateTime.now();

    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _nextResetTime() {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day + 1,
    );
  }

  Future<ScanUsage> getUsage() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return ScanUsage(
        tier: 'regular',
        dailyLimit: 5,
        usedToday: 0,
        canAutoSaveToCloud: false,
        nextResetAt: _nextResetTime(),
      );
    }

    String tier = 'regular';
    int limit = 5;
    bool canSave = false;

    try {
      final subs = await _client
          .from('user_subscriptions')
          .select(
            '''
            status,
            current_period_end,
            subscription_plans(
              name,
              daily_scan_limit,
              can_save_results
            )
            ''',
          )
          .eq('user_id', user.id)
          .eq('status', 'active');

      Map<String, dynamic>? activePlan;

      for (final s in subs) {
        final plan =
            s['subscription_plans']
                as Map<String, dynamic>?;

        if (plan != null) {
          activePlan = plan;
        }
      }

      if (activePlan != null) {
        final raw =
            (activePlan['name'] ?? '')
                .toString()
                .toLowerCase();

        if (raw.contains('premium') || raw.contains('lifetime') ||
            raw.contains('pro') || raw.contains('weekly') ||
            raw.contains('monthly')) {
          tier = 'premium';
        }

        canSave =
            activePlan['can_save_results'] == true;
      }
    } catch (e) {
      debugPrint('Plan lookup failed: $e');
    }

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

      used =
          (row?['scans_today'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Usage lookup failed: $e');
    }

    return ScanUsage(
      tier: tier,
      dailyLimit: limit,
      usedToday: used,
      canAutoSaveToCloud: canSave,
      nextResetAt: _nextResetTime(),
    );
  }

  Future<ScanUsage> consumeScan() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return getUsage();
    }

    final today = _today();

    try {
      final existing = await _client
          .from('usage_tracking')
          .select('id, scans_today')
          .eq('user_id', user.id)
          .eq('tracking_date', today)
          .maybeSingle();

      if (existing == null) {
        await _client
            .from('usage_tracking')
            .insert({
          'user_id': user.id,
          'tracking_date': today,
          'scans_today': 1,
        });
      } else {
        final current =
            (existing['scans_today'] as int?) ??
                0;

        await _client
            .from('usage_tracking')
            .update({
          'scans_today': current + 1,
        }).eq('id', existing['id']);
      }
    } catch (e) {
      debugPrint('consumeScan failed: $e');
    }

    return getUsage();
  }

  Future<void> autoSaveScan({
    required String lookName,
    String? imagePath,
    String? imageUrl,
    String? skinTone,
    String? faceShape,
    Map<String, dynamic>? faceData,
    String? selectedPreset,
    List<Map<String, dynamic>>? tutorialSteps,
    Map<String, dynamic>? scanSnapshot,
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
        if (selectedPreset != null) 'selected_preset': selectedPreset,
        if (tutorialSteps != null) 'tutorial_steps': tutorialSteps,
        if (scanSnapshot != null) 'scan_snapshot': scanSnapshot,
      });
    } catch (e) {
      debugPrint('ScanQuotaService.autoSaveScan failed: $e');
    }
  }
}