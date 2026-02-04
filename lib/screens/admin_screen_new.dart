// lib/screens/admin_screen_new.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../utils/export_helper.dart';

class AdminScreenNew extends StatefulWidget {
  const AdminScreenNew({super.key});

  @override
  State<AdminScreenNew> createState() => _AdminScreenNewState();
}

class _AdminScreenNewState extends State<AdminScreenNew> {
  final _supabaseService = SupabaseService();
  int _currentSection = 0; // 0: Dashboard, 1: Accounts, 2: Subscriptions, 3: Profits, 4: Audit Logs
  late RealtimeChannel _accountsChannel;
  late RealtimeChannel _subscriptionsChannel;
  late RealtimeChannel _auditLogsChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    _accountsChannel = _supabaseService.client
        .channel('accounts_all')
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
        .channel('user_subscriptions_all')
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
        .channel('audit_logs_all')
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
    _supabaseService.client.removeChannel(_accountsChannel);
    _supabaseService.client.removeChannel(_subscriptionsChannel);
    _supabaseService.client.removeChannel(_auditLogsChannel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebAdmin();
    }
    return _buildMobileAdmin();
  }

  Widget _buildWebAdmin() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Row(
          children: [
            _buildWebSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildWebTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildCurrentSection(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSidebar() {
    const items = [
      ('Dashboard', Icons.dashboard_outlined),
      ('Accounts', Icons.people_outline),
      ('Subscriptions', Icons.card_membership_outlined),
      ('Profit', Icons.attach_money_outlined),
      ('Audit Logs', Icons.receipt_long_outlined),
    ];

    return Container(
      width: 240,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FaceTune Beauty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Admin Console',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ...List.generate(items.length, (index) {
            final (label, icon) = items[index];
            return GestureDetector(
              onTap: () => setState(() => _currentSection = index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _currentSection == index ? const Color(0xFFFF4D97).withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: _currentSection == index ? const Color(0xFFFF4D97) : Colors.grey[700]),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentSection == index ? FontWeight.w600 : FontWeight.w500,
                        color: _currentSection == index ? const Color(0xFFFF4D97) : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6E8F0))),
      ),
      child: Row(
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Search users, subscriptions, audits…',
                filled: true,
                fillColor: const Color(0xFFF3F4F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildLiveTime(),
          const SizedBox(width: 12),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFF4D97),
            child: const Text('A', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTime() {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Text(
          DateFormat('MMM dd, yyyy • HH:mm').format(now),
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
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
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return FutureBuilder(
      future: Future.wait([
        _supabaseService.getAllUsers(),
        _supabaseService.getAllSubscriptions(),
        _supabaseService.getAuditLogs(limit: 5),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          );
        }

        final users = snapshot.data?[0] ?? [];
        final subscriptions = snapshot.data?[1] ?? [];

        double currentMonthProfit = 0.0;
        try {
          final monthlyData = _calculateMonthlyProfits(subscriptions);
          final currentMonthKey = DateFormat('MMM yy').format(DateTime.now());
          final monthData = monthlyData.firstWhere(
            (d) => d['month'] == currentMonthKey,
            orElse: () => {'month': currentMonthKey, 'amount': 0.0},
          );
          currentMonthProfit = (monthData['amount'] as num?)?.toDouble() ?? 0.0;
        } catch (e) {
          currentMonthProfit = 0.0;
        }

        final activeSubscriptions = subscriptions.where((s) => s['status'] == 'active').length;
        final totalAccounts = users.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard('Total Accounts', '$totalAccounts', '+2.1%', Colors.blue),
                _buildKpiCard('Active Subscriptions', '$activeSubscriptions', '+1.5%', const Color(0xFFFF4D97)),
                _buildKpiCard('Monthly Profit', '₱${currentMonthProfit.toStringAsFixed(2)}', '+0%', Colors.green),
                _buildKpiCard('Churn Rate', '1.8%', '-0.3%', Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Accounts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Email', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Role', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Created', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                      ],
                      rows: List.generate(
                        (users.length > 5 ? 5 : users.length),
                        (index) {
                          final user = users[index];
                          return DataRow(cells: [
                            DataCell(Text(user['full_name'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(user['email'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(user['role'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(
                              Text(
                                DateFormat('MMM dd, yyyy • HH:mm').format(
                                  DateTime.parse(user['created_at'] ?? DateTime.now().toIso8601String()),
                                ),
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ]);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Manage Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Account', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder(
          future: _supabaseService.getAllUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              );
            }

            final users = snapshot.data ?? [];

            if (users.isEmpty) {
              return const Center(
                child: Text(
                  'No accounts found',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Email', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Role', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Created', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                  ],
                  rows: List.generate(users.length, (index) {
                    final user = users[index];
                    return DataRow(cells: [
                      DataCell(Text(user['full_name'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                      DataCell(Text(user['email'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                      DataCell(Text(user['role'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                      DataCell(
                        Text(
                          DateFormat('MMM dd, yyyy • HH:mm').format(
                            DateTime.parse(user['created_at'] ?? DateTime.now().toIso8601String()),
                          ),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showEditAccountDialog(user),
                              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                              label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subscription Plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
            ElevatedButton.icon(
              onPressed: () => _showAddPlanDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Plan', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder(
          future: _supabaseService.getAllPlans(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              );
            }

            final plans = snapshot.data ?? [];

            if (plans.isEmpty) {
              return const Center(
                child: Text(
                  'No plans found',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Plan Name', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Price', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Billing Period', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Description', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                  ],
                  rows: List.generate(plans.length, (index) {
                    final plan = plans[index];
                    return DataRow(cells: [
                      DataCell(Text(plan['name'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                      DataCell(Text('₱${(plan['price'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(color: Colors.black87))),
                      DataCell(Text(plan['billing_period'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                      DataCell(Text(plan['description'] ?? '-', style: const TextStyle(color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFFFF4D97), size: 18),
                              onPressed: () => _showEditPlanDialog(plan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () => _showDeletePlanDialog(plan['id'], plan['name']),
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Profit Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 16),
        FutureBuilder(
          future: _supabaseService.getAllSubscriptions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              );
            }

            final subscriptions = snapshot.data ?? [];
            final monthlyData = _calculateMonthlyProfits(subscriptions);
            final totalRevenue = monthlyData.fold<double>(0, (sum, data) => sum + data['amount']);
            final avgMonthly = monthlyData.isNotEmpty ? totalRevenue / monthlyData.length : 0;

            return Column(
              children: [
                // Summary Cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildProfitCard('Total Revenue', '₱${totalRevenue.toStringAsFixed(2)}', Colors.green),
                    _buildProfitCard('Avg Monthly', '₱${avgMonthly.toStringAsFixed(2)}', Colors.blue),
                    _buildProfitCard('Active Subs', '${subscriptions.where((s) => s['status'] == 'active').length}', const Color(0xFFFF4D97)),
                  ],
                ),
                const SizedBox(height: 24),
                // Monthly Profit Chart
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Revenue Chart',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 300,
                        child: monthlyData.isEmpty
                            ? const Center(
                                child: Text(
                                  'No subscription data available',
                                  style: TextStyle(color: Colors.black54, fontSize: 14),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: true,
                                    horizontalInterval: 500,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: Colors.grey[300],
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          if (value.toInt() >= 0 && value.toInt() < monthlyData.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                monthlyData[value.toInt()]['month'],
                                                style: const TextStyle(fontSize: 10, color: Colors.black87),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 500,
                                        reservedSize: 50,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            '₱${value.toInt()}',
                                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  minX: 0,
                                  maxX: (monthlyData.length - 1).toDouble(),
                                  minY: 0,
                                  maxY: (monthlyData.map((d) => d['amount'] as double).reduce((a, b) => a > b ? a : b) * 1.2),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: List.generate(
                                        monthlyData.length,
                                        (index) => FlSpot(
                                          index.toDouble(),
                                          monthlyData[index]['amount'],
                                        ),
                                      ),
                                      isCurved: true,
                                      color: const Color(0xFFFF4D97),
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: const Color(0xFFFF4D97).withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _calculateMonthlyProfits(List<Map<String, dynamic>> subscriptions) {
    final Map<DateTime, double> monthlyRevenue = {};
    final planPrices = {
      'regular': 0.0,
      'trial': 0.0,
      'pro': 499.0,
      'premium': 999.0,
    };

    for (var sub in subscriptions) {
      final periodEndRaw = sub['current_period_end']?.toString();
      final createdAtRaw = sub['created_at']?.toString();
      final revenueDate = DateTime.tryParse(periodEndRaw ?? '') ??
          DateTime.tryParse(createdAtRaw ?? '') ??
          DateTime.now();
      final monthKey = DateTime(revenueDate.year, revenueDate.month);
      final plan = sub['plan']?.toString().toLowerCase() ?? 'trial';
      final rawCustomPrice = sub['price'] ?? sub['promo_price'];
      final customPrice = rawCustomPrice != null
          ? double.tryParse(rawCustomPrice.toString().replaceAll('₱', ''))
          : null;
      final price = customPrice ?? (planPrices[plan] ?? 0.0);
      
      monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0.0) + price;
    }

    final sortedEntries = monthlyRevenue.entries.toList()
      ..sort((a, b) {
        return a.key.compareTo(b.key);
      });

    return sortedEntries.map((entry) => {
      'month': DateFormat('MMM yy').format(entry.key),
      'amount': entry.value,
    }).toList();
  }

  Widget _buildProfitCard(String title, String value, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  String _buildAuditLogsCsv(List<Map<String, dynamic>> logs) {
    final buffer = StringBuffer();
    buffer.writeln('time,actor,action,target,metadata');
    for (final log in logs) {
      final actorData = log['accounts'] as Map<String, dynamic>?;
      final actorEmail = actorData?['email'] ?? 'System';
      final createdAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime.parse(log['created_at'] ?? DateTime.now().toIso8601String()),
      );
      final action = (log['action'] ?? '').toString().replaceAll('"', '""');
      final target = (log['target'] ?? '').toString().replaceAll('"', '""');
      final metadata = (log['metadata'] ?? '').toString().replaceAll('"', '""');
      buffer.writeln('"$createdAt","$actorEmail","$action","$target","$metadata"');
    }
    return buffer.toString();
  }

  Widget _buildAuditLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Audit Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
            ElevatedButton.icon(
              onPressed: () async {
                final logs = await _supabaseService.getAuditLogs();
                if (logs.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No audit logs to export')),
                    );
                  }
                  return;
                }

                final csv = _buildAuditLogsCsv(logs);
                final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
                try {
                  saveCsvFile('audit_logs_$timestamp.csv', csv);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audit logs exported')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download, color: Colors.white, size: 18),
              label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder(
          future: _supabaseService.getAuditLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              );
            }

            final logs = snapshot.data ?? [];

            if (logs.isEmpty) {
              return const Center(
                child: Text(
                  'No audit logs found',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Time', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Actor', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Action', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Target', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                  ],
                  rows: List.generate(logs.length, (index) {
                    final log = logs[index];
                    final actorData = log['accounts'] as Map<String, dynamic>?;
                    final actorEmail = actorData?['email'] ?? 'System';

                    return DataRow(cells: [
                      DataCell(
                        Text(
                          DateFormat('MMM dd, yyyy - HH:mm').format(
                            DateTime.parse(log['created_at'] ?? DateTime.now().toIso8601String()),
                          ),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      DataCell(Text(actorEmail, style: const TextStyle(color: Colors.black87))),
                      DataCell(Text(log['action'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                      DataCell(Text(log['target'] ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                    ]);
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String delta, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                delta.startsWith('+') ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: delta.startsWith('+') ? const Color(0xFF16A34A) : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                delta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: delta.startsWith('+') ? const Color(0xFF16A34A) : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Map<String, dynamic> account) {
    String fullName = account['full_name'] ?? '';
    String role = account['role'] ?? 'user';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: fullName),
              decoration: const InputDecoration(labelText: 'Full Name'),
              onChanged: (value) => fullName = value,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) => role = value ?? 'user',
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabaseService.updateUserProfile(
                userId: account['id'],
                updates: {
                  'full_name': fullName,
                  'role': role,
                },
              );

              await _supabaseService.logAdminAction(
                action: 'updated_account',
                target: account['email'],
                metadata: {'old_role': account['role'], 'new_role': role},
              );

              if (mounted) {
                setState(() {});
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== PLAN MANAGEMENT ====================

  void _showAddPlanDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    String billingPeriod = 'month';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Subscription Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Plan Name (e.g., Pro, Premium)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (₱)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: billingPeriod,
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('Monthly')),
                    DropdownMenuItem(value: 'year', child: Text('Yearly')),
                    DropdownMenuItem(value: 'lifetime', child: Text('Lifetime')),
                  ],
                  onChanged: (value) => setDialogState(() => billingPeriod = value ?? 'month'),
                  decoration: const InputDecoration(labelText: 'Billing Period'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
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
                if (nameController.text.isEmpty || priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }

                try {
                  await _supabaseService.createPlan(
                    name: nameController.text,
                    price: double.parse(priceController.text),
                    description: descriptionController.text.isEmpty ? null : descriptionController.text,
                    billingPeriod: billingPeriod,
                  );

                  if (mounted) {
                    setState(() {});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan created successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97)),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlanDialog(Map<String, dynamic> plan) {
    final nameController = TextEditingController(text: plan['name']);
    final priceController = TextEditingController(text: plan['price'].toString());
    final descriptionController = TextEditingController(text: plan['description'] ?? '');
    String billingPeriod = plan['billing_period'] ?? 'month';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Subscription Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Plan Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (₱)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: billingPeriod,
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('Monthly')),
                    DropdownMenuItem(value: 'year', child: Text('Yearly')),
                    DropdownMenuItem(value: 'lifetime', child: Text('Lifetime')),
                  ],
                  onChanged: (value) => setDialogState(() => billingPeriod = value ?? 'month'),
                  decoration: const InputDecoration(labelText: 'Billing Period'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
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
                try {
                  await _supabaseService.updatePlan(
                    planId: plan['id'],
                    updates: {
                      'name': nameController.text,
                      'price': double.parse(priceController.text),
                      'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                      'billing_period': billingPeriod,
                    },
                  );

                  if (mounted) {
                    setState(() {});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97)),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePlanDialog(String planId, String planName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete the "$planName" plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.deletePlan(planId);

                if (mounted) {
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== LOGOUT ====================

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabaseService.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAdmin() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: _buildCurrentSection(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentSection,
        onTap: (index) => setState(() => _currentSection = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF4D97),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership_outlined),
            activeIcon: Icon(Icons.card_membership),
            label: 'Subscriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Profit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            activeIcon: Icon(Icons.receipt),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
