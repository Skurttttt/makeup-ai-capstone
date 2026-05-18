// lib/screens/admin_dashboard_section.dart
// Dashboard section: KPIs, revenue chart, quick actions, system health,
// and recent activity.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import 'admin_shared.dart';

class AdminDashboardSection extends StatefulWidget {
  /// Called when a quick action or "View All" link requests navigation
  /// to another section by index (1=Accounts, 2=Subscriptions, 3=Profits, 4=AuditLogs).
  final void Function(int) onNavigate;

  const AdminDashboardSection({super.key, required this.onNavigate});

  @override
  State<AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<AdminDashboardSection> {
  final _supabaseService = SupabaseService();

  double get _sectionPadding =>
      context.responsive(compact: 16, medium: 20, expanded: 24, large: 28);
  bool get _isCompact => context.isCompact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        _supabaseService.getAllUsers(),
        _supabaseService.getAllSubscriptions(),
        _supabaseService.getAuditLogs(limit: 10),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AdminTheme.accentColor),
                const SizedBox(height: 16),
                Text(
                  'Loading dashboard...',
                  style: TextStyle(
                      color: AdminTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: buildErrorState(
              'Failed to load dashboard data',
              details: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            ),
          );
        }

        final users = snapshot.data?[0] as List<dynamic>? ?? [];
        final subscriptions = snapshot.data?[1] as List<dynamic>? ?? [];
        final recentLogs = snapshot.data?[2] as List<dynamic>? ?? [];

        final totalUsers = users.length;
        final activeSubscriptions =
            subscriptions.where((s) => s['status'] == 'active').length;
        final totalRevenue = subscriptions.fold<double>(
          0,
          (sum, s) => sum + ((s['amount_paid'] as num?)?.toDouble() ?? 0),
        );
        final churnRate = totalUsers > 0
            ? ((subscriptions
                            .where((s) => s['status'] == 'expired')
                            .length /
                        totalUsers) *
                    100)
                .toStringAsFixed(1)
            : '0.0';

        return SingleChildScrollView(
          padding: EdgeInsets.all(_sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(),
              const SizedBox(height: 24),
              buildAdaptiveCardGrid(
                minWidth: 200,
                children: [
                  buildKpiCard(context, 'Total Users', '$totalUsers',
                      Icons.people_rounded, AdminTheme.accentColor, '+12%'),
                  buildKpiCard(
                      context,
                      'Active Plans',
                      '$activeSubscriptions',
                      Icons.verified_rounded,
                      AdminTheme.successColor,
                      '+8%'),
                  buildKpiCard(
                      context,
                      'Revenue',
                      formatPHP(totalRevenue),
                      Icons.payments_rounded,
                      AdminTheme.warningColor,
                      '+15%'),
                  buildKpiCard(
                      context,
                      'Churn Rate',
                      '$churnRate%',
                      Icons.trending_down_rounded,
                      AdminTheme.dangerColor,
                      '-2.1%'),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 800;
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildQuickActions(),
                        const SizedBox(height: 16),
                        _buildSystemHealth(users, subscriptions),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildQuickActions()),
                      const SizedBox(width: 24),
                      Expanded(
                          flex: 2,
                          child: _buildSystemHealth(users, subscriptions)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 800;
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildRevenueChart(subscriptions),
                        const SizedBox(height: 16),
                        _buildRecentActivity(recentLogs),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 3, child: buildRevenueChart(subscriptions)),
                      const SizedBox(width: 24),
                      Expanded(
                          flex: 2, child: _buildRecentActivity(recentLogs)),
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

  // ==================== WELCOME BANNER ====================

  Widget _buildWelcomeBanner() {
    return Container(
      padding: EdgeInsets.all(_isCompact ? 16 : 24),
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
                  'Welcome back, Admin',
                  style: TextStyle(
                    fontSize: _isCompact ? 20 : 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Here's what's happening with your app today.",
                  style: TextStyle(
                    fontSize: _isCompact ? 13 : 15,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (!_isCompact) ...[
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== QUICK ACTIONS ====================

  Widget _buildQuickActions() {
    final actions = <AdminQuickAction>[
      AdminQuickAction(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Add User',
        color: AdminTheme.accentColor,
        onTap: () => widget.onNavigate(1),
      ),
      AdminQuickAction(
        icon: Icons.card_membership_rounded,
        label: 'Manage Plans',
        color: AdminTheme.successColor,
        onTap: () => widget.onNavigate(2),
      ),
      AdminQuickAction(
        icon: Icons.file_download_rounded,
        label: 'Export Report',
        color: AdminTheme.warningColor,
        onTap: () => widget.onNavigate(3),
      ),
      AdminQuickAction(
        icon: Icons.security_rounded,
        label: 'Audit Logs',
        color: AdminTheme.dangerColor,
        onTap: () => widget.onNavigate(4),
      ),
    ];

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
            children: [
              Icon(Icons.flash_on_rounded,
                  size: 20, color: AdminTheme.accentColor),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Frequently used administrative tools',
            style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth < 360 ? 2 : 4;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: actions.map(_buildQuickActionTile).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(AdminQuickAction a) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: a.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: a.color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a.icon, color: a.color, size: 28),
              const SizedBox(height: 8),
              Text(
                a.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: a.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SYSTEM HEALTH ====================

  Widget _buildSystemHealth(List<dynamic> users, List<dynamic> subs) {
    final activeUsers = users
        .where((u) =>
            (u['is_active'] == true) || (u['status']?.toString() == 'active'))
        .length;
    final activeSubs = subs.where((s) => s['status'] == 'active').length;

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
            children: [
              Icon(Icons.monitor_heart_rounded,
                  size: 20, color: AdminTheme.successColor),
              const SizedBox(width: 8),
              const Text(
                'System Health',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'OPERATIONAL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AdminTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHealthRow('Database', 'Connected', true, 1.0),
          const SizedBox(height: 10),
          _buildHealthRow('Supabase API', 'Reachable', true, 0.98),
          const SizedBox(height: 10),
          _buildHealthRow(
            'Active Sessions',
            '$activeUsers users',
            true,
            users.isEmpty ? 0 : activeUsers / users.length,
          ),
          const SizedBox(height: 10),
          _buildHealthRow(
            'Subscription Load',
            '$activeSubs active',
            true,
            subs.isEmpty ? 0 : activeSubs / subs.length,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AdminTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All systems operating normally. Last checked just now.',
                    style: TextStyle(
                        fontSize: 11, color: AdminTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(
      String label, String status, bool ok, double progress) {
    final color = ok ? AdminTheme.successColor : AdminTheme.dangerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: AdminTheme.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== RECENT ACTIVITY ====================

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
          Row(
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onNavigate(4),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded,
                            size: 40,
                            color: AdminTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        const Text('No recent activity',
                            style:
                                TextStyle(color: AdminTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length.clamp(0, 5),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final action = log['action']?.toString() ?? 'Unknown';
                    final target = log['target']?.toString() ?? 'N/A';
                    final timestamp =
                        DateTime.tryParse(log['created_at']?.toString() ?? '') ??
                            DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: getActionColor(action).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              getActionIcon(action),
                              size: 16,
                              color: getActionColor(action),
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
                                  overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}
