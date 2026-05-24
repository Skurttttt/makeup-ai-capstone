// lib/screens/admin_screen_new.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import '../utils/logout_util.dart';
import 'admin_shared.dart';
import 'admin_dashboard_section.dart';
import 'admin_accounts_section.dart';
import 'admin_subscriptions_section.dart';
import 'admin_profits_section.dart';
import 'admin_audit_logs_section.dart';
import 'admin_support_section.dart';

class AdminScreenNew extends StatefulWidget {
  final String currentUserRole;
  const AdminScreenNew({super.key, this.currentUserRole = 'admin'});

  @override
  State<AdminScreenNew> createState() => _AdminScreenNewState();
}

class _AdminScreenNewState extends State<AdminScreenNew> {
  final _supabaseService = SupabaseService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentSection = 0;
  late RealtimeChannel _accountsChannel;
  late RealtimeChannel _subscriptionsChannel;
  late RealtimeChannel _auditLogsChannel;
  late RealtimeChannel _ordersChannel;
  late RealtimeChannel _supportChannel;
  late RealtimeChannel _feedbacksChannel;

  // ── Notifications ──────────────────────────────────────────────
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _notifLoading = false;
  // Track the timestamp of the last notification we've seen
  DateTime _lastSeenAt = DateTime.now();

  late final Stream<DateTime> _clockStream = Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );

  bool get _showInlineSidebar =>
      MediaQuery.of(context).size.width >= Breakpoints.medium;
  bool get _isCompact => context.isCompact;

  bool get _isSuperAdmin => widget.currentUserRole == 'super_admin';

  int _refreshCounter = 0;

  // ── Current admin user helpers ──────────────────────────────────
  User? get _currentUser => Supabase.instance.client.auth.currentUser;
  String get _adminEmail => _currentUser?.email ?? '';
  String get _adminDisplayName {
    final meta = _currentUser?.userMetadata;
    if (meta != null) {
      final name = meta['full_name'] as String? ?? meta['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    }
    final email = _adminEmail;
    return email.isNotEmpty ? email.split('@').first : 'Super Admin';
  }
  String get _adminAvatarLetter =>
      _adminDisplayName.isNotEmpty ? _adminDisplayName[0].toUpperCase() : 'S';

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_notifLoading) return;
    setState(() => _notifLoading = true);
    try {
      final items = await _supabaseService.getAdminNotifications();
      if (!mounted) return;
      final unread = items.where((n) {
        final t = DateTime.tryParse(n['created_at'] ?? '');
        return t != null && t.isAfter(_lastSeenAt);
      }).length;
      setState(() {
        _notifications = items;
        _unreadCount = unread;
        _notifLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _notifLoading = false);
    }
  }

  void _openNotificationPanel() {
    // Mark all as read
    setState(() {
      _lastSeenAt = DateTime.now();
      _unreadCount = 0;
    });
    showDialog(
      context: context,
      builder: (ctx) => _NotificationPanel(
        notifications: _notifications,
        onRefresh: _loadNotifications,
      ),
    );
  }

  void _scheduleRebuild() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _refreshCounter++);
    });
  }

  void _scheduleNotifRefresh() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNotifications();
    });
  }

  void _setupRealtimeListeners() {
    _accountsChannel = _supabaseService.client
        .channel('accounts_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          callback: (payload) => _scheduleRebuild(),
        )
        .subscribe();

    _subscriptionsChannel = _supabaseService.client
        .channel('subscriptions_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          callback: (payload) {
            _scheduleRebuild();
            if (payload.eventType == PostgresChangeEvent.insert) {
              _scheduleNotifRefresh();
            }
          },
        )
        .subscribe();

    _auditLogsChannel = _supabaseService.client
        .channel('audit_logs_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'audit_logs',
          callback: (payload) => _scheduleRebuild(),
        )
        .subscribe();

    _ordersChannel = _supabaseService.client
        .channel('orders_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _scheduleNotifRefresh(),
        )
        .subscribe();

    _supportChannel = _supabaseService.client
        .channel('support_requests_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_requests',
          callback: (payload) => _scheduleNotifRefresh(),
        )
        .subscribe();

    _feedbacksChannel = _supabaseService.client
        .channel('feedbacks_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'feedbacks',
          callback: (payload) => _scheduleNotifRefresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabaseService.client.removeChannel(_accountsChannel);
    _supabaseService.client.removeChannel(_subscriptionsChannel);
    _supabaseService.client.removeChannel(_auditLogsChannel);
    _supabaseService.client.removeChannel(_ordersChannel);
    _supabaseService.client.removeChannel(_supportChannel);
    _supabaseService.client.removeChannel(_feedbacksChannel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inlineSidebar = _showInlineSidebar;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminTheme.backgroundColor,
      drawer: inlineSidebar ? null : Drawer(child: _buildSidebar(inDrawer: true)),
      body: SafeArea(
        child: Row(
          children: [
            if (inlineSidebar) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _buildCurrentSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar({bool inDrawer = false}) {
    final sections = [
      NavigationItem(Icons.dashboard_rounded, 'Dashboard', 0),
      NavigationItem(Icons.people_rounded, 'Accounts', 1),
      NavigationItem(Icons.card_membership_rounded, 'Subscriptions', 2),
      NavigationItem(Icons.trending_up_rounded, 'Profit', 3),
      NavigationItem(Icons.receipt_long_rounded, 'Audit Logs', 4),
      NavigationItem(Icons.support_agent_rounded, 'Support/Feedbacks', 5),
    ];

    return Container(
      width: inDrawer ? null : 280,
      decoration: BoxDecoration(
        color: AdminTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Branding - Fixed overlapping PRO badge
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AdminTheme.primaryGradient,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AdminTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.accentColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fix: Better layout for title with badge
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Super Admin',
                                  style: TextStyle(
                                    fontSize: constraints.maxWidth < 120 ? 14 : 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'OWNER',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            size: 12,
                            color: AdminTheme.successColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Full System Access',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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
          
          const SizedBox(height: 24),
          
          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'MAIN MENU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 2,
                    ),
                  ),
                ),
                ...sections.map((item) => _buildNavItem(item)),
              ],
            ),
          ),
          
          // User info & logout
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AdminTheme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _adminAvatarLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _adminDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _adminEmail,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                  ),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item) {
    final isSelected = _currentSection == item.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _currentSection = item.index);
            if (!_showInlineSidebar) Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AdminTheme.accentColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AdminTheme.accentColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? AdminTheme.accentColor : Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AdminTheme.accentColor : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final sectionTitles = [
      'Dashboard Overview',
      'Account Management',
      'Subscription Management',
      'Revenue Analytics',
      'System Audit Logs',
      'Support / Feedbacks',
    ];

    final compact = _isCompact;
    final hideBreadcrumbPrefix = compact;
    final hideLiveTime = MediaQuery.of(context).size.width < Breakpoints.expanded;

    return Container(
      height: compact ? 56 : 72,
      padding: EdgeInsets.only(left: compact ? 12 : 24, right: 4),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        border: const Border(
          bottom: BorderSide(color: AdminTheme.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!_showInlineSidebar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu_rounded, color: AdminTheme.textPrimary),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                visualDensity: VisualDensity.compact,
              ),
            ),
          // Breadcrumb / title
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hideBreadcrumbPrefix) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AdminTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 14,
                      color: AdminTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AdminTheme.borderColor,
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    sectionTitles[_currentSection],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Quick actions
          _buildTopBarAction(
            Icons.refresh_rounded,
            'Refresh',
            () {
              setState(() {});
              _loadNotifications();
            },
          ),
          _buildTopificationButton(),

          // Live indicator (hidden on phones to save space)
          if (!compact)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AdminTheme.successColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AdminTheme.successColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AdminTheme.successColor.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),

          // Time display — only on wide screens
          if (!hideLiveTime) _buildLiveTime(),
        ],
      ),
    );
  }

  Widget _buildTopBarAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AdminTheme.textSecondary),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: AdminTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildTopificationButton() {
    final hasUnread = _unreadCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: _openNotificationPanel,
            icon: Icon(
              hasUnread
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              size: 18,
              color: hasUnread
                  ? AdminTheme.accentColor
                  : AdminTheme.textSecondary,
            ),
            tooltip: hasUnread
                ? '$_unreadCount new notification${_unreadCount > 1 ? 's' : ''}'
                : 'Notifications',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: hasUnread
                  ? AdminTheme.accentColor.withOpacity(0.08)
                  : AdminTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: AdminTheme.dangerColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveTime() {
    return StreamBuilder<DateTime>(
      stream: _clockStream,
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AdminTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminTheme.borderColor),
          ),
          child: Text(
            DateFormat('MMM dd, yyyy • HH:mm:ss').format(now),
            style: const TextStyle(
              fontSize: 11,
              color: AdminTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return AdminDashboardSection(
          key: ValueKey(_refreshCounter),
          onNavigate: (i) => setState(() => _currentSection = i),
        );
      case 1:
        return AdminAccountsSection(
            key: ValueKey(_refreshCounter),
            isSuperAdmin: _isSuperAdmin);
      case 2:
        return AdminSubscriptionsSection(key: ValueKey(_refreshCounter));
      case 3:
        return AdminProfitsSection(key: ValueKey(_refreshCounter));
      case 4:
        return AdminAuditLogsSection(key: ValueKey(_refreshCounter));
      case 5:
        return AdminSupportSection(key: ValueKey(_refreshCounter), initialTabIndex: 0);
      default:
        return const Center(child: Text('Section not found'));
    }
  }

  void _showLogoutDialog() {
    showLogoutConfirmationDialog(context, role: 'admin');
  }

}

// ==================== NOTIFICATION PANEL ====================

class _NotificationPanel extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onRefresh;

  const _NotificationPanel({
    required this.notifications,
    required this.onRefresh,
  });

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: AdminTheme.accentGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.notifications.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.notifications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      widget.onRefresh();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: widget.notifications.isEmpty
                  ? const _EmptyNotif()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: widget.notifications.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, color: AdminTheme.borderColor),
                      itemBuilder: (context, i) =>
                          _NotifTile(item: widget.notifications[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotif extends StatelessWidget {
  const _EmptyNotif();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 48, color: AdminTheme.textSecondary),
          SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AdminTheme.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'New orders and support messages will appear here.',
            style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotifTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['_type'] as String? ?? '';
    final createdAt = item['created_at'] as String?;
    final time = createdAt != null
        ? _formatTime(DateTime.tryParse(createdAt))
        : '';

    String title;
    String subtitle;
    IconData icon;
    Color color;

    final userName = (item['accounts']?['full_name'] as String?)?.trim();
    final userEmail = item['accounts']?['email'] as String? ?? '';
    final displayUser =
        (userName?.isNotEmpty == true) ? userName! : userEmail;

    switch (type) {
      case 'subscription':
        final planDisplay = item['subscription_plans']?['display_name'] ??
            item['subscription_plans']?['name'] ??
            'a plan';
        title = 'New Subscription';
        subtitle = '${displayUser.isNotEmpty ? displayUser : 'A user'} subscribed to $planDisplay';
        icon = Icons.card_membership_rounded;
        color = AdminTheme.accentColor;
        break;
      case 'order':
        final total = (item['total'] as num?)?.toDouble() ?? 0;
        title = 'New Order';
        subtitle =
            '${displayUser.isNotEmpty ? displayUser : 'A user'} placed an order · ₱${total.toStringAsFixed(0)}';
        icon = Icons.shopping_bag_rounded;
        color = AdminTheme.successColor;
        break;
      case 'support':
        final subject = item['subject'] as String? ?? 'Support Request';
        title = 'Support Request';
        subtitle =
            '${displayUser.isNotEmpty ? displayUser : 'A user'} · $subject';
        icon = Icons.contact_support_rounded;
        color = AdminTheme.warningColor;
        break;
      default:
        title = 'Notification';
        subtitle = '';
        icon = Icons.info_outline_rounded;
        color = AdminTheme.textSecondary;
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AdminTheme.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 12, color: AdminTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: AdminTheme.textSecondary.withOpacity(0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
