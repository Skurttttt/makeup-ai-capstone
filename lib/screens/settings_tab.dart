// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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
  String _userId = '';
  String _userPhone = '';
  String _userAddress = '';

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
        _userName = fullName.trim().isNotEmpty
            ? fullName.trim()
            : name.trim().isNotEmpty
            ? name.trim()
            : 'Beauty Enthusiast';
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
                    (value) => setState(() => _notificationsEnabled = value),
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
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);
    final phoneController = TextEditingController(text: _userPhone);
    final addressController = TextEditingController(text: _userAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();
              final newAddress = addressController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(
                      data: {
                        'full_name': newName,
                        'phone_number': newPhone,
                        'phone': newPhone,
                        'address': newAddress,
                      },
                    ),
                  );
                  setState(() {
                    _userName = newName;
                    _userPhone = newPhone;
                    _userAddress = newAddress;
                  });
                  _showSettingsMessage('Profile updated');
                } catch (e) {
                  _showSettingsMessage('Error: $e');
                }
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Save'),
          ),
        ],
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Privacy Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Share Usage Data'),
              subtitle: const Text('Help us improve the app'),
              value: true,
              onChanged: (value) {},
              activeThumbColor: const Color(0xFFFF4D97),
            ),
            SwitchListTile(
              title: const Text('Personalized Recommendations'),
              subtitle: const Text('Get better product suggestions'),
              value: true,
              onChanged: (value) {},
              activeThumbColor: const Color(0xFFFF4D97),
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
                _showSettingsMessage('FAQ coming soon');
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
                _showSettingsMessage('support@beautyshop.com');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school, color: Color(0xFFFF4D97)),
              title: const Text('Tutorials'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showSettingsMessage('Tutorials coming soon');
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Send Feedback',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: feedbackController,
          decoration: const InputDecoration(
            hintText: 'Share your thoughts...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final feedback = feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                _showSettingsMessage('Thank you for your feedback!');
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _rateUs() {
    _showSettingsMessage('Rate us on the App Store');
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
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _showSettingsMessage('www.beautyshop.com'),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFFFF4D97)),
              title: const Text('Email'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _showSettingsMessage('info@beautyshop.com'),
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
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) {
        widget.onMessage('Unable to verify user');
        return;
      }
      // Re-authenticate with current password first
      await Supabase.instance.client.auth.signInWithPassword(
        email: user!.email!,
        password: _currentCtrl.text.trim(),
      );
      // Update to new password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newCtrl.text.trim()),
      );
      widget.onMessage('Password updated successfully!');
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      widget.onMessage(
        e.message.contains('Invalid') || e.message.contains('invalid')
            ? 'Current password is incorrect.'
            : 'Error: ${e.message}',
      );
    } catch (e) {
      widget.onMessage('Error: $e');
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
              const SizedBox(height: 28),

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
