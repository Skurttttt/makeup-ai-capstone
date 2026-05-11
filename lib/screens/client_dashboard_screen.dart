import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class ClientDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDashboardScreen({
    super.key,
    required this.clientData,
  });

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _rangeDays = 30;
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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterByRange(List<Map<String, dynamic>> items) {
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays));
    return items.where((item) {
      final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());
      return createdAt != null && createdAt.isAfter(cutoff);
    }).toList();
  }

  List<Map<String, dynamic>> _previousRange(List<Map<String, dynamic>> items) {
    final end = DateTime.now().subtract(Duration(days: _rangeDays));
    final start = end.subtract(Duration(days: _rangeDays));
    return items.where((item) {
      final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());
      return createdAt != null &&
          createdAt.isAfter(start) &&
          createdAt.isBefore(end);
    }).toList();
  }

  String _formatDelta(double current, double previous) {
    if (previous == 0) return current == 0 ? '0%' : '+100%';
    final delta = ((current - previous) / previous) * 100;
    final sign = delta >= 0 ? '+' : '';
    return '${sign}${delta.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('order_items')
          .stream(primaryKey: ['id'])
          .eq('business_id', widget.clientData['id']),
      builder: (context, salesSnapshot) {
        final salesItems = salesSnapshot.data ?? [];
        final rangeItems = _filterByRange(salesItems);
        final previousRange = _previousRange(salesItems);

        final totalRevenue = rangeItems.fold(
          0.0,
          (sum, item) =>
              sum + ((item['total_price'] as num?)?.toDouble() ?? 0),
        );
        final totalUnitsSold = rangeItems.fold(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
        );
        final orderCount = rangeItems
            .map((item) => item['order_id']?.toString())
            .whereType<String>()
            .toSet()
            .length;
        final averageOrderValue =
            orderCount == 0 ? 0.0 : totalRevenue / orderCount;
        final previousRevenue = previousRange.fold(
          0.0,
          (sum, item) =>
              sum + ((item['total_price'] as num?)?.toDouble() ?? 0),
        );
        final previousOrders = previousRange
            .map((item) => item['order_id']?.toString())
            .whereType<String>()
            .toSet()
            .length;
        final previousUnits = previousRange.fold(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
        );

        final revenueDelta = _formatDelta(totalRevenue, previousRevenue);
        final ordersDelta = _formatDelta(orderCount.toDouble(), previousOrders.toDouble());
        final unitsDelta = _formatDelta(totalUnitsSold.toDouble(), previousUnits.toDouble());

        // Calculate recent sales with proper grouping
        final recentSales = _getRecentSales(rangeItems);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              color: pinkSoft.withOpacity(0.5),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    _buildWelcomeHeader(isDesktop),
                    const SizedBox(height: 32),

                    // Quick Stats Row
                    _buildQuickStatsRow(
                      totalRevenue,
                      orderCount,
                      totalUnitsSold,
                      averageOrderValue,
                      isDesktop,
                      revenueDelta,
                      ordersDelta,
                      unitsDelta,
                    ),
                    const SizedBox(height: 24),

                    // Time Range Selector
                    _buildTimeRangeSelector(),
                    const SizedBox(height: 32),

                    // Main Dashboard Content
                    if (isDesktop)
                      _buildDesktopLayout(
                        totalRevenue: totalRevenue,
                        orderCount: orderCount,
                        totalUnitsSold: totalUnitsSold,
                        averageOrderValue: averageOrderValue,
                        recentSales: recentSales,
                        revenueDelta: revenueDelta,
                        ordersDelta: ordersDelta,
                        unitsDelta: unitsDelta,
                        rangeItems: rangeItems,
                      )
                    else
                      _buildMobileLayout(
                        totalRevenue: totalRevenue,
                        orderCount: orderCount,
                        totalUnitsSold: totalUnitsSold,
                        averageOrderValue: averageOrderValue,
                        recentSales: recentSales,
                        revenueDelta: revenueDelta,
                        ordersDelta: ordersDelta,
                        unitsDelta: unitsDelta,
                        rangeItems: rangeItems,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(bool isDesktop) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Icons.dashboard_rounded,
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
                      'Welcome Back! 👋',
                      style: TextStyle(
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.clientData['business_name'] ?? 'Your Business'} • Dashboard Overview',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade400,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Live Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Track your store performance in real-time 💖',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _buildQuickStatsRow(
    double totalRevenue,
    int orderCount,
    int totalUnitsSold,
    double averageOrderValue,
    bool isDesktop,
    String revenueDelta,
    String ordersDelta,
    String unitsDelta,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStat(
            _formatCompactCurrency(totalRevenue),
            'Revenue',
            Icons.trending_up,
            pinkPrimary,
            revenueDelta,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStat(
            orderCount.toString(),
            'Orders',
            Icons.receipt_long,
            pinkAccent,
            ordersDelta,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStat(
            totalUnitsSold.toString(),
            'Units Sold',
            Icons.shopping_bag_outlined,
            pinkDark,
            unitsDelta,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(
    String value,
    String label,
    IconData icon,
    Color color,
    String delta,
  ) {
    final isPositive = delta.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: pinkDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        delta,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
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
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pinkLight.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [7, 30, 90, 365].map((days) {
          final isSelected = _rangeDays == days;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _rangeDays = days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [pinkPrimary, pinkAccent],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: pinkPrimary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    days == 365 ? '1 Year' : '${days}d',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : pinkDark,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesktopLayout({
    required double totalRevenue,
    required int orderCount,
    required int totalUnitsSold,
    required double averageOrderValue,
    required List<Map<String, dynamic>> recentSales,
    required String revenueDelta,
    required String ordersDelta,
    required String unitsDelta,
    required List<Map<String, dynamic>> rangeItems,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildPerformanceOverview(
                totalRevenue,
                orderCount,
                totalUnitsSold,
                averageOrderValue,
                revenueDelta,
                ordersDelta,
                unitsDelta,
              ),
              const SizedBox(height: 24),
              _buildSalesChart(rangeItems, totalRevenue),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildRecentSalesCard(recentSales),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout({
    required double totalRevenue,
    required int orderCount,
    required int totalUnitsSold,
    required double averageOrderValue,
    required List<Map<String, dynamic>> recentSales,
    required String revenueDelta,
    required String ordersDelta,
    required String unitsDelta,
    required List<Map<String, dynamic>> rangeItems,
  }) {
    return Column(
      children: [
        _buildPerformanceOverview(
          totalRevenue,
          orderCount,
          totalUnitsSold,
          averageOrderValue,
          revenueDelta,
          ordersDelta,
          unitsDelta,
        ),
        const SizedBox(height: 24),
        _buildSalesChart(rangeItems, totalRevenue),
        const SizedBox(height: 24),
        _buildRecentSalesCard(recentSales),
      ],
    );
  }

  Widget _buildPerformanceOverview(
    double totalRevenue,
    int orderCount,
    int totalUnitsSold,
    double averageOrderValue,
    String revenueDelta,
    String ordersDelta,
    String unitsDelta,
  ) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Overview 📈',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [pinkSoft, pinkLight.withOpacity(0.3)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last $_rangeDays days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pinkPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _buildPerformanceCard(
                'Total Revenue',
                _formatCompactCurrency(totalRevenue),
                Icons.attach_money_rounded,
                pinkPrimary,
                revenueDelta,
              ),
              _buildPerformanceCard(
                'Orders',
                orderCount.toString(),
                Icons.receipt_long_rounded,
                pinkAccent,
                ordersDelta,
              ),
              _buildPerformanceCard(
                'Units Sold',
                totalUnitsSold.toString(),
                Icons.shopping_bag_rounded,
                pinkDark,
                unitsDelta,
              ),
              _buildPerformanceCard(
                'Avg Order',
                _formatCompactCurrency(averageOrderValue),
                Icons.analytics_rounded,
                const Color(0xFFE91E63),
                '', // No delta for average
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String delta,
  ) {
    final isPositive = delta.startsWith('+');
    final hasDelta = delta.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.05), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (hasDelta)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        delta,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(List<Map<String, dynamic>> rangeItems, double total) {
    // Generate daily revenue data for the chart
    final dailyRevenue = _generateDailyRevenue(rangeItems);
    
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: pinkDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Daily revenue overview',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [pinkSoft, pinkLight.withOpacity(0.3)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatCompactCurrency(total),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: pinkPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _DashboardChartPainter(
                data: dailyRevenue,
                color: pinkPrimary,
              ),
              size: const Size(double.infinity, 200),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dailyRevenue.length > 7 ? 7 : dailyRevenue.length,
              (index) {
                final day = DateTime.now().subtract(Duration(days: _rangeDays - 1 - (index * (_rangeDays ~/ 7))));
                return Text(
                  DateFormat('M/d').format(day),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesCard(List<Map<String, dynamic>> recentSales) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Sales 🛍️',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: pinkPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSales.isEmpty)
            _buildEmptyState('No recent sales yet')
          else
            ...recentSales.map((sale) => _buildSaleItem(sale)),
        ],
      ),
    );
  }

  Widget _buildSaleItem(Map<String, dynamic> sale) {
    final createdAt =
        DateTime.tryParse((sale['created_at'] ?? '').toString()) ?? DateTime.now();
    final quantity = (sale['quantity'] as num?)?.toInt() ?? 0;
    final total = (sale['total_price'] as num?)?.toDouble() ?? 0;
    final productName = (sale['product_name'] ?? 'Product').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pinkSoft.withOpacity(0.5), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pinkLight.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [pinkPrimary.withOpacity(0.15), pinkAccent.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.shopping_bag_rounded,
              color: pinkPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$quantity item${quantity == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      _formatCompactCurrency(total),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pinkPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getTimeAgo(createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pinkSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 32,
                color: pinkLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRecentSales(List<Map<String, dynamic>> items) {
    // Sort by created_at and take the most recent 10
    final sorted = [...items]
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString());
        return (bDate ?? DateTime.now()).compareTo(aDate ?? DateTime.now());
      });
    return sorted.take(10).toList();
  }

  List<double> _generateDailyRevenue(List<Map<String, dynamic>> items) {
    // Generate mock daily data for the chart
    final days = _rangeDays > 90 ? 12 : 7;
    return List.generate(days, (index) {
      return (math.Random().nextDouble() * 10000) + 2000;
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(1)}K';
    }
    return _formatPHP(amount);
  }
}

class _DashboardChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _DashboardChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Add dots paint
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = 0.0; // Start from zero
    final range = maxValue - minValue;

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * (size.height - 20);

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, gradientPaint);
    
    // Draw line
    canvas.drawPath(path, paint);

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        3,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

String _formatPHP(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'fil_PH',
    symbol: '₱',
    decimalDigits: amount == amount.toInt() ? 0 : 2,
  );
  return formatter.format(amount);
}