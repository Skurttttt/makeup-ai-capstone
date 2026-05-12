// lib/screens/admin_screen_new.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../utils/export_helper.dart';
import '../utils/logout_util.dart';
import '../utils/responsive.dart';

// Format currency to Philippine Peso (PHP)
String formatPHP(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'fil_PH',
    symbol: '₱',
    decimalDigits: amount == amount.toInt() ? 0 : 2,
  );
  return formatter.format(amount);
}

// Admin theme constants
class AdminTheme {
  static const Color primaryColor = Color(0xFF1E293B);
  static const Color secondaryColor = Color(0xFF334155);
  static const Color accentColor = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );
  
  static const Gradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
  );
}

class AdminScreenNew extends StatefulWidget {
  const AdminScreenNew({super.key});

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

  // Layout helpers — sidebar inlines on tablet+, becomes a drawer on phones.
  bool get _showInlineSidebar =>
      MediaQuery.of(context).size.width >= Breakpoints.medium;
  bool get _isCompact => context.isCompact;
  double get _sectionPadding =>
      context.responsive(compact: 16, medium: 20, expanded: 24, large: 28);
  
  // Search and filter controllers
  final _accountSearchController = TextEditingController();
  final _subscriptionSearchController = TextEditingController();
  String _accountSearchQuery = '';
  String _subscriptionSearchQuery = '';
  String _subscriptionStatusFilter = 'all';
  String _accountRoleFilter = 'all';
  
  // Pagination
  int _accountsPage = 0;
  int _subscriptionsPage = 0;
  static const int _pageSize = 10;
  
  // Loading states
  bool _isExporting = false;
  
  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    _accountsChannel = _supabaseService.client
        .channel('accounts_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          callback: (payload) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();

    _subscriptionsChannel = _supabaseService.client
        .channel('subscriptions_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          callback: (payload) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();

    _auditLogsChannel = _supabaseService.client
        .channel('audit_logs_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'audit_logs',
          callback: (payload) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _accountSearchController.dispose();
    _subscriptionSearchController.dispose();
    _supabaseService.client.removeChannel(_accountsChannel);
    _supabaseService.client.removeChannel(_subscriptionsChannel);
    _supabaseService.client.removeChannel(_auditLogsChannel);
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
          // Branding
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Management Console',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
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
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin User',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'admin@example.com',
                        style: TextStyle(
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
                  icon: Icon(
                    Icons.logout_rounded,
                    color: AdminTheme.dangerColor.withOpacity(0.8),
                    size: 20,
                  ),
                  tooltip: 'Logout',
                  style: IconButton.styleFrom(
                    backgroundColor: AdminTheme.dangerColor.withOpacity(0.1),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item) {
    final isActive = _currentSection == item.index;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _currentSection = item.index);
            // If sidebar is rendered inside a Drawer, close it after tap.
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.hasDrawer && scaffold.isDrawerOpen) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? AdminTheme.accentColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: AdminTheme.accentColor.withOpacity(0.3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive
                      ? AdminTheme.accentColor
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AdminTheme.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AdminTheme.accentColor.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
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

  Widget _buildTopBar() {
    final sectionTitles = [
      'Dashboard Overview',
      'Account Management',
      'Subscription Management',
      'Revenue Analytics',
      'System Audit Logs',
    ];

    final compact = _isCompact;
    final hideBreadcrumbPrefix = compact;
    final hideLiveTime = MediaQuery.of(context).size.width < Breakpoints.expanded;
    final hideStatusPill = compact;

    return Container(
      height: compact ? 64 : 80,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 32),
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
            IconButton(
              tooltip: 'Open menu',
              icon: const Icon(Icons.menu_rounded, color: AdminTheme.textPrimary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          // Breadcrumb / title
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hideBreadcrumbPrefix) ...[
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 20,
                    color: AdminTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    sectionTitles[_currentSection],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: compact ? 16 : 18,
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
            () => setState(() {}),
          ),
          _buildTopBarAction(
            Icons.notifications_outlined,
            'Notifications',
            () {},
            showBadge: true,
          ),

          // Live indicator (hidden on phones to save space)
          if (!hideStatusPill)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AdminTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AdminTheme.successColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
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
                  const SizedBox(width: 6),
                  Text(
                    'System Online',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),

          // Time display \u2014 only on wide screens
          if (!hideLiveTime) _buildLiveTime(),
        ],
      ),
    );
  }

  Widget _buildTopBarAction(IconData icon, String tooltip, VoidCallback onTap, {bool showBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(icon, size: 20, color: AdminTheme.textSecondary),
            tooltip: tooltip,
            style: IconButton.styleFrom(
              backgroundColor: AdminTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AdminTheme.dangerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveTime() {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Text(
          DateFormat('MMM dd, yyyy • HH:mm:ss').format(now),
          style: const TextStyle(
            fontSize: 13,
            color: AdminTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        );
      },
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildAccountsSection();
      case 2:
        return _buildSubscriptionsSection();
      case 3:
        return _buildProfitsSection();
      case 4:
        return _buildAuditLogsSection();
      default:
        return const Center(child: Text('Section not found'));
    }
  }

  // ==================== DASHBOARD ====================
  
  Widget _buildDashboard() {
    return FutureBuilder(
      future: Future.wait([
        _supabaseService.getAllUsers(),
        _supabaseService.getAllSubscriptions(),
        _supabaseService.getAuditLogs(limit: 10),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AdminTheme.accentColor,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: _buildErrorState(snapshot.error.toString()),
          );
        }

        final users = snapshot.data?[0] as List<dynamic>? ?? [];
        final subscriptions = snapshot.data?[1] as List<dynamic>? ?? [];
        final recentLogs = snapshot.data?[2] as List<dynamic>? ?? [];

        // Calculate metrics
        final totalUsers = users.length;
        final activeSubscriptions = subscriptions.where((s) => s['status'] == 'active').length;
        final totalRevenue = subscriptions.fold<double>(
          0,
          (sum, s) => sum + ((s['amount_paid'] as num?)?.toDouble() ?? 0),
        );
        final pendingSubscriptions = subscriptions.where((s) => s['status'] == 'pending').length;
        final churnRate = totalUsers > 0 
            ? ((subscriptions.where((s) => s['status'] == 'expired').length / totalUsers) * 100).toStringAsFixed(1)
            : '0.0';

        return SingleChildScrollView(
          padding: EdgeInsets.all(_sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome banner
              Container(
                padding: EdgeInsets.all(_isCompact ? 18 : 24),
                decoration: BoxDecoration(
                  gradient: AdminTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: _isCompact ? 22 : 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Monitor and manage your application in real-time',
                            style: TextStyle(
                              fontSize: _isCompact ? 12 : 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isCompact)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.analytics_rounded,
                          size: 48,
                          color: AdminTheme.accentColor,
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // KPI Cards — grid that adapts to width.
              _adaptiveCardGrid(
                minWidth: 220,
                children: [
                  _buildKpiCard('Total Users', '$totalUsers', Icons.people_rounded, AdminTheme.accentColor, '+12%'),
                  _buildKpiCard('Active Plans', '$activeSubscriptions', Icons.verified_rounded, AdminTheme.successColor, '+8%'),
                  _buildKpiCard('Revenue', formatPHP(totalRevenue), Icons.payments_rounded, AdminTheme.warningColor, '+15%'),
                  _buildKpiCard('Churn Rate', '$churnRate%', Icons.trending_down_rounded, AdminTheme.dangerColor, '-2.1%'),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Charts and recent activity — stack on narrow screens.
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 900;
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRevenueChart(subscriptions),
                        const SizedBox(height: 16),
                        _buildRecentActivity(recentLogs),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildRevenueChart(subscriptions),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: _buildRecentActivity(recentLogs),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trend.startsWith('+') 
                      ? AdminTheme.successColor.withOpacity(0.1)
                      : AdminTheme.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trend.startsWith('+') 
                        ? AdminTheme.successColor
                        : AdminTheme.dangerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AdminTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(List<dynamic> subscriptions) {
    final monthlyData = _calculateMonthlyProfits(subscriptions);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Last 12 Months',
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminTheme.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: monthlyData.isEmpty
                ? const Center(child: Text('No data available'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 500,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AdminTheme.borderColor,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) => Text(
                              '₱${value.toInt()}',
                              style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < monthlyData.length) {
                                return Text(
                                  monthlyData[value.toInt()]['month'],
                                  style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: monthlyData.asMap().entries.map((e) => 
                            FlSpot(e.key.toDouble(), (e.value['amount'] as num).toDouble())
                          ).toList(),
                          isCurved: true,
                          color: AdminTheme.accentColor,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: AdminTheme.accentColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AdminTheme.accentColor.withOpacity(0.3),
                                AdminTheme.accentColor.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<dynamic> logs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('No recent activity'))
                : ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final action = log['action']?.toString() ?? 'Unknown';
                      final target = log['target']?.toString() ?? 'N/A';
                      final timestamp = DateTime.tryParse(log['created_at']?.toString() ?? '') ?? DateTime.now();
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _getActionColor(action).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getActionIcon(action),
                                size: 16,
                                color: _getActionColor(action),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AdminTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    target,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AdminTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== ACCOUNTS SECTION ====================
  
  Widget _buildAccountsSection() {
    return FutureBuilder(
      future: Future.wait([
        _supabaseService.getAllUsers(),
        _supabaseService.getAllSubscriptions(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: _buildErrorState(snapshot.error.toString()));
        }

        final users = (snapshot.data?[0] as List<dynamic>?) ?? [];
        final subscriptions = (snapshot.data?[1] as List<dynamic>?) ?? [];
        
        // Create subscription map
        final Map<String, Map<String, dynamic>> userSubMap = {};
        for (var sub in subscriptions) {
          final userId = sub['user_id']?.toString();
          if (userId != null && !userSubMap.containsKey(userId)) {
            userSubMap[userId] = sub;
          }
        }

        // Filter and search
        var filteredUsers = users.where((user) {
          final matchesSearch = _accountSearchQuery.isEmpty ||
              (user['full_name']?.toString().toLowerCase().contains(_accountSearchQuery.toLowerCase()) ?? false) ||
              (user['email']?.toString().toLowerCase().contains(_accountSearchQuery.toLowerCase()) ?? false);
          
          final matchesRole = _accountRoleFilter == 'all' || 
              user['role']?.toString() == _accountRoleFilter;
          
          return matchesSearch && matchesRole;
        }).toList();

        // Pagination
        final totalPages = (filteredUsers.length / _pageSize).ceil();
        final paginatedUsers = filteredUsers.skip(_accountsPage * _pageSize).take(_pageSize).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.all(_sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    'Account Management',
                    style: TextStyle(
                      fontSize: _isCompact ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAccountDialog(),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Summary cards
              _adaptiveCardGrid(
                minWidth: 200,
                children: [
                  _buildSummaryCard(
                    'Total Users',
                    '${users.length}',
                    Icons.people_rounded,
                    AdminTheme.accentColor,
                  ),
                  _buildSummaryCard(
                    'Active Subscribers',
                    '${userSubMap.length}',
                    Icons.verified_rounded,
                    AdminTheme.successColor,
                  ),
                  _buildSummaryCard(
                    'Admins',
                    '${users.where((u) => u['role'] == 'admin').length}',
                    Icons.shield_rounded,
                    AdminTheme.warningColor,
                  ),
                  _buildSummaryCard(
                    'Regular Users',
                    '${users.where((u) => u['role'] == 'user').length}',
                    Icons.person_rounded,
                    AdminTheme.textSecondary,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Filters
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 600;
                  final searchField = TextField(
                    controller: _accountSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _accountSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _accountSearchController.clear();
                                setState(() => _accountSearchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AdminTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AdminTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AdminTheme.accentColor, width: 2),
                      ),
                      filled: true,
                      fillColor: AdminTheme.cardColor,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _accountSearchQuery = value;
                        _accountsPage = 0;
                      });
                    },
                  );
                  final roleDropdown = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AdminTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _accountRoleFilter,
                        isExpanded: stack,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Roles')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'user', child: Text('User')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _accountRoleFilter = value ?? 'all';
                            _accountsPage = 0;
                          });
                        },
                      ),
                    ),
                  );
                  final exportButton = IconButton(
                    onPressed: () => _exportAccounts(filteredUsers),
                    icon: Icon(Icons.download_rounded, color: AdminTheme.accentColor),
                    tooltip: 'Export CSV',
                    style: IconButton.styleFrom(
                      backgroundColor: AdminTheme.accentColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );

                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: roleDropdown),
                            const SizedBox(width: 12),
                            exportButton,
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: searchField),
                      const SizedBox(width: 16),
                      roleDropdown,
                      const SizedBox(width: 16),
                      exportButton,
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Users table
              Container(
                decoration: BoxDecoration(
                  color: AdminTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AdminTheme.backgroundColor),
                        headingRowHeight: 56,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 72,
                        dividerThickness: 1,
                        columns: const [
                          DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Subscription', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Joined', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        rows: paginatedUsers.map((user) {
                          final userSub = userSubMap[user['id']?.toString()];
                          final planName = userSub?['subscription_plans']?['name']?.toString() ?? 'Free';
                          final status = userSub?['status']?.toString() ?? 'inactive';
                          
                          return DataRow(cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AdminTheme.accentColor.withOpacity(0.1),
                                    child: Text(
                                      (user['full_name']?.toString() ?? 'U')[0].toUpperCase(),
                                      style: TextStyle(
                                        color: AdminTheme.accentColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    user['full_name']?.toString() ?? 'N/A',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(user['email']?.toString() ?? 'N/A')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: user['role'] == 'admin'
                                      ? AdminTheme.warningColor.withOpacity(0.1)
                                      : AdminTheme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user['role']?.toString() ?? 'user',
                                  style: TextStyle(
                                    color: user['role'] == 'admin'
                                        ? AdminTheme.warningColor
                                        : AdminTheme.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(planName)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? AdminTheme.successColor.withOpacity(0.1)
                                      : AdminTheme.textSecondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'active' ? AdminTheme.successColor : AdminTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                DateFormat('MMM dd, yyyy').format(
                                  DateTime.tryParse(user['created_at']?.toString() ?? '') ?? DateTime.now(),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTableActionButton(
                                    Icons.edit_rounded,
                                    'Edit',
                                    AdminTheme.accentColor,
                                    () => _showEditAccountDialog(user),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTableActionButton(
                                    Icons.delete_rounded,
                                    'Delete',
                                    AdminTheme.dangerColor,
                                    () => _showDeleteAccountDialog(user),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                    
                    // Pagination
                    if (totalPages > 1)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AdminTheme.borderColor)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _accountsPage > 0
                                  ? () => setState(() => _accountsPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              'Page ${_accountsPage + 1} of $totalPages',
                              style: const TextStyle(color: AdminTheme.textSecondary),
                            ),
                            IconButton(
                              onPressed: _accountsPage < totalPages - 1
                                  ? () => setState(() => _accountsPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SUBSCRIPTIONS SECTION ====================
  
  Widget _buildSubscriptionsSection() {
    return FutureBuilder(
      future: Future.wait([
        _supabaseService.getAllSubscriptions(),
        _supabaseService.getAllPlans(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: _buildErrorState(snapshot.error.toString()));
        }

        final subscriptions = (snapshot.data?[0] as List<dynamic>?) ?? [];
        final plans = (snapshot.data?[1] as List<dynamic>?) ?? [];

        // Filter subscriptions
        var filteredSubs = subscriptions.where((sub) {
          final matchesSearch = _subscriptionSearchQuery.isEmpty ||
              (sub['accounts']?['full_name']?.toString().toLowerCase().contains(_subscriptionSearchQuery.toLowerCase()) ?? false) ||
              (sub['subscription_plans']?['name']?.toString().toLowerCase().contains(_subscriptionSearchQuery.toLowerCase()) ?? false);
          
          final matchesStatus = _subscriptionStatusFilter == 'all' ||
              sub['status']?.toString() == _subscriptionStatusFilter;
          
          return matchesSearch && matchesStatus;
        }).toList();

        final totalPages = (filteredSubs.length / _pageSize).ceil();
        final paginatedSubs = filteredSubs.skip(_subscriptionsPage * _pageSize).take(_pageSize).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.all(_sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    'Subscription Management',
                    style: TextStyle(
                      fontSize: _isCompact ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAssignSubscriptionDialog(),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Assign Subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddPlanDialog(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Summary cards
              _adaptiveCardGrid(
                minWidth: 200,
                children: [
                  _buildSummaryCard(
                    'Total Subscriptions',
                    '${subscriptions.length}',
                    Icons.subscriptions_rounded,
                    AdminTheme.accentColor,
                  ),
                  _buildSummaryCard(
                    'Active',
                    '${subscriptions.where((s) => s['status'] == 'active').length}',
                    Icons.check_circle_rounded,
                    AdminTheme.successColor,
                  ),
                  _buildSummaryCard(
                    'Pending',
                    '${subscriptions.where((s) => s['status'] == 'pending').length}',
                    Icons.pending_rounded,
                    AdminTheme.warningColor,
                  ),
                  _buildSummaryCard(
                    'Expired',
                    '${subscriptions.where((s) => s['status'] == 'expired').length}',
                    Icons.cancel_rounded,
                    AdminTheme.dangerColor,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Plans management
              const Text(
                'Subscription Plans',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: AdminTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AdminTheme.backgroundColor),
                    headingRowHeight: 56,
                    dataRowMinHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Plan Name', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Billing Period', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: plans.map((plan) {
                      return DataRow(cells: [
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AdminTheme.accentGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                plan['name']?.toString() ?? 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            formatPHP((plan['price'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(plan['billing_period']?.toString() ?? 'N/A')),
                        DataCell(
                          Text(
                            plan['description']?.toString() ?? '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTableActionButton(
                                Icons.edit_rounded,
                                'Edit',
                                AdminTheme.accentColor,
                                () => _showEditPlanDialog(plan),
                              ),
                              const SizedBox(width: 8),
                              _buildTableActionButton(
                                Icons.delete_rounded,
                                'Delete',
                                AdminTheme.dangerColor,
                                () => _showDeletePlanDialog(plan['id']?.toString() ?? '', plan['name']?.toString() ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Active subscriptions
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    'Active Subscriptions',
                    style: TextStyle(
                      fontSize: _isCompact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _isCompact ? double.infinity : 420),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: _isCompact ? double.infinity : 250,
                          child: TextField(
                            controller: _subscriptionSearchController,
                            decoration: InputDecoration(
                              hintText: 'Search subscriptions...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AdminTheme.borderColor),
                              ),
                              filled: true,
                              fillColor: AdminTheme.cardColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _subscriptionSearchQuery = value;
                                _subscriptionsPage = 0;
                              });
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AdminTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminTheme.borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _subscriptionStatusFilter,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Status')),
                                DropdownMenuItem(value: 'active', child: Text('Active')),
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'expired', child: Text('Expired')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _subscriptionStatusFilter = value ?? 'all';
                                  _subscriptionsPage = 0;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: AdminTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AdminTheme.backgroundColor),
                        headingRowHeight: 56,
                        dataRowMinHeight: 56,
                        columns: const [
                          DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('End Date', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        rows: paginatedSubs.map((sub) {
                          final userName = sub['accounts']?['full_name']?.toString() ?? 'N/A';
                          final planName = sub['subscription_plans']?['name']?.toString() ?? 'N/A';
                          final status = sub['status']?.toString() ?? 'N/A';
                          final amount = sub['amount_paid'] ?? sub['price'] ?? 0;
                          final startDate = sub['current_period_start']?.toString();
                          final endDate = sub['current_period_end']?.toString();
                          
                          return DataRow(cells: [
                            DataCell(Text(userName, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(planName)),
                            DataCell(Text(formatPHP((amount as num?)?.toDouble() ?? 0))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(startDate != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(startDate)) : 'N/A')),
                            DataCell(Text(endDate != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(endDate)) : 'N/A')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTableActionButton(
                                    Icons.edit_rounded,
                                    'Edit',
                                    AdminTheme.accentColor,
                                    () => _showEditSubscriptionDialog(sub),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTableActionButton(
                                    Icons.delete_rounded,
                                    'Delete',
                                    AdminTheme.dangerColor,
                                    () => _showDeleteSubscriptionDialog(
                                      sub['id']?.toString() ?? '',
                                      userName,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                    
                    if (totalPages > 1)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AdminTheme.borderColor)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _subscriptionsPage > 0
                                  ? () => setState(() => _subscriptionsPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              'Page ${_subscriptionsPage + 1} of $totalPages',
                              style: const TextStyle(color: AdminTheme.textSecondary),
                            ),
                            IconButton(
                              onPressed: _subscriptionsPage < totalPages - 1
                                  ? () => setState(() => _subscriptionsPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== PROFITS SECTION ====================
  
  Widget _buildProfitsSection() {
    // Reuse profit section from original code but with admin theme
    return FutureBuilder(
      future: _supabaseService.getAllSubscriptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: _buildErrorState(snapshot.error.toString()));
        }

        final subscriptions = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(_sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue Analytics',
                style: TextStyle(
                  fontSize: _isCompact ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // Profit content here (similar to original _buildProfitsSection)
            ],
          ),
        );
      },
    );
  }

  // ==================== AUDIT LOGS SECTION ====================
  
  Widget _buildAuditLogsSection() {
    return FutureBuilder(
      future: _supabaseService.getAuditLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: _buildErrorState(snapshot.error.toString()));
        }

        final logs = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.all(_sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    'System Audit Logs',
                    style: TextStyle(
                      fontSize: _isCompact ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _exportAuditLogs(logs),
                        icon: Icon(
                          _isExporting ? Icons.hourglass_top_rounded : Icons.download_rounded,
                          size: 18,
                        ),
                        label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: AdminTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AdminTheme.backgroundColor),
                    columns: const [
                      DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Target', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: logs.map((log) {
                      return DataRow(cells: [
                        DataCell(
                          Text(
                            DateFormat('MMM dd, yyyy HH:mm:ss').format(
                              DateTime.tryParse(log['created_at']?.toString() ?? '') ?? DateTime.now(),
                            ),
                          ),
                        ),
                        DataCell(Text(log['accounts']?['email']?.toString() ?? 'System')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getActionColor(log['action']?.toString() ?? '').withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log['action']?.toString() ?? 'N/A',
                              style: TextStyle(
                                color: _getActionColor(log['action']?.toString() ?? ''),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(log['target']?.toString() ?? 'N/A')),
                        DataCell(Text(log['metadata']?.toString() ?? '-')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== HELPER WIDGETS ====================

  /// Renders a row of equal-width cards that automatically wraps to multiple
  /// rows on narrower screens. Used by KPI rows, summary cards, etc.
  Widget _adaptiveCardGrid({
    required List<Widget> children,
    double minWidth = 220,
    double spacing = 16,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final maxColumns = children.length;
        var columns = (available / minWidth).floor();
        if (columns < 1) columns = 1;
        if (columns > maxColumns) columns = maxColumns;
        final itemWidth =
            (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.dangerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.dangerColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AdminTheme.dangerColor),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AdminTheme.dangerColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AdminTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOG METHODS ====================
  
  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'user';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => role = value ?? 'user',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields'), backgroundColor: AdminTheme.dangerColor),
                );
                return;
              }
              
              try {
                await _supabaseService.client.auth.admin.createUser(
                  AdminUserAttributes(
                    email: emailController.text,
                    password: passwordController.text,
                    emailConfirm: true,
                    userMetadata: {'full_name': nameController.text, 'role': role},
                  ),
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account created successfully'), backgroundColor: AdminTheme.successColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AdminTheme.dangerColor),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Map<String, dynamic> account) {
    final nameController = TextEditingController(text: account['full_name']?.toString() ?? '');
    String role = account['role']?.toString() ?? 'user';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Email: ${account['email']}',
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => setDialogState(() => role = value ?? 'user'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _supabaseService.updateUserProfile(
                    userId: account['id']?.toString() ?? '',
                    updates: {'full_name': nameController.text, 'role': role},
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account updated successfully'), backgroundColor: AdminTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AdminTheme.dangerColor),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to delete ${account['full_name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.client.auth.admin.deleteUser(
                  account['id']?.toString() ?? '',
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully'), backgroundColor: AdminTheme.successColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AdminTheme.dangerColor),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddPlanDialog() {
    // Implementation similar to original
  }

  void _showEditPlanDialog(Map<String, dynamic> plan) {
    // Implementation similar to original
  }

  void _showDeletePlanDialog(String planId, String planName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete "$planName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.deletePlan(planId);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan deleted'), backgroundColor: AdminTheme.successColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AdminTheme.dangerColor),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.dangerColor, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAssignSubscriptionDialog() {
    // Implementation similar to original with admin theme
  }

  void _showEditSubscriptionDialog(Map<String, dynamic> subscription) {
    // Implementation for editing subscriptions
  }

  void _showDeleteSubscriptionDialog(String subscriptionId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text('Are you sure you want to delete subscription for $userName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.deleteSubscription(subscriptionId);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subscription deleted'), backgroundColor: AdminTheme.successColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AdminTheme.dangerColor),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.dangerColor, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportAccounts(List<dynamic> accounts) async {
    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('Name,Email,Role,Created');
      for (var account in accounts) {
        buffer.writeln(
          '${account['full_name']},${account['email']},${account['role']},${account['created_at']}',
        );
      }
      saveCsvFile('accounts_export.csv', buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accounts exported successfully'), backgroundColor: AdminTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AdminTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _exportAuditLogs(List<dynamic> logs) async {
    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('Timestamp,User,Action,Target,Metadata');
      for (var log in logs) {
        buffer.writeln(
          '${log['created_at']},${log['accounts']?['email'] ?? 'System'},${log['action']},${log['target']},${log['metadata']}',
        );
      }
      saveCsvFile('audit_logs_export.csv', buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audit logs exported successfully'), backgroundColor: AdminTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AdminTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // ==================== UTILITY METHODS ====================
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AdminTheme.successColor;
      case 'pending':
        return AdminTheme.warningColor;
      case 'expired':
      case 'cancelled':
        return AdminTheme.dangerColor;
      default:
        return AdminTheme.textSecondary;
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('create') || action.contains('add')) return AdminTheme.successColor;
    if (action.contains('delete') || action.contains('remove')) return AdminTheme.dangerColor;
    if (action.contains('update') || action.contains('edit')) return AdminTheme.accentColor;
    return AdminTheme.warningColor;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('create') || action.contains('add')) return Icons.add_circle_rounded;
    if (action.contains('delete') || action.contains('remove')) return Icons.delete_rounded;
    if (action.contains('update') || action.contains('edit')) return Icons.edit_rounded;
    return Icons.info_rounded;
  }

  List<Map<String, dynamic>> _calculateMonthlyProfits(List<dynamic> subscriptions) {
    // Implementation from original code
    final Map<String, double> monthlyData = {};
    final now = DateTime.now();
    
    // Initialize last 12 months
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM').format(month);
      monthlyData[key] = 0.0;
    }
    
    // Calculate revenue
    for (var sub in subscriptions) {
      final date = DateTime.tryParse(sub['created_at']?.toString() ?? '') ?? DateTime.now();
      final key = DateFormat('MMM').format(date);
      if (monthlyData.containsKey(key)) {
        final amount = (sub['amount_paid'] as num?)?.toDouble() ?? 0;
        monthlyData[key] = (monthlyData[key] ?? 0) + amount;
      }
    }
    
    return monthlyData.entries.map((e) => {'month': e.key, 'amount': e.value}).toList();
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  NavigationItem(this.icon, this.label, this.index);
}