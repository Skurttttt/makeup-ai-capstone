// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../utils/logout_util.dart';
import 'user_subscription_page.dart';
import 'chat_list_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _supabaseService = SupabaseService();

  String _userEmail = '';
  String _userName = '';
  String _userFirstName = '';
  String _userLastName = '';
  String _userId = '';
  String _userPhone = '';
  String _userAddress = '';
  String _userCity = '';
  String _userPostalCode = '';
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _isUploadingAvatar = false;
  final ImagePicker _avatarPicker = ImagePicker();

  // Current subscription state
  bool _subscriptionLoading = true;
  String _currentPlanName = 'Free Plan';
  String? _currentPlanBadge;
  DateTime? _currentPlanRenewsAt;
  bool _hasActiveSubscription = false;

  // Plan tier: 'regular' | 'pro' | 'premium'
  String _planTier = 'regular';
  // ignore: unused_field
  bool _canSaveResults = false;
  // ignore: unused_field
  bool _canExportHd = false;
  // ignore: unused_field
  bool _removeWatermark = false;
  int _dailyScanLimit = 5;
  int _scansUsedToday = 0;
  bool get _isRegular => _planTier == 'regular';
  bool get _isPro => _planTier == 'pro';
  bool get _isPremium => _planTier == 'premium';
  bool get _hasUnlimitedScans => _dailyScanLimit < 0;
  int get _scansRemaining =>
      _hasUnlimitedScans ? -1 : (_dailyScanLimit - _scansUsedToday).clamp(0, _dailyScanLimit);

  // Settings state
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _faceRecognitionEnabled = true;
  bool _autoSaveLooks = true;
  bool _shareUsageData = true;
  bool _personalizedRecommendations = true;

  // Support contact info (centralized)
  static const String _supportEmail = 'support@beautyshop.com';
  static const String _appPackageId = 'com.example.flutter_application_1';

  int _savedLooksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
    _loadCurrentSubscription();
    _loadTodaysScans();
    _loadSavedLooksCount();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final fullName = meta['full_name'] as String? ?? '';
      final name = meta['name'] as String? ?? '';
      setState(() {
        _userEmail = user.email ?? '';
        _userId = user.id;
        _userPhone =
            (meta['phone_number'] as String? ?? meta['phone'] as String? ?? '')
                .trim();
        _userAddress = (meta['address'] as String? ?? '').trim();
        _userCity = (meta['city'] as String? ?? '').trim();
        _userPostalCode = (meta['postal_code'] as String? ?? '').trim();
        _userFirstName = (meta['first_name'] as String? ?? '').trim();
        _userLastName = (meta['last_name'] as String? ?? '').trim();
        _userName = fullName.trim().isNotEmpty
            ? fullName.trim()
            : name.trim().isNotEmpty
            ? name.trim()
            : 'Beauty Enthusiast';
        // Back-fill first/last from full_name if not stored separately
        if (_userFirstName.isEmpty && _userName.isNotEmpty && _userName != 'Beauty Enthusiast') {
          final parts = _userName.split(' ');
          _userFirstName = parts.first;
          _userLastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
        _avatarUrl = (meta['avatar_url'] as String?) ?? null;
        _avatarBytes = null;
      });
      debugPrint('Loaded user id: $_userId');
    }
  }

  void _loadSettings() {
    // Load settings from shared preferences or local storage
  }

  Future<void> _loadCurrentSubscription() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _subscriptionLoading = false);
      return;
    }

    try {
      final subs = await _supabaseService.getUserSubscriptions(user.id);

      // Find the active subscription with the latest period end
      Map<String, dynamic>? active;
      for (final sub in subs) {
        if ((sub['status']?.toString().toLowerCase()) == 'active') {
          if (active == null) {
            active = sub;
          } else {
            final aEnd = DateTime.tryParse(
              active['current_period_end']?.toString() ?? '',
            );
            final sEnd = DateTime.tryParse(
              sub['current_period_end']?.toString() ?? '',
            );
            if (sEnd != null && (aEnd == null || sEnd.isAfter(aEnd))) {
              active = sub;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _subscriptionLoading = false;
        if (active != null) {
          _hasActiveSubscription = true;
          final plan = active['subscription_plans'] as Map<String, dynamic>?;
          _currentPlanName =
              (plan?['display_name'] ?? plan?['name'] ?? 'Active Plan')
                  .toString();
          _currentPlanBadge = plan?['badge_text']?.toString();
          _currentPlanRenewsAt = DateTime.tryParse(
            active['current_period_end']?.toString() ?? '',
          );
          _applyPlanCapabilities(plan);
        } else {
          _hasActiveSubscription = false;
          _currentPlanName = 'Free Plan';
          _currentPlanBadge = null;
          _currentPlanRenewsAt = null;
          _applyPlanCapabilities(null);
        }
      });
    } catch (e) {
      debugPrint('Settings: failed to load subscription: $e');
      if (mounted) {
        setState(() {
          _subscriptionLoading = false;
          _hasActiveSubscription = false;
          _currentPlanName = 'Free Plan';
          _applyPlanCapabilities(null);
        });
      }
    }
  }

  /// Resolves the user's plan tier and capability flags from the active
  /// subscription_plans row. When [plan] is null the user is treated as
  /// Regular (free).
  void _applyPlanCapabilities(Map<String, dynamic>? plan) {
    final raw = (plan?['name'] ?? plan?['display_name'] ?? '')
        .toString()
        .toLowerCase();
    if (raw.contains('premium') || raw.contains('lifetime')) {
      _planTier = 'premium';
    } else if (raw.contains('pro')) {
      _planTier = 'pro';
    } else {
      _planTier = 'regular';
    }
    _canSaveResults = plan?['can_save_results'] == true || _isPro || _isPremium;
    _canExportHd = plan?['can_export_hd'] == true || _isPremium;
    _removeWatermark = plan?['remove_watermark'] == true || _isPro || _isPremium;
    final limit = plan?['daily_scan_limit'];
    if (limit is int) {
      _dailyScanLimit = limit;
    } else if (limit is num) {
      _dailyScanLimit = limit.toInt();
    } else {
      _dailyScanLimit = _isRegular ? 5 : -1;
    }
    // Pro/Premium are unlimited regardless of plan row.
    if (!_isRegular) _dailyScanLimit = -1;
  }

  /// Loads today's scan count for the current user from `usage_tracking`.
  Future<void> _loadTodaysScans() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final row = await Supabase.instance.client
          .from('usage_tracking')
          .select('scans_today')
          .eq('user_id', user.id)
          .eq('tracking_date', dateStr)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _scansUsedToday = (row?['scans_today'] as int?) ?? 0;
      });
    } catch (e) {
      debugPrint('Settings: failed to load scan usage: $e');
    }
  }

  Future<void> _loadSavedLooksCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('scans')
          .select('id')
          .eq('user_id', user.id);
      if (!mounted) return;
      setState(() {
        _savedLooksCount = (rows as List).length;
      });
    } catch (e) {
      debugPrint('Settings: failed to load saved looks count: $e');
    }
  }

  /// Time remaining until the daily scan quota resets at local midnight.
  String get _resetCountdownLabel {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return 'Resets in ${h}h ${m}m';
    return 'Resets in ${m}m';
  }

  String get _planLabel {
    switch (_planTier) {
      case 'premium':
        return 'PREMIUM';
      case 'pro':
        return 'PRO';
      default:
        return 'REGULAR';
    }
  }

  Color get _planColor {
    switch (_planTier) {
      case 'premium':
        return const Color(0xFF9C27B0);
      case 'pro':
        return const Color(0xFFFF4D97);
      default:
        return const Color(0xFF78909C);
    }
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFFF4D97),
            elevation: 0,
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.save_outlined),
                onPressed: _saveSettings,
                tooltip: 'Save Settings',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile Hero Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D97), Color(0xFFFF8DC7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D97).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName.isEmpty
                                  ? 'Beauty Enthusiast'
                                  : _userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail.isEmpty ? 'Loading...' : _userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_userPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _userPhone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (_userAddress.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _userAddress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.78),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildSubscriptionPill(),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings Sections
                _buildSection('My Beauty', [
                  _buildSettingItem(
                    Icons.favorite_outline,
                    'Saved Looks',
                    '$_savedLooksCount items',
                    () => _showSavedLooksDialog(),
                    const Color(0xFFFF4D97),
                  ),
                  _buildSwitchItem(
                    Icons.face_retouching_natural,
                    'Face Recognition',
                    _faceRecognitionEnabled,
                    (value) => setState(() => _faceRecognitionEnabled = value),
                    const Color(0xFF8B5CF6),
                  ),
                  _buildSwitchItem(
                    Icons.auto_awesome,
                    'Auto-Save Looks',
                    _autoSaveLooks,
                    (value) => setState(() => _autoSaveLooks = value),
                    const Color(0xFF10B981),
                  ),
                  if (_isPremium)
                    _buildSettingItem(
                      Icons.high_quality_outlined,
                      'HD Export',
                      'Enabled — export looks in HD',
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('HD export is enabled for your account.'),
                        ),
                      ),
                      const Color(0xFF9C27B0),
                    ),
                ]),

                // Daily scans usage card (always shown)
                _buildScanUsageCard(),

                // Upgrade promo only for Regular users
                if (_isRegular) _buildUpgradeCard(),


                _buildSection('Account Settings', [
                  _buildSettingItem(
                    Icons.workspace_premium_outlined,
                    'My Subscription',
                    _subscriptionLoading
                        ? 'Loading…'
                        : (_hasActiveSubscription
                            ? '$_currentPlanName · $_planLabel'
                            : 'Regular Plan · Tap to upgrade'),
                    () => _openMySubscription(),
                    _planColor,
                  ),
                  _buildSettingItem(
                    Icons.person_outline,
                    'Edit Profile',
                    null,
                    () => _showEditProfileDialog(),
                    const Color(0xFF4568DC),
                  ),
                  _buildSettingItem(
                    Icons.lock_outline,
                    'Change Password',
                    null,
                    () => _showChangePasswordDialog(),
                    const Color(0xFF3B82F6),
                  ),
                  _buildSettingItem(
                    Icons.chat_bubble_outline,
                    'My Messages',
                    'Chat with sellers',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatListScreen(),
                      ),
                    ),
                    const Color(0xFFFF4D97),
                  ),
                  _buildSwitchItem(
                    Icons.notifications_outlined,
                    'Notifications',
                    _notificationsEnabled,
                    (value) {
                      setState(() => _notificationsEnabled = value);
                      _showSettingsMessage(
                        value
                            ? 'Notifications enabled'
                            : 'Notifications muted',
                      );
                    },
                    const Color(0xFF6366F1),
                  ),
                  _buildSettingItem(
                    Icons.privacy_tip_outlined,
                    'Privacy Settings',
                    null,
                    () => _showPrivacyDialog(),
                    const Color(0xFF8B5CF6),
                  ),
                ]),

                _buildSection('Preferences', [
                  _buildSettingItem(
                    Icons.language,
                    'Language',
                    _selectedLanguage,
                    () => _showLanguageDialog(),
                    const Color(0xFF06B6D4),
                  ),
                  _buildSettingItem(
                    Icons.storage,
                    'Storage & Cache',
                    null,
                    () => _showStorageDialog(),
                    const Color(0xFF64748B),
                  ),
                ]),

                _buildSection('Support', [
                  _buildSettingItem(
                    Icons.help_outline,
                    'Help Center',
                    null,
                    () => _showHelpDialog(),
                    const Color(0xFF10B981),
                  ),
                  _buildSettingItem(
                    Icons.feedback_outlined,
                    'Send Feedback',
                    null,
                    () => _showFeedbackDialog(),
                    const Color(0xFF059669),
                  ),
                  _buildSettingItem(
                    Icons.star_outline,
                    'Rate Us',
                    null,
                    () => _rateUs(),
                    const Color(0xFFF59E0B),
                  ),
                  _buildSettingItem(
                    Icons.info_outline,
                    'About',
                    null,
                    () => _showAboutDialog(),
                    const Color(0xFF0EA5E9),
                  ),
                ]),

                _buildSection('Legal', [
                  _buildSettingItem(
                    Icons.description_outlined,
                    'Terms of Service',
                    null,
                    () => _showTermsDialog(),
                    const Color(0xFF94A3B8),
                  ),
                  _buildSettingItem(
                    Icons.policy_outlined,
                    'Privacy Policy',
                    null,
                    () => _showPrivacyPolicyDialog(),
                    const Color(0xFF94A3B8),
                  ),
                ]),

                const SizedBox(height: 16),
                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        'LOG OUT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D97),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFFFF4D97).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMySubscription() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserSubscriptionPage()),
    );
    if (mounted) _loadCurrentSubscription();
  }

  Widget _buildSubscriptionPill() {
    final loading = _subscriptionLoading;
    final hasActive = _hasActiveSubscription;
    final renewsAt = _currentPlanRenewsAt;

    final IconData icon = hasActive
        ? Icons.workspace_premium_rounded
        : Icons.card_membership_outlined;

    String label;
    if (loading) {
      label = 'Checking subscription…';
    } else {
      label = _currentPlanName;
      if (_currentPlanBadge != null && _currentPlanBadge!.isNotEmpty) {
        label = '$label · ${_currentPlanBadge!}';
      }
    }

    String? subline;
    if (!loading && hasActive && renewsAt != null) {
      subline = 'Renews ${DateFormat('MMM d, yyyy').format(renewsAt)}';
    } else if (!loading && !hasActive) {
      subline = 'Tap to upgrade';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subline != null)
                  Text(
                    subline,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanUsageCard() {
    final pct = _hasUnlimitedScans
        ? 1.0
        : (_dailyScanLimit == 0
            ? 0.0
            : (_scansUsedToday / _dailyScanLimit).clamp(0.0, 1.0));
    final color = _hasUnlimitedScans
        ? const Color(0xFF9C27B0)
        : (_scansRemaining == 0
            ? Colors.red.shade400
            : const Color(0xFFFF4D97));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bolt_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Face Scans',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    Text(
                      _hasUnlimitedScans
                          ? 'Unlimited scans on $_planLabel'
                          : '$_scansUsedToday / $_dailyScanLimit used today',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasUnlimitedScans)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '∞',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _hasUnlimitedScans
                      ? 'No daily cap'
                      : (_scansRemaining == 0
                          ? "You've reached today's limit"
                          : '$_scansRemaining scans left today'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
              if (!_hasUnlimitedScans)
                Text(
                  _resetCountdownLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4D97), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D97).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _openMySubscription,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.workspace_premium,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Go unlimited with Pro & Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _upgradePerk(Icons.all_inclusive,
                    'Unlimited face scans — no waiting until midnight'),
                _upgradePerk(Icons.cloud_done_outlined,
                    'Auto-saved looks synced across devices'),
                _upgradePerk(Icons.high_quality_outlined,
                    'HD downloads & no watermark (Premium)'),
                _upgradePerk(Icons.support_agent,
                    'Priority support from our beauty team'),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'From ₱99/week',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See plans',
                            style: TextStyle(
                              color: Color(0xFFFF4D97),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              color: Color(0xFFFF4D97), size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _upgradePerk(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D97),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap,
    Color iconColor, {
    bool locked = false,
    String? requiredTier,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (locked ? Colors.grey : iconColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: locked ? Colors.grey : iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            color: locked
                                ? Colors.grey.shade500
                                : const Color(0xFF1A1D2E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (locked && requiredTier != null) ...[
                        const SizedBox(width: 8),
                        _buildTierBadge(requiredTier),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                locked ? Icons.lock_outline : Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    final color = tier == 'PREMIUM'
        ? const Color(0xFF9C27B0)
        : const Color(0xFFFF4D97);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tier,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showUpgradePrompt(String feature, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Color(0xFFFF4D97)),
            const SizedBox(width: 10),
            Expanded(child: Text(feature)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('See plans'),
          ),
        ],
      ),
    );
    if (result == true && mounted) _openMySubscription();
  }

  Widget _buildSwitchItem(
    IconData icon,
    String title,
    bool value,
    Function(bool) onChanged,
    Color iconColor, {
    bool locked = false,
    String? requiredTier,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (locked ? Colors.grey : iconColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: locked ? Colors.grey : iconColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: locked
                          ? Colors.grey.shade500
                          : const Color(0xFF1A1D2E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (locked && requiredTier != null) ...[
                  const SizedBox(width: 8),
                  _buildTierBadge(requiredTier),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF4D97),
            activeTrackColor: const Color(0xFFFF4D97).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog() {
    const faqs = [
      (
        q: 'How does the AI skin scan work?',
        a: 'Open the camera tab and press Scan. The AI analyzes your skin tone, undertone, and features to recommend compatible makeup looks and products.'
      ),
      (
        q: 'How do I try on a makeup look?',
        a: 'After scanning, tap any recommended look. You can preview the look using AR try-on or follow the step-by-step tutorial.'
      ),
      (
        q: 'How do I purchase products?',
        a: 'Go to the Market tab, browse or search for products, tap a product to view details, and add it to your cart. Checkout supports GCash and card payments.'
      ),
      (
        q: 'How do I track my orders?',
        a: 'Go to Settings → My Orders to see all your past and active orders with status updates.'
      ),
      (
        q: 'Can I use the app without creating an account?',
        a: 'You can browse products as a guest, but scanning, purchasing, and saving looks require a free account.'
      ),
      (
        q: 'How do I cancel or return an order?',
        a: 'Contact support within 24 hours of placing your order. Returns are accepted within 7 days of delivery.'
      ),
      (
        q: 'Why are some products out of stock?',
        a: 'Sellers update their stock in real time. Save a product to your wishlist and check back later.'
      ),
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFF4D97), Color(0xFFCC3A7A)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.question_answer, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Frequently Asked Questions',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: faqs.map((faq) => Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        childrenPadding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                        iconColor: const Color(0xFFFF4D97),
                        collapsedIconColor: Colors.black54,
                        title: Text(faq.q,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        children: [
                          Text(faq.a,
                              style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactSupportDialog() {
    final messageController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFF4D97), Color(0xFFCC3A7A)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contact_support, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Contact Support',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('We typically reply within 24 hours.',
                        style: TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        filled: true,
                        fillColor: const Color(0xFFFFF9FB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: const Color(0xFFFFF9FB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D97),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final subjectText = subjectController.text.trim();
                              final messageText = messageController.text.trim();
                              // Save to Supabase so admin gets notified
                              final inserted = await _supabaseService.insertSupportRequest(
                                subject: subjectText,
                                message: messageText,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              if (inserted != null && inserted['id'] != null) {
                                _showSettingsMessage('Thanks — saved (id: ${inserted['id']}).');
                              } else {
                                _showSettingsMessage('Could not save support request — please try again or contact the admin.');
                              }
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('Send Email'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTutorialsDialog() {
    const tutorials = [
      (
        icon: Icons.face_retouching_natural,
        title: 'Getting Your First Scan',
        steps: [
          'Open the app and go to the Camera tab.',
          'Make sure you are in good lighting facing the camera.',
          'Tap the Scan button and hold still for 2–3 seconds.',
          'Your skin tone, undertone and features will be analyzed.',
          'Recommended looks and products appear instantly.',
        ]
      ),
      (
        icon: Icons.auto_fix_high,
        title: 'Trying On a Look',
        steps: [
          'After scanning, scroll through your recommended looks.',
          'Tap any look card to open the detail view.',
          'Tap "Try On" to see the look applied in AR.',
          'Use the sliders to adjust intensity.',
          'Save the look to your profile or share it.',
        ]
      ),
      (
        icon: Icons.shopping_bag_outlined,
        title: 'Buying Products',
        steps: [
          'Tap the Market tab at the bottom.',
          'Browse by category or use the search bar.',
          'Tap a product to see details, shades, and reviews.',
          'Tap "Add to Cart" and proceed to Checkout.',
          'Choose GCash, card, or COD and confirm your order.',
        ]
      ),
      (
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        steps: [
          'Tap the bell icon at the top of your screen.',
          'See order updates, new messages, and low-stock alerts.',
          'Tap a notification to jump to the relevant screen.',
          'Tap "Mark all read" to clear the badge.',
        ]
      ),
    ];

    int selectedIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFF4D97), Color(0xFFCC3A7A)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Tutorials',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(tutorials.length, (i) {
                            final t = tutorials[i];
                            final selected = i == selectedIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setDialogState(() => selectedIndex = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFFF4D97)
                                        : const Color(0xFFFFF0F5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(t.icon,
                                          size: 16,
                                          color: selected ? Colors.white : const Color(0xFFFF4D97)),
                                      const SizedBox(width: 6),
                                      Text(t.title,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: selected ? Colors.white : const Color(0xFFFF4D97))),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(
                        tutorials[selectedIndex].steps.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4D97),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(tutorials[selectedIndex].steps[i],
                                    style: const TextStyle(fontSize: 14, height: 1.5)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditProfileDialog() {
    final firstNameController = TextEditingController(text: _userFirstName);
    final lastNameController = TextEditingController(text: _userLastName);
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);
    final phoneController = TextEditingController(text: _userPhone);
    final addressController = TextEditingController(text: _userAddress);
    final cityController = TextEditingController(text: _userCity);
    final postalController = TextEditingController(text: _userPostalCode);
    const Color primaryPink = Color(0xFFFF4D97);
    const Color pinkDeep = Color(0xFFCC3A7A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool saving = false;
        final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> _pickAndUploadProfileImage() async {
              if (_isUploadingAvatar) return;
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;
              XFile? pickedFile;
              try {
                pickedFile = await _avatarPicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (pickedFile == null) return;
              } catch (_) {
                return;
              }
              setSheetState(() => _isUploadingAvatar = true);
              try {
                final bytes = await pickedFile.readAsBytes();
                final safeName = pickedFile.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
                final extension = RegExp(r'\.(\w+)\$').firstMatch(pickedFile.name)?.group(1)?.toLowerCase() ?? 'png';
                final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName.$extension';
                final storagePath = '${user.id}/avatars/$fileName';

                await Supabase.instance.client.storage.from('scan-images').uploadBinary(
                  storagePath,
                  bytes,
                  fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
                );

                final publicUrl = Supabase.instance.client.storage
                    .from('scan-images')
                    .getPublicUrl(storagePath);

                // Update accounts table and auth metadata
                await Supabase.instance.client
                    .from('accounts')
                    .update({'avatar_url': publicUrl})
                    .eq('id', user.id);
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(data: {'avatar_url': publicUrl}),
                  );
                } catch (_) {}

                if (!mounted) return;
                setState(() {
                  _avatarBytes = bytes;
                  _avatarUrl = publicUrl;
                });
                setSheetState(() => _isUploadingAvatar = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile photo updated')),
                );
              } catch (e) {
                setSheetState(() => _isUploadingAvatar = false);
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text('Upload failed: $e')),
                  );
                }
              }
            }

            Future<void> handleSave() async {
              final newFirst = firstNameController.text.trim();
              final newLast = lastNameController.text.trim();
              final newName = '$newFirst $newLast'.trim();
              final newPhone = phoneController.text.trim();
              final newAddress = addressController.text.trim();
              final newCity = cityController.text.trim();
              final newPostal = postalController.text.trim();
              if (newFirst.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('First name cannot be empty')),
                );
                return;
              }
              setSheetState(() => saving = true);
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(
                    data: {
                      'full_name': newName,
                      'first_name': newFirst,
                      'last_name': newLast,
                      'phone_number': newPhone,
                      'phone': newPhone,
                      'address': newAddress,
                      'city': newCity,
                      'postal_code': newPostal,
                    },
                  ),
                );
                if (mounted) {
                  setState(() {
                    _userName = newName;
                    _userFirstName = newFirst;
                    _userLastName = newLast;
                    _userPhone = newPhone;
                    _userAddress = newAddress;
                    _userCity = newCity;
                    _userPostalCode = newPostal;
                  });
                  _showSettingsMessage('Profile updated');
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              } catch (e) {
                setSheetState(() => saving = false);
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Gradient header with avatar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryPink, pinkDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _avatarBytes != null || _avatarUrl != null
                                      ? CircleAvatar(
                                          radius: 36,
                                          backgroundImage: _avatarBytes != null
                                              ? MemoryImage(_avatarBytes!) as ImageProvider
                                              : NetworkImage(_avatarUrl!),
                                          backgroundColor: Colors.white,
                                        )
                                      : Text(
                                          initial,
                                          style: const TextStyle(
                                            color: primaryPink,
                                            fontSize: 36,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [primaryPink, pinkDeep]),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryPink.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isUploadingAvatar ? null : _pickAndUploadProfileImage,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: _isUploadingAvatar
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.camera_alt_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your personal info',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form fields
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          children: [
                            _buildEditField(controller: nameController, label: 'Full Name', icon: Icons.person_outline),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _buildEditField(controller: firstNameController, label: 'First Name', icon: Icons.badge_outlined)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildEditField(controller: lastNameController, label: 'Last Name', icon: Icons.badge_outlined)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildEditField(controller: emailController, label: 'Email', icon: Icons.email_outlined, enabled: false),
                            const SizedBox(height: 14),
                            _buildEditField(controller: phoneController, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                            const SizedBox(height: 14),
                            _buildEditField(controller: addressController, label: 'Address', icon: Icons.location_on_outlined, maxLines: 2),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(flex: 2, child: _buildEditField(controller: cityController, label: 'City', icon: Icons.location_city_outlined)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildEditField(controller: postalController, label: 'Postal', icon: Icons.markunread_mailbox_outlined, keyboardType: TextInputType.number)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving ? null : () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: saving ? null : handleSave,
                              style: ElevatedButton.styleFrom(backgroundColor: primaryPink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                              child: saving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 18), SizedBox(width: 6), Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700))]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    const Color primaryPink = Color(0xFFFF4D97);
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: primaryPink, size: 20),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPink, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onMessage: _showSettingsMessage,
      ),
    );
  }

  // _showVerifyCurrentPasswordDialog and _showSetNewPasswordDialog
  // are replaced by the _ChangePasswordSheet widget below.

  void _showLanguageDialog() {
    final languages = [
      'English',
      'Filipino',
      'Spanish',
      'French',
      'Japanese',
      'Korean',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Select Language',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: languages.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final language = languages[index];
              return ListTile(
                title: Text(language),
                trailing: _selectedLanguage == language
                    ? const Icon(Icons.check, color: Color(0xFFFF4D97))
                    : null,
                onTap: () {
                  setState(() => _selectedLanguage = language);
                  Navigator.pop(context);
                  _showSettingsMessage('Language changed to $language');
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _gradientDialogHeader(
                  context: dialogContext,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Settings',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Share Usage Data',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Help us improve the app'),
                        value: _shareUsageData,
                        onChanged: (value) {
                          setDialogState(() => _shareUsageData = value);
                          setState(() => _shareUsageData = value);
                        },
                        activeThumbColor: const Color(0xFFFF4D97),
                      ),
                      SwitchListTile(
                        title: const Text('Personalized Recommendations',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle:
                            const Text('Get better product suggestions'),
                        value: _personalizedRecommendations,
                        onChanged: (value) {
                          setDialogState(
                              () => _personalizedRecommendations = value);
                          setState(
                              () => _personalizedRecommendations = value);
                        },
                        activeThumbColor: const Color(0xFFFF4D97),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable gradient header for dialogs (matches Contact Support style).
  Widget _gradientDialogHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF4D97), Color(0xFFCC3A7A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showStorageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Storage',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFFF4D97),
              ),
              title: const Text('Cached Images'),
              trailing: Text(
                '24.5 MB',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Clear Cache'),
              trailing: ElevatedButton(
                onPressed: () {
                  _showSettingsMessage('Cache cleared');
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(70, 32),
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.question_answer,
                color: Color(0xFFFF4D97),
              ),
              title: const Text('FAQ'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showFaqDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.contact_support,
                color: Color(0xFFFF4D97),
              ),
              title: const Text('Contact Support'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showContactSupportDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school, color: Color(0xFFFF4D97)),
              title: const Text('Tutorials'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showTutorialsDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    int selectedRating = 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _gradientDialogHeader(
                  context: dialogContext,
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "We'd love to hear what you think.",
                        style:
                            TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      // ── Star rating ──────────────────────────────────
                      const Text('How would you rate your experience?',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedRating = star),
                            child: Icon(
                              star <= selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: star <= selectedRating
                                  ? const Color(0xFFFFB400)
                                  : Colors.grey.shade400,
                              size: 36,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      // ── Message ──────────────────────────────────────
                      TextField(
                        controller: feedbackController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts...',
                          filled: true,
                          fillColor: const Color(0xFFFFF9FB),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFFFF4D97),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final message =
                                    feedbackController.text.trim();
                                if (message.isEmpty) {
                                  _showSettingsMessage(
                                      'Please enter your feedback first');
                                  return;
                                }
                                Navigator.pop(dialogContext);
                                try {
                                  final inserted =
                                      await _supabaseService.insertFeedback(
                                    rating: selectedRating > 0
                                        ? selectedRating
                                        : null,
                                    message: message,
                                  );
                                  if (!mounted) return;
                                  if (inserted != null &&
                                      inserted['id'] != null) {
                                    _showSettingsMessage(
                                        'Thanks for your feedback!');
                                  } else {
                                    _showSettingsMessage(
                                        'Could not save feedback — please try again.');
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  _showSettingsMessage(
                                      'Could not send feedback: $e');
                                }
                              },
                              icon: const Icon(Icons.send),
                              label: const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rateUs() async {
    final playStore = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_appPackageId',
    );
    if (await canLaunchUrl(playStore)) {
      await launchUrl(playStore, mode: LaunchMode.externalApplication);
    } else {
      _showSettingsMessage('Thanks! Please rate us on the Play Store.');
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront, size: 64, color: Color(0xFFFF4D97)),
            const SizedBox(height: 12),
            const Text(
              'Beauty Shop',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Version 1.0.0', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            const Text(
              'Your one-stop beauty destination for makeup and skincare products.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.web, color: Color(0xFFFF4D97)),
              title: const Text('Website'),
              subtitle: const Text('www.beautyshop.com'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                final uri = Uri.parse('https://www.beautyshop.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                } else {
                  _showSettingsMessage('Visit www.beautyshop.com');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFFFF4D97)),
              title: const Text('Email'),
              subtitle: const Text(_supportEmail),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                final uri = Uri.parse('mailto:$_supportEmail');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  _showSettingsMessage('Email: $_supportEmail');
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Terms of Service',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'Terms of Service\n\n'
              'Last updated: January 1, 2024\n\n'
              'Please read these Terms of Service carefully before using the Beauty Shop mobile application.\n\n'
              'Your access to and use of the Service is conditioned on your acceptance of and compliance with these Terms.\n\n'
              'By accessing or using the Service you agree to be bound by these Terms.\n\n'
              'If you have any questions about these Terms, please contact us at info@beautyshop.com.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'Privacy Policy\n\n'
              'Last updated: January 1, 2024\n\n'
              'This Privacy Policy describes our policies on the collection, use and disclosure of your information.\n\n'
              'We value your privacy and are committed to protecting your personal data.\n\n'
              'If you have any questions about this Privacy Policy, please contact us at info@beautyshop.com.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showLogoutConfirmationDialog(context, role: 'user');
  }

  void _showSavedLooksDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SavedLooksSheet(),
    );
  }
}

// ── Saved Looks Bottom Sheet ─────────────────────────────────────────────────

class _SavedLooksSheet extends StatefulWidget {
  const _SavedLooksSheet();

  @override
  State<_SavedLooksSheet> createState() => _SavedLooksSheetState();
}

class _SavedLooksSheetState extends State<_SavedLooksSheet> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _looks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to view your saved looks.';
      });
      return;
    }
    try {
      final rows = await _client
          .from('scans')
          .select('id, look_name, image_url, image_path, skin_tone, '
              'face_shape, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _looks = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load saved looks: $e';
      });
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete look?'),
        content: const Text('This look will be removed from your saved list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('scans').delete().eq('id', id);
      if (!mounted) return;
      setState(() => _looks.removeWhere((l) => l['id'] == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void _openLook(Map<String, dynamic> look) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 1,
                child: _LookImage(url: look['image_url']?.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (look['look_name'] ?? 'Saved Look').toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (look['created_at'] != null)
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(
                        DateTime.parse(look['created_at'].toString()).toLocal(),
                      ),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((look['skin_tone']?.toString() ?? '').isNotEmpty)
                        _MetaChip(
                            icon: Icons.color_lens_outlined,
                            label: 'Tone: ${look['skin_tone']}'),
                      if ((look['face_shape']?.toString() ?? '').isNotEmpty)
                        _MetaChip(
                            icon: Icons.face_outlined,
                            label: 'Shape: ${look['face_shape']}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _delete(look['id'].toString());
                          },
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          label: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4D97),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F4F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D97).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite,
                      color: Color(0xFFFF4D97), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Looks',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      Text(
                        'Your face scans and looks',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  color: const Color(0xFFFF4D97),
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _loading = true);
                          _load();
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (!_loading && _error == null && _looks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    '${_looks.length} ${_looks.length == 1 ? "look" : "looks"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4D97)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      );
    }
    if (_looks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 72, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No saved looks yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Scan your face and try a look — it will be saved here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _looks.length,
      itemBuilder: (_, i) {
        final look = _looks[i];
        return _LookCard(
          look: look,
          onTap: () => _openLook(look),
          onDelete: () => _delete(look['id'].toString()),
        );
      },
    );
  }
}

class _LookCard extends StatelessWidget {
  final Map<String, dynamic> look;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LookCard({
    required this.look,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = (look['look_name'] ?? 'Saved Look').toString();
    final created = look['created_at']?.toString();
    final url = look['image_url']?.toString();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox.expand(child: _LookImage(url: url)),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onDelete,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    created == null
                        ? ''
                        : DateFormat('MMM d, yyyy').format(
                            DateTime.parse(created).toLocal(),
                          ),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookImage extends StatelessWidget {
  final String? url;
  const _LookImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: const Color(0xFFFFF1F8),
        child: const Center(
          child: Icon(Icons.face_retouching_natural,
              size: 48, color: Color(0xFFFF4D97)),
        ),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null
              ? child
              : Container(
                  color: const Color(0xFFFFF1F8),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                      color: Color(0xFFFF4D97), strokeWidth: 2),
                ),
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFFFF1F8),
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              size: 40, color: Color(0xFFFF4D97)),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D97).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFF4D97)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFFF4D97),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change Password Bottom Sheet ──────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final void Function(String) onMessage;
  const _ChangePasswordSheet({required this.onMessage});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  static const _pink = Color(0xFFFF4D97);

  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  double _strength = 0;
  String? _errorMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onNewPasswordChanged(String val) {
    double s = 0;
    if (val.length >= 8) s += 0.25;
    if (val.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (val.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (val.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.25;
    setState(() => _strength = s);
  }

  Color get _strengthColor {
    if (_strength <= 0.25) return Colors.red;
    if (_strength <= 0.5) return Colors.orange;
    if (_strength <= 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String get _strengthLabel {
    if (_strength <= 0.25) return 'Weak';
    if (_strength <= 0.5) return 'Fair';
    if (_strength <= 0.75) return 'Good';
    return 'Strong';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) {
        setState(() => _errorMsg = 'No authenticated user found. Please log in again.');
        return;
      }
      // Verify current password by re-authenticating
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: user!.email!,
          password: _currentCtrl.text.trim(),
        );
      } on AuthException {
        setState(() => _errorMsg = 'Current password is incorrect.');
        return;
      }
      // Update to new password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newCtrl.text.trim()),
      );
      // Log password change
      try {
        await SupabaseService().logAdminAction(
          action: 'password_changed',
          target: 'accounts:${user.id}',
          metadata: {'method': 'in_app'},
        );
      } catch (_) {}
      // Close sheet first, then show success snackbar on the parent
      if (mounted) {
        Navigator.pop(context);
        widget.onMessage('Password updated successfully! ✓');
      }
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message.isNotEmpty ? e.message : 'Authentication error. Please try again.');
    } catch (e) {
      setState(() => _errorMsg = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset, color: _pink, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      Text(
                        'Keep your account secure',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current password
              _passwordField(
                controller: _currentCtrl,
                label: 'Current password',
                icon: Icons.lock_outline,
                show: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 16),

              // New password
              _passwordField(
                controller: _newCtrl,
                label: 'New password',
                icon: Icons.lock_open_outlined,
                show: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                onChanged: _onNewPasswordChanged,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 6) return 'At least 6 characters required';
                  return null;
                },
              ),

              // Strength bar
              if (_newCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _strength,
                          minHeight: 6,
                          backgroundColor: Colors.grey[200],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_strengthColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _strengthLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _strengthColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Confirm new password
              _passwordField(
                controller: _confirmCtrl,
                label: 'Confirm new password',
                icon: Icons.lock_outline,
                show: _showConfirm,
                onToggle: () =>
                    setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm password';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Inline error banner
              if (_errorMsg != null) ...[  
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Update button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _pink.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool show,
    required VoidCallback onToggle,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _pink),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[500],
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _pink, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
