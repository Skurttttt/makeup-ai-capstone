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
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
      backgroundColor: const Color(0xFFF8F9FC),
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
          Expanded(child: Container()),
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
                _buildKpiCard('Monthly Sales', '₱${currentMonthProfit.toStringAsFixed(2)}', '+0%', Colors.green),
                _buildKpiCard('Churn Rate', '1.8%', '-0.3%', Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: FutureBuilder(
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

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Sales Chart',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
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
                );
              },
                    ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      // Quick Stats Panel
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Stats',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            _buildQuickStatRow('Total Revenue', '₱${subscriptions.fold<double>(0, (sum, s) => sum + ((s['price'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}', Colors.green),
                            const SizedBox(height: 8),
                            _buildQuickStatRow('Pending', '${subscriptions.where((s) => s['status'] == 'pending').length}', Colors.orange),
                            const SizedBox(height: 8),
                            _buildQuickStatRow('Expired', '${subscriptions.where((s) => s['status'] == 'expired').length}', Colors.red),
                            const SizedBox(height: 8),
                            _buildQuickStatRow('Avg Price', '₱${subscriptions.isEmpty ? 0 : (subscriptions.fold<double>(0, (sum, s) => sum + ((s['price'] as num?)?.toDouble() ?? 0)) / subscriptions.length).toStringAsFixed(0)}', Colors.blue),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // System Health Panel
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey[50]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'System Status',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            _buildStatusIndicator('Database', true, 'Connected'),
                            const SizedBox(height: 8),
                            _buildStatusIndicator('API', true, 'Healthy'),
                            const SizedBox(height: 8),
                            _buildStatusIndicator('Storage', true, 'Operational'),
                            const SizedBox(height: 8),
                            _buildStatusIndicator('Auth Service', true, 'Active'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(String label, bool status, String message) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: status ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
              Text(message, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

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
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 14)),
          );
        }

        final users = snapshot.data?[0] ?? [];
        final subscriptions = snapshot.data?[1] ?? [];
        final totalUsers = users.length;
        final adminCount = users.where((u) => u['role'] == 'admin').length;
        final regularUsers = totalUsers - adminCount;

        // Create a map of user_id to subscription info
        final Map<String, Map<String, dynamic>> userSubscriptionMap = {};
        for (var sub in subscriptions) {
          final userId = sub['user_id'];
          if (userId != null) {
            if (!userSubscriptionMap.containsKey(userId) || sub['status'] == 'active') {
              userSubscriptionMap[userId] = sub;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard('Total Users', '$totalUsers', '+${(totalUsers > 0 ? 5 : 0)}%', Colors.blue),
                _buildKpiCard('Admin Users', '$adminCount', '+0%', Colors.purple),
                _buildKpiCard('Regular Users', '$regularUsers', '+${(regularUsers > 0 ? 5 : 0)}%', Colors.cyan),
              ],
            ),
            const SizedBox(height: 24),
            // Search and Accounts Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('Add Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D97),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE6E8F0), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE6E8F0), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF4D97), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                  dataRowHeight: 56,
                  headingRowHeight: 48,
                  dividerThickness: 1,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Name', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Email', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Role', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Subscription', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Created', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                  ],
                  rows: List.generate((_searchQuery.isEmpty
                          ? users
                          : users
                              .where((user) =>
                                  (user['full_name'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                                  (user['email'] ?? '').toString().toLowerCase().contains(_searchQuery))
                              .toList())
                      .length, (index) {
                    final filteredUsers = _searchQuery.isEmpty
                        ? users
                        : users
                            .where((user) =>
                                (user['full_name'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                                (user['email'] ?? '').toString().toLowerCase().contains(_searchQuery))
                            .toList();
                    final user = filteredUsers[index];
                    final isEvenRow = index % 2 == 0;
                    final userSub = userSubscriptionMap[user['id']];
                    final planName = userSub?['subscription_plans']?['name'] ?? 'Free';
                    
                    return DataRow(
                      color: MaterialStateProperty.all(
                        isEvenRow ? Colors.white : Colors.grey[50],
                      ),
                      cells: [
                        DataCell(Text(user['full_name'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(Text(user['email'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(Text(user['role'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getSubscriptionColor(planName).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getSubscriptionColor(planName).withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              planName,
                              style: TextStyle(
                                color: _getSubscriptionColor(planName),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormat('MMM dd, yyyy • HH:mm').format(
                              DateTime.parse(user['created_at'] ?? DateTime.now().toIso8601String()),
                            ),
                            style: const TextStyle(color: Colors.black87, fontSize: 13),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: TextButton.icon(
                                  onPressed: () => _showEditAccountDialog(user),
                                  icon: const Icon(Icons.edit, size: 16, color: Color(0xFF2563EB)),
                                  label: const Text('Edit', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: TextButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.delete, size: 16, color: Color(0xFFDC2626)),
                                  label: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionsSection() {
    return FutureBuilder(
      future: _supabaseService.getAllSubscriptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 14)),
          );
        }

        final subscriptions = snapshot.data ?? [];
        final activeCount = subscriptions.where((s) => s['status'] == 'active').length;
        final totalRevenue = subscriptions.fold<double>(0, (sum, s) => sum + ((s['price'] as num?) ?? 0).toDouble());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard('Total Subscriptions', '${subscriptions.length}', '+${(subscriptions.isNotEmpty ? 3 : 0)}%', Colors.orange),
                _buildKpiCard('Active Subscriptions', '$activeCount', '+${(activeCount > 0 ? 2 : 0)}%', const Color(0xFFFF4D97)),
                _buildKpiCard('Revenue', '₱${totalRevenue.toStringAsFixed(0)}', '+${(totalRevenue > 0 ? 5 : 0)}%', Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            // Plans Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subscription Plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                ElevatedButton.icon(
                  onPressed: () => _showAddPlanDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D97),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 14)),
                  );
                }

                final plans = snapshot.data ?? [];

                if (plans.isEmpty) {
                  return const Center(
                    child: Text('No plans found', style: TextStyle(color: Colors.black54, fontSize: 14)),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                      dataRowHeight: 56,
                      headingRowHeight: 48,
                      dividerThickness: 1,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Plan Name', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Price', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Billing Period', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Description', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Actions', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                      ],
                      rows: List.generate(plans.length, (index) {
                        final plan = plans[index];
                        final isEvenRow = index % 2 == 0;
                        return DataRow(
                          color: MaterialStateProperty.all(
                            isEvenRow ? Colors.white : Colors.grey[50],
                          ),
                          cells: [
                            DataCell(Text(plan['name'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                            DataCell(Text('₱${(plan['price'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600))),
                            DataCell(Text(plan['billing_period'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                            DataCell(Text(plan['description'] ?? '-', style: const TextStyle(color: Colors.black87, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4D97).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFFFF4D97), size: 18),
                                      onPressed: () => _showEditPlanDialog(plan),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Color(0xFFDC2626), size: 18),
                                      onPressed: () => _showDeletePlanDialog(plan['id'], plan['name']),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // User Subscriptions Management
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage User Subscriptions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                ElevatedButton.icon(
                  onPressed: () => _showAssignSubscriptionDialog(),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Assign Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                  dataRowHeight: 56,
                  headingRowHeight: 48,
                  dividerThickness: 1,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('User', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Plan', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Price', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Status', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('End Date', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                  ],
                  rows: List.generate(subscriptions.length, (index) {
                    final sub = subscriptions[index];
                    final planName = sub['subscription_plans']?['name'] ?? 'N/A';
                    final userName = sub['accounts']?['full_name'] ?? 'N/A';
                    final status = sub['status'] ?? 'N/A';
                    final price = sub['price'] ?? sub['amount_paid'] ?? 0;
                    final endDate = sub['current_period_end'] != null
                        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(sub['current_period_end']))
                        : 'N/A';
                    final isEvenRow = index % 2 == 0;

                    return DataRow(
                      color: MaterialStateProperty.all(isEvenRow ? Colors.white : Colors.grey[50]),
                      cells: [
                        DataCell(Text(userName, style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(Text(planName, style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(Text('₱${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'active' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: status == 'active' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(endDate, style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        DataCell(
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                  onPressed: () => _showDeleteSubscriptionDialog(sub['id'], userName),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        );

      },
    );
  }

  Widget _buildProfitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sales Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
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
                    _buildProfitCard('Total Sales', '₱${totalRevenue.toStringAsFixed(2)}', Colors.green),
                    _buildProfitCard('Avg Monthly', '₱${avgMonthly.toStringAsFixed(2)}', Colors.blue),
                    _buildProfitCard('Active Subs', '${subscriptions.where((s) => s['status'] == 'active').length}', const Color(0xFFFF4D97)),
                  ],
                ),
                const SizedBox(height: 24),
                // Monthly Sales Chart
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
                        'Monthly Sales Chart',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 260,
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
                const SizedBox(height: 16),
                // Daily Sales Chart (Last 30 Days)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Sales (Last 30 Days)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
                        child: () {
                          final dailyData = _calculateDailySales(subscriptions);
                          if (dailyData.isEmpty) {
                            return const Center(
                              child: Text(
                                'No daily sales data available',
                                style: TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                            );
                          }
                          return BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (dailyData.map((d) => d['amount'] as double).reduce((a, b) => a > b ? a : b) * 1.2),
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (group) => Colors.black87,
                                  tooltipPadding: const EdgeInsets.all(8),
                                  tooltipMargin: 8,
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      '${dailyData[group.x.toInt()]['date']}\n₱${rod.toY.toStringAsFixed(2)}',
                                      const TextStyle(color: Colors.white, fontSize: 12),
                                    );
                                  },
                                ),
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
                                    interval: 5,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < dailyData.length && value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            dailyData[value.toInt()]['date'],
                                            style: const TextStyle(fontSize: 9, color: Colors.black87),
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
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 100,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey[300],
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              barGroups: List.generate(
                                dailyData.length,
                                (index) => BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: dailyData[index]['amount'],
                                      color: const Color(0xFF2563EB),
                                      width: 8,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }(),
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

  List<Map<String, dynamic>> _calculateDailySales(List<Map<String, dynamic>> subscriptions) {
    final now = DateTime.now();
    final Map<DateTime, double> dailyRevenue = {};

    // Initialize last 30 days with 0
    for (int i = 29; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      dailyRevenue[date] = 0.0;
    }

    // Sum up revenue for each day
    for (var sub in subscriptions) {
      final createdAtRaw = sub['created_at']?.toString();
      final createdAt = DateTime.tryParse(createdAtRaw ?? '');
      
      if (createdAt != null) {
        final dayKey = DateTime(createdAt.year, createdAt.month, createdAt.day);
        
        // Only include if within last 30 days
        if (dayKey.isAfter(now.subtract(const Duration(days: 31))) && dayKey.isBefore(now.add(const Duration(days: 1)))) {
          double price = 0.0;
          if (sub['amount_paid'] != null) {
            price = (sub['amount_paid'] as num).toDouble();
          } else if (sub['price'] != null) {
            price = (sub['price'] as num).toDouble();
          } else if (sub['subscription_plans'] != null && sub['subscription_plans']['price'] != null) {
            price = (sub['subscription_plans']['price'] as num).toDouble();
          }
          
          dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0.0) + price;
        }
      }
    }

    final sortedEntries = dailyRevenue.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries.map((entry) => {
      'date': DateFormat('M/d').format(entry.key),
      'amount': entry.value,
    }).toList();
  }

  List<Map<String, dynamic>> _calculateMonthlyProfits(List<Map<String, dynamic>> subscriptions) {
    // Philippines timezone is UTC+8
    final phTimeZone = Duration(hours: 8);
    
    // Initialize map for last 12 months
    final Map<DateTime, double> monthlyRevenue = {};
    final now = DateTime.now().add(phTimeZone);
    
    // Create entries for last 12 months
    for (int i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i);
      final monthKey = DateTime(monthDate.year, monthDate.month);
      monthlyRevenue[monthKey] = 0.0;
    }

    for (var sub in subscriptions) {
      final periodEndRaw = sub['current_period_end']?.toString();
      final createdAtRaw = sub['created_at']?.toString();
      var revenueDate = DateTime.tryParse(periodEndRaw ?? '') ??
          DateTime.tryParse(createdAtRaw ?? '') ??
          DateTime.now();
      
      // Convert to Philippines time
      revenueDate = revenueDate.add(phTimeZone);
      
      final monthKey = DateTime(revenueDate.year, revenueDate.month);
      
      // Get price from amount_paid first, then from subscription_plans, then from price field
      double price = 0.0;
      if (sub['amount_paid'] != null) {
        price = (sub['amount_paid'] as num).toDouble();
      } else if (sub['price'] != null) {
        price = (sub['price'] as num).toDouble();
      } else if (sub['subscription_plans'] != null && sub['subscription_plans']['price'] != null) {
        price = (sub['subscription_plans']['price'] as num).toDouble();
      }
      
      if (monthlyRevenue.containsKey(monthKey)) {
        monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0.0) + price;
      }
    }

    final sortedEntries = monthlyRevenue.entries.toList()
      ..sort((a, b) {
        return a.key.compareTo(b.key);
      });

    return sortedEntries.map((entry) => {
      'month': DateFormat('MMM').format(entry.key),
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
    return FutureBuilder(
      future: _supabaseService.getAuditLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];
        final last24HourLogsCount = logs
            .where((log) {
              final logDate = DateTime.parse(log['created_at'] ?? DateTime.now().toIso8601String());
              final yesterday = DateTime.now().subtract(const Duration(hours: 24));
              return logDate.isAfter(yesterday);
            })
            .length;

        final actionMap = <String, int>{};
        for (var log in logs) {
          final action = log['action'] ?? 'unknown';
          actionMap[action] = (actionMap[action] ?? 0) + 1;
        }
        final topAction = actionMap.entries.isEmpty
            ? 'None'
            : actionMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard('Total Events', '${logs.length}', '+${logs.isNotEmpty ? 8 : 0}%', const Color(0xFF7C3AED)),
                _buildKpiCard('Last 24 Hours', '$last24HourLogsCount', '+${last24HourLogsCount > 0 ? 15 : 0}%', Colors.blue),
                _buildKpiCard('Top Action', topAction, '+12%', Colors.indigo),
              ],
            ),
            const SizedBox(height: 24),
            // Controls and Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Audit Log Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      label: const Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
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
                      label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              )
            else if (logs.isEmpty)
              const Center(
                child: Text(
                  'No audit logs found',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                    dataRowHeight: 56,
                    headingRowHeight: 48,
                    dividerThickness: 1,
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Time', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                      DataColumn(label: Text('Actor', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                      DataColumn(label: Text('Action', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                      DataColumn(label: Text('Target', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 13))),
                    ],
                    rows: List.generate(logs.length, (index) {
                      final log = logs[index];
                      final actorData = log['accounts'] as Map<String, dynamic>?;
                      final actorEmail = actorData?['email'] ?? 'System';
                      final isEvenRow = index % 2 == 0;

                      return DataRow(
                        color: MaterialStateProperty.all(
                          isEvenRow ? Colors.white : Colors.grey[50],
                        ),
                        cells: [
                          DataCell(
                            Text(
                              DateFormat('MMM dd, yyyy - HH:mm').format(
                                DateTime.parse(log['created_at'] ?? DateTime.now().toIso8601String()),
                              ),
                              style: const TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          ),
                          DataCell(Text(actorEmail, style: const TextStyle(color: Colors.black87, fontSize: 13))),
                          DataCell(Text(log['action'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                          DataCell(Text(log['target'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, String delta, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: delta.startsWith('+') ? const Color(0xFF16A34A).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  delta.startsWith('+') ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: delta.startsWith('+') ? const Color(0xFF16A34A) : Colors.red,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                delta,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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

  // ==================== USER SUBSCRIPTION MANAGEMENT ====================

  void _showAssignSubscriptionDialog() {
    String? selectedUserId;
    String? selectedPlanId;
    String? selectedDuration = '1 Month';
    final priceController = TextEditingController();
    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> plans = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load users and plans on first build
          if (users.isEmpty) {
            _supabaseService.getAllUsers().then((u) {
              setState(() => users = u);
            });
          }
          if (plans.isEmpty) {
            _supabaseService.getAllPlans().then((p) {
              setState(() => plans = p);
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Assign Subscription to User', style: TextStyle(fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select User:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedUserId,
                    hint: const Text('Choose a user'),
                    items: users.map<DropdownMenuItem<String>>((user) {
                      return DropdownMenuItem(
                        value: user['id'],
                        child: Text('${user['full_name']} (${user['email']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedUserId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Plan:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPlanId,
                    hint: const Text('Choose a plan'),
                    items: plans.map<DropdownMenuItem<String>>((plan) {
                      return DropdownMenuItem(
                        value: plan['id'],
                        child: Text(plan['name'] ?? 'N/A'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedPlanId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Price (₱):', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      hintText: 'Enter price',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  const Text('Duration:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedDuration,
                    items: ['1 Day', '1 Week', '1 Month', '3 Months', '6 Months', '1 Year', 'Lifetime']
                        .map((duration) => DropdownMenuItem(value: duration, child: Text(duration)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedDuration = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedUserId == null || selectedPlanId == null || priceController.text.isEmpty || selectedDuration == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  try {
                    // Calculate end date based on duration
                    DateTime endDate;
                    switch (selectedDuration) {
                      case '1 Day':
                        endDate = DateTime.now().add(const Duration(days: 1));
                        break;
                      case '1 Week':
                        endDate = DateTime.now().add(const Duration(days: 7));
                        break;
                      case '1 Month':
                        endDate = DateTime.now().add(const Duration(days: 30));
                        break;
                      case '3 Months':
                        endDate = DateTime.now().add(const Duration(days: 90));
                        break;
                      case '6 Months':
                        endDate = DateTime.now().add(const Duration(days: 180));
                        break;
                      case '1 Year':
                        endDate = DateTime.now().add(const Duration(days: 365));
                        break;
                      case 'Lifetime':
                        endDate = DateTime.now().add(const Duration(days: 36500));
                        break;
                      default:
                        endDate = DateTime.now().add(const Duration(days: 30));
                    }

                    final price = double.parse(priceController.text);

                    // Create subscription
                    await _supabaseService.createUserSubscription(
                      accountId: selectedUserId!,
                      planId: selectedPlanId!,
                      status: 'active',
                      currentPeriodEnd: endDate,
                      amountPaid: price,
                    );

                    // Log the action
                    await _supabaseService.logAdminAction(
                      action: 'admin_assign_subscription',
                      target: 'subscription',
                      metadata: {
                        'user_id': selectedUserId,
                        'plan_id': selectedPlanId,
                        'price': price,
                        'duration': selectedDuration,
                        'end_date': endDate.toIso8601String(),
                      },
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscription assigned successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Assign', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteSubscriptionDialog(String subscriptionId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Subscription'),
        content: Text('Are you sure you want to delete the subscription for $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.deleteSubscription(subscriptionId);

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subscription deleted successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
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

  Color _getSubscriptionColor(String planName) {
    final lowerPlan = planName.toLowerCase();
    if (lowerPlan.contains('premium')) return const Color(0xFFFFD700); // Gold
    if (lowerPlan.contains('pro')) return const Color(0xFFFF4D97); // Pink
    if (lowerPlan.contains('lifetime')) return const Color(0xFF7C3AED); // Purple
    return Colors.grey; // Free
  }

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
              // Log admin logout before signing out
              try {
                await _supabaseService.logAdminAction(
                  action: 'admin_logout',
                  target: 'auth',
                  metadata: {
                    'email': _supabaseService.client.auth.currentUser?.email,
                    'logout_time': DateTime.now().toIso8601String(),
                  },
                );
              } catch (e) {
                debugPrint('Failed to log logout audit: $e');
              }
              
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
