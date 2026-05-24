import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';

class ClientSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientSettingsScreen({
    super.key,
    required this.clientData,
  });

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _soundEffects = true;
  bool _lowStockAlerts = true;
  bool _orderConfirmations = true;
  bool _isOnline = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Pink theme colors
  static const Color pinkPrimary = Color(0xFFFF4D8C);
  static const Color pinkDark = Color(0xFFD6336C);
  static const Color pinkLight = Color(0xFFFFB8D4);
  static const Color pinkSoft = Color(0xFFFFF0F5);
  static const Color pinkAccent = Color(0xFFFF6B9D);
  static const Color pinkDeep = Color(0xFFC71563);

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final uid = ChatService.instance.supabaseClient.auth.currentUser?.id;
      if (uid == null) return;
      final row = await ChatService.instance.supabaseClient
          .from('accounts')
          .select('is_online')
          .eq('id', uid)
          .maybeSingle();
      if (mounted) setState(() => _isOnline = row?['is_online'] == true);
    } catch (_) {}
  }

  Future<void> _toggleOnline(bool val) async {
    setState(() => _isOnline = val);
    await ChatService.instance.setOnlineStatus(val);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          color: pinkSoft.withOpacity(0.5),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(isDesktop),
                const SizedBox(height: 32),

                // Content Layout
                if (isDesktop)
                  _buildDesktopLayout()
                else
                  _buildMobileLayout(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pinkDark, pinkPrimary, pinkAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings ⚙️',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customize your experience',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Colors.white.withOpacity(0.9), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Secured',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildChatBotCard(),
              const SizedBox(height: 24),
              _buildNotificationsCard(),
              const SizedBox(height: 24),
              _buildAppearanceCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildAccountCard(),
              const SizedBox(height: 24),
              _buildStoreInfoCard(),
              const SizedBox(height: 24),
              _buildDangerZoneCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildChatBotCard(),
        const SizedBox(height: 16),
        _buildNotificationsCard(),
        const SizedBox(height: 16),
        _buildAppearanceCard(),
        const SizedBox(height: 16),
        _buildAccountCard(),
        const SizedBox(height: 16),
        _buildStoreInfoCard(),
        const SizedBox(height: 16),
        _buildDangerZoneCard(),
      ],
    );
  }

  Widget _buildChatBotCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pinkPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: pinkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Chat & AI Bot 🤖',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            icon: _isOnline
                ? Icons.circle
                : Icons.circle_outlined,
            title: 'Online Status',
            subtitle: _isOnline
                ? 'You are online — AI bot is OFF (you reply to buyers)'
                : 'You are offline — AI bot is ON (bot handles buyer messages)',
            value: _isOnline,
            onChanged: _toggleOnline,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isOnline
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _isOnline
                      ? Icons.person_rounded
                      : Icons.smart_toy_rounded,
                  color: _isOnline
                      ? const Color(0xFF388E3C)
                      : const Color(0xFFF57C00),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOnline
                        ? 'Buyers will see you as available. AI bot is disabled.'
                        : 'AI bot will auto-reply when buyers message. Turn on to handle chats yourself.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOnline
                          ? const Color(0xFF388E3C)
                          : const Color(0xFFF57C00),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pinkPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: pinkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Notifications 🔔',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            icon: Icons.email_rounded,
            title: 'Email Notifications',
            subtitle: 'Receive updates via email',
            value: _emailNotifications,
            onChanged: (val) => setState(() => _emailNotifications = val),
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildSwitchTile(
            icon: Icons.notifications_rounded,
            title: 'Push Notifications',
            subtitle: 'Get alerts on your device',
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildSwitchTile(
            icon: Icons.warning_amber_rounded,
            title: 'Low Stock Alerts',
            subtitle: 'Get notified when stock is low',
            value: _lowStockAlerts,
            onChanged: (val) => setState(() => _lowStockAlerts = val),
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildSwitchTile(
            icon: Icons.receipt_long_rounded,
            title: 'Order Confirmations',
            subtitle: 'Receive order confirmation alerts',
            value: _orderConfirmations,
            onChanged: (val) => setState(() => _orderConfirmations = val),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pinkPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: pinkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Appearance 🎨',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Switch to dark theme',
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
              _showSuccessMessage('Dark Mode ${val ? "enabled" : "disabled"} 🌙');
            },
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildSwitchTile(
            icon: Icons.volume_up_rounded,
            title: 'Sound Effects',
            subtitle: 'Play sounds for actions',
            value: _soundEffects,
            onChanged: (val) => setState(() => _soundEffects = val),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pinkPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: pinkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Account 👤',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActionTile(
            icon: Icons.lock_rounded,
            title: 'Change Password',
            subtitle: 'Update your security credentials',
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildActionTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: pinkSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'EN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pinkPrimary,
                ),
              ),
            ),
            onTap: _showLanguageDialog,
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _buildActionTile(
            icon: Icons.info_rounded,
            title: 'About',
            subtitle: 'App version and information',
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pinkPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: pinkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Store Information 🏪',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Store ID', widget.clientData['id']?.toString() ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow('Store Name', widget.clientData['business_name']?.toString() ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Member Since',
            DateFormat('MMMM d, yyyy').format(DateTime.now()),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Account Type', 'Business Account'),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Danger Zone ⚠️',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmResetPreferences,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset All Preferences'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmDeleteAccount,
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Delete Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: pinkSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: pinkPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: pinkPrimary,
            activeTrackColor: pinkPrimary.withOpacity(0.3),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: pinkSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: pinkPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pinkSoft.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: pinkDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;
    double strength = 0;
    String? errorMsg;

    void calcStrength(String v, StateSetter set) {
      double s = 0;
      if (v.length >= 8) s += 0.25;
      if (v.contains(RegExp(r'[A-Z]'))) s += 0.25;
      if (v.contains(RegExp(r'[0-9]'))) s += 0.25;
      if (v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.25;
      set(() => strength = s);
    }

    Color strengthColor(double s) {
      if (s <= 0.25) return Colors.red;
      if (s <= 0.5) return Colors.orange;
      if (s <= 0.75) return Colors.yellow.shade700;
      return Colors.green;
    }

    String strengthLabel(double s) {
      if (s <= 0.25) return 'Weak';
      if (s <= 0.5) return 'Fair';
      if (s <= 0.75) return 'Good';
      return 'Strong';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setSheet(() { loading = true; errorMsg = null; });
            try {
              final user = Supabase.instance.client.auth.currentUser;
              if (user?.email == null) {
                setSheet(() { errorMsg = 'No authenticated user.'; loading = false; });
                return;
              }
              try {
                await Supabase.instance.client.auth.signInWithPassword(
                  email: user!.email!,
                  password: currentCtrl.text.trim(),
                );
              } on AuthException {
                setSheet(() { errorMsg = 'Current password is incorrect.'; loading = false; });
                return;
              }
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(password: newCtrl.text.trim()),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _showSuccessMessage('Password updated successfully! 🔒');
            } on AuthException catch (e) {
              setSheet(() { errorMsg = e.message; loading = false; });
            } catch (_) {
              setSheet(() { errorMsg = 'Something went wrong. Please try again.'; loading = false; });
            }
          }

          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: pinkPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.lock_reset, color: pinkPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1D2E))),
                          Text('Keep your account secure', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 24),
                    // Current password
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: !showCurrent,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline, color: pinkPrimary),
                        suffixIcon: IconButton(
                          icon: Icon(showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[500], size: 20),
                          onPressed: () => setSheet(() => showCurrent = !showCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: pinkPrimary, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // New password
                    TextFormField(
                      controller: newCtrl,
                      obscureText: !showNew,
                      onChanged: (v) => calcStrength(v, setSheet),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a new password';
                        if (v.length < 8) return 'At least 8 characters required';
                        if (!v.contains(RegExp(r'[A-Z]'))) return 'Add at least one uppercase letter';
                        if (!v.contains(RegExp(r'[0-9]'))) return 'Add at least one number';
                        if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) return 'Add at least one symbol';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_open_outlined, color: pinkPrimary),
                        suffixIcon: IconButton(
                          icon: Icon(showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[500], size: 20),
                          onPressed: () => setSheet(() => showNew = !showNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: pinkPrimary, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    if (newCtrl.text.isNotEmpty) ...[  
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: strength,
                              minHeight: 6,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(strengthColor(strength)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(strengthLabel(strength), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: strengthColor(strength))),
                      ]),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        'Min. 8 characters with uppercase, lowercase, number & symbol for a strong password.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Confirm password
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: !showConfirm,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm password';
                        if (v != newCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.lock_outline, color: pinkPrimary),
                        suffixIcon: IconButton(
                          icon: Icon(showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[500], size: 20),
                          onPressed: () => setSheet(() => showConfirm = !showConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: pinkPrimary, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (errorMsg != null) ...[  
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pinkPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: pinkPrimary.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: loading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.language_rounded, color: pinkPrimary),
            const SizedBox(width: 12),
            const Text('Select Language', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', 'EN', true),
            _buildLanguageOption('Tagalog', 'TL', false),
            _buildLanguageOption('Español', 'ES', false),
            _buildLanguageOption('中文', 'ZH', false),
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

  Widget _buildLanguageOption(String language, String code, bool isSelected) {
    return RadioListTile<bool>(
      value: true,
      groupValue: isSelected ? true : false,
      onChanged: (val) {
        Navigator.pop(context);
        _showSuccessMessage('Language set to $language 🌐');
      },
      title: Text(language),
      subtitle: Text(code),
      activeColor: pinkPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('About', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [pinkSoft, pinkLight.withOpacity(0.3)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 48,
                color: pinkPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Seller Centre',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: pinkPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: pinkSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: pinkPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your complete solution for managing your beauty business online. 💖',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialIcon(Icons.facebook, const Color(0xFF1877F2)),
                const SizedBox(width: 12),
                _buildSocialIcon(Icons.camera_alt, pinkPrimary),
                const SizedBox(width: 12),
                _buildSocialIcon(Icons.alternate_email, const Color(0xFF1DA1F2)),
              ],
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

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _confirmResetPreferences() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Reset Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This will reset all your preferences to their default values. This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _emailNotifications = true;
                _pushNotifications = true;
                _darkMode = false;
                _soundEffects = true;
                _lowStockAlerts = true;
                _orderConfirmations = true;
              });
              Navigator.pop(context);
              _showSuccessMessage('Preferences reset to defaults 🔄');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? All your data will be permanently removed. This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage('Account deletion requested');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }
}