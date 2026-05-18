// lib/screens/admin_profits_section.dart
// Revenue Analytics section: KPI cards, revenue chart, and
// per-plan revenue breakdown table.

import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import 'admin_shared.dart';

class AdminProfitsSection extends StatefulWidget {
  const AdminProfitsSection({super.key});

  @override
  State<AdminProfitsSection> createState() => _AdminProfitsSectionState();
}

class _AdminProfitsSectionState extends State<AdminProfitsSection> {
  final _supabaseService = SupabaseService();

  List<dynamic> _subscriptions = [];
  bool _loading = true;
  String? _error;

  double get _sectionPadding =>
      context.responsive(compact: 16, medium: 20, expanded: 24, large: 28);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final subs = await _supabaseService.getAllSubscriptions();
      if (!mounted) return;
      setState(() { _subscriptions = subs; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminTheme.accentColor));
    }

    if (_error != null) {
      return Center(
        child: buildErrorState('Failed to load revenue data',
            details: _error, onRetry: _loadData),
      );
    }

    final subscriptions = _subscriptions;
    final totalRevenue = subscriptions.fold<double>(
        0, (sum, s) => sum + ((s['amount_paid'] as num?)?.toDouble() ?? 0));
    final activeCount =
        subscriptions.where((s) => s['status'] == 'active').length;
    final expiredCount =
        subscriptions.where((s) => s['status'] == 'expired').length;
    final avgRevenue =
        activeCount > 0 ? (totalRevenue / subscriptions.length) : 0.0;

    // monthly revenue (current month)
    final now = DateTime.now();
    final monthlyRevenue = subscriptions
        .where((s) {
          final dt =
              DateTime.tryParse(s['created_at']?.toString() ?? '');
          return dt != null &&
              dt.year == now.year &&
              dt.month == now.month;
        })
        .fold<double>(
            0,
            (sum, s) =>
                sum + ((s['amount_paid'] as num?)?.toDouble() ?? 0));

    return SingleChildScrollView(
      padding: EdgeInsets.all(_sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          buildSectionHeader(
            context,
            'Revenue Analytics',
            actions: [
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: primaryButtonStyle(AdminTheme.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── KPI Cards ──
          buildAdaptiveCardGrid(
            minWidth: 200,
            children: [
              buildKpiCard(
                  context,
                  'Total Revenue',
                  formatPHP(totalRevenue),
                  Icons.payments_rounded,
                  AdminTheme.accentColor,
                  ''),
              buildKpiCard(
                  context,
                  'This Month',
                  formatPHP(monthlyRevenue),
                  Icons.calendar_month_rounded,
                  AdminTheme.successColor,
                  ''),
              buildKpiCard(
                  context,
                  'Active Subscribers',
                  '$activeCount',
                  Icons.verified_rounded,
                  AdminTheme.warningColor,
                  ''),
              buildKpiCard(
                  context,
                  'Avg. per Sub',
                  formatPHP(avgRevenue),
                  Icons.trending_up_rounded,
                  AdminTheme.dangerColor,
                  ''),
            ],
          ),
          const SizedBox(height: 28),

          // ── Chart ──
          buildRevenueChart(subscriptions),
          const SizedBox(height: 28),

          // ── Revenue by Plan ──
          buildSectionHeader(context, 'Revenue by Plan',
              isSubsection: true),
          const SizedBox(height: 16),
          _buildPlanBreakdown(subscriptions),
          const SizedBox(height: 28),

          // ── Status Breakdown ──
          buildSectionHeader(context, 'Subscription Status Breakdown',
              isSubsection: true),
          const SizedBox(height: 16),
          _buildStatusBreakdown(subscriptions),
        ],
      ),
    );
  }

  Widget _buildPlanBreakdown(List<dynamic> subscriptions) {
    final Map<String, double> planRevenue = {};
    final Map<String, int> planCount = {};
    final Map<String, int> activePlanCount = {};

    for (var sub in subscriptions) {
      final planName =
          sub['subscription_plans']?['display_name']?.toString() ??
              sub['subscription_plans']?['name']?.toString() ??
              'Unknown';
      final amount = (sub['amount_paid'] as num?)?.toDouble() ?? 0;
      planRevenue[planName] = (planRevenue[planName] ?? 0) + amount;
      planCount[planName] = (planCount[planName] ?? 0) + 1;
      if (sub['status']?.toString() == 'active') {
        activePlanCount[planName] =
            (activePlanCount[planName] ?? 0) + 1;
      }
    }

    final plans = planRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final grandTotal =
        plans.fold<double>(0, (sum, p) => sum + p.value);

    if (plans.isEmpty) {
      return _buildEmptyCard('No revenue data yet', Icons.bar_chart_rounded);
    }

    final planColors = [
      AdminTheme.accentColor,
      AdminTheme.successColor,
      AdminTheme.warningColor,
      AdminTheme.dangerColor,
    ];

    return Column(
      children: plans.asMap().entries.map((entry) {
        final idx = entry.key;
        final plan = entry.value;
        final share =
            grandTotal > 0 ? (plan.value / grandTotal * 100) : 0.0;
        final color = planColors[idx % planColors.length];
        final totalSubs = planCount[plan.key] ?? 0;
        final activeSubs = activePlanCount[plan.key] ?? 0;
        final isPremium = plan.key.toLowerCase().contains('premium') ||
            plan.key.toLowerCase().contains('lifetime');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AdminTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Plan icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPremium
                          ? Icons.star_rounded
                          : Icons.card_membership_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AdminTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                            '$totalSubs subscriber${totalSubs != 1 ? 's' : ''}'
                            ' · $activeSubs active',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AdminTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatPHP(plan.value),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: color)),
                      Text('${share.toStringAsFixed(1)}% of total',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AdminTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: share / 100,
                  minHeight: 7,
                  backgroundColor: AdminTheme.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBreakdown(List<dynamic> subscriptions) {
    final Map<String, int> statusCount = {};
    for (var sub in subscriptions) {
      final status = sub['status']?.toString() ?? 'unknown';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    final statusColors = {
      'active': AdminTheme.successColor,
      'trial': AdminTheme.accentColor,
      'paused': AdminTheme.warningColor,
      'past_due': AdminTheme.dangerColor,
      'expired': AdminTheme.textSecondary,
      'canceled': AdminTheme.dangerColor.withOpacity(0.7),
    };

    final statusIcons = {
      'active': Icons.check_circle_rounded,
      'trial': Icons.hourglass_top_rounded,
      'paused': Icons.pause_circle_rounded,
      'past_due': Icons.warning_rounded,
      'expired': Icons.cancel_rounded,
      'canceled': Icons.block_rounded,
    };

    if (statusCount.isEmpty) {
      return _buildEmptyCard(
          'No subscription data yet', Icons.pie_chart_rounded);
    }

    return buildAdaptiveCardGrid(
      minWidth: 160,
      children: statusCount.entries.map((entry) {
        final color = statusColors[entry.key] ?? AdminTheme.textSecondary;
        final icon = statusIcons[entry.key] ?? Icons.circle;
        return buildSummaryCard(
          entry.key
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1)}'
                  : '')
              .join(' '),
          '${entry.value}',
          icon,
          color,
        );
      }).toList(),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AdminTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    fontSize: 14, color: AdminTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
