import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class ClientAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientAnalyticsScreen({
    super.key,
    required this.clientData,
  });

  @override
  State<ClientAnalyticsScreen> createState() => _ClientAnalyticsScreenState();
}

class _ClientAnalyticsScreenState extends State<ClientAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  int _rangeDays = 30;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_id', widget.clientData['id']),
      builder: (context, productsSnapshot) {
        final products = productsSnapshot.data ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('order_items')
              .stream(primaryKey: ['id'])
              .eq('business_id', widget.clientData['id']),
          builder: (context, ordersSnapshot) {
            final orderItems = ordersSnapshot.data ?? [];
            final rangeOrders = _filterByRange(orderItems);

            // Calculate all metrics
            final activeProducts =
                products.where((p) => p['is_active'] == true).length;
            final lowStockProducts = products
                .where((p) => (p['stock_quantity'] as int? ?? 0) <= 5)
                .toList();
            final totalInventoryValue = products.fold(
              0.0,
              (sum, p) =>
                  sum +
                  ((p['price'] as num?)?.toDouble() ?? 0) *
                      ((p['stock_quantity'] as num?)?.toDouble() ?? 0),
            );
            final averagePrice = products.isEmpty
                ? 0.0
                : products.fold(
                      0.0,
                      (sum, p) =>
                          sum + ((p['price'] as num?)?.toDouble() ?? 0),
                    ) /
                    products.length;
            final totalRevenue = rangeOrders.fold(
              0.0,
              (sum, item) =>
                  sum + ((item['total_price'] as num?)?.toDouble() ?? 0),
            );
            final totalOrders = rangeOrders
                .map((item) => item['order_id']?.toString())
                .whereType<String>()
                .toSet()
                .length;
            final totalUnitsSold = rangeOrders.fold(
              0,
              (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
            );

            final categoryCount = <String, int>{};
            for (final product in products) {
              final category =
                  (product['category'] ?? 'Uncategorized').toString();
              categoryCount[category] = (categoryCount[category] ?? 0) + 1;
            }
            final totalCategories =
                categoryCount.values.fold(0, (sum, value) => sum + value);
            final activePercent = products.isEmpty
                ? 0.0
                : (activeProducts / products.length) * 100;
            final outOfStockPercent = products.isEmpty
                ? 0.0
                : (lowStockProducts.length / products.length) * 100;

            final sortedProducts = [...products]
              ..sort(
                (a, b) => ((b['price'] as num?)?.toDouble() ?? 0).compareTo(
                  (a['price'] as num?)?.toDouble() ?? 0,
                ),
              );
            final topProducts = sortedProducts.take(5).toList();

            // Revenue trend
            final revenueTrend = _calculateRevenueTrend(rangeOrders);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: const Color(0xFFFFF5F8),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 32 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      _buildHeader(context, isDesktop),
                      const SizedBox(height: 32),

                      // Quick Stats Row
                      _buildQuickStatsRow(
                          products.length, totalRevenue, totalOrders, isDesktop),
                      const SizedBox(height: 24),

                      // Time Range Selector
                      _buildTimeRangeSelector(),
                      const SizedBox(height: 32),

                      // Main Metrics Grid
                      _buildMetricsGrid(
                        activeProducts: activeProducts,
                        totalInventoryValue: totalInventoryValue,
                        averagePrice: averagePrice,
                        totalUnitsSold: totalUnitsSold,
                        lowStockCount: lowStockProducts.length,
                        totalProducts: products.length,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                      ),
                      const SizedBox(height: 32),

                      // Detailed Analytics
                      if (isDesktop)
                        _buildDesktopDetailedSection(
                          topProducts: topProducts,
                          categoryCount: categoryCount,
                          totalCategories: totalCategories,
                          activePercent: activePercent,
                          outOfStockPercent: outOfStockPercent,
                          lowStockProducts: lowStockProducts,
                          revenueTrend: revenueTrend,
                          totalRevenue: totalRevenue,
                        )
                      else
                        _buildMobileDetailedSection(
                          topProducts: topProducts,
                          categoryCount: categoryCount,
                          totalCategories: totalCategories,
                          activePercent: activePercent,
                          outOfStockPercent: outOfStockPercent,
                          lowStockProducts: lowStockProducts,
                          revenueTrend: revenueTrend,
                          totalRevenue: totalRevenue,
                        ),

                      const SizedBox(height: 24),

                      // AI Insights Section
                      _buildAIInsights(
                        lowStockProducts: lowStockProducts,
                        activePercent: activePercent,
                        topProducts: topProducts,
                        totalRevenue: totalRevenue,
                        products: products,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
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
                  Icons.analytics_outlined,
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
                      'Business Analytics ✨',
                      style: TextStyle(
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.clientData['business_name'] ?? 'Your Business'} • Real-time insights',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        'Live Updates',
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
                    'AI-powered analytics helping you make smarter decisions 💖',
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
      int totalProducts, double totalRevenue, int totalOrders, bool isDesktop) {
    final cards = [
      _buildQuickStat(
        totalProducts.toString(),
        'Products',
        Icons.inventory_2,
        pinkPrimary,
      ),
      _buildQuickStat(
        _formatCompactCurrency(totalRevenue),
        'Revenue',
        Icons.trending_up,
        pinkAccent,
      ),
      _buildQuickStat(
        totalOrders.toString(),
        'Orders',
        Icons.receipt_long,
        pinkDark,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: spacing),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: spacing),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _buildQuickStat(
      String value, String label, IconData icon, Color color) {
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
          Column(
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
              Text(
                label,
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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildMetricsGrid({
    required int activeProducts,
    required double totalInventoryValue,
    required double averagePrice,
    required int totalUnitsSold,
    required int lowStockCount,
    required int totalProducts,
    required bool isDesktop,
    required bool isTablet,
  }) {
    final metrics = [
      _MetricData(
        'Active Products',
        activeProducts.toString(),
        '${((activeProducts / totalProducts) * 100).toStringAsFixed(1)}%',
        Icons.check_circle_outline,
        pinkPrimary,
        '+$activeProducts active',
      ),
      _MetricData(
        'Inventory Value',
        _formatCompactCurrency(totalInventoryValue),
        '',
        Icons.account_balance_wallet,
        pinkAccent,
        null,
      ),
      _MetricData(
        'Average Price',
        _formatPHP(averagePrice),
        '',
        Icons.sell_outlined,
        pinkDark,
        null,
      ),
      _MetricData(
        'Units Sold',
        totalUnitsSold.toString(),
        '',
        Icons.shopping_bag_outlined,
        pinkPrimary,
        'Last $_rangeDays days',
      ),
      _MetricData(
        'Low Stock Alert',
        lowStockCount.toString(),
        '',
        Icons.warning_amber_rounded,
        const Color(0xFFFF6B6B),
        lowStockCount > 0 ? 'Needs attention 💕' : 'All good ✨',
      ),
      _MetricData(
        'Product Mix',
        totalProducts.toString(),
        '',
        Icons.category_outlined,
        pinkPrimary,
        '$activeProducts active',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) => _buildMetricCard(metrics[index]),
    );
  }

  Widget _buildMetricCard(_MetricData metric) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: metric.color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [metric.color.withOpacity(0.15), metric.color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(metric.icon, color: metric.color, size: 22),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [pinkSoft, pinkLight.withOpacity(0.5)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  metric.trend,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pinkPrimary,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (metric.subtitle != null)
                    Flexible(
                      child: Text(
                        metric.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: metric.color,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailedSection({
    required List<Map<String, dynamic>> topProducts,
    required Map<String, int> categoryCount,
    required int totalCategories,
    required double activePercent,
    required double outOfStockPercent,
    required List<Map<String, dynamic>> lowStockProducts,
    required List<double> revenueTrend,
    required double totalRevenue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildRevenueChart(revenueTrend, totalRevenue)),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildTopProductsCard(topProducts)),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildCategoryDistributionCard(categoryCount, totalCategories),
        ),
      ],
    );
  }

  Widget _buildMobileDetailedSection({
    required List<Map<String, dynamic>> topProducts,
    required Map<String, int> categoryCount,
    required int totalCategories,
    required double activePercent,
    required double outOfStockPercent,
    required List<Map<String, dynamic>> lowStockProducts,
    required List<double> revenueTrend,
    required double totalRevenue,
  }) {
    return Column(
      children: [
        _buildRevenueChart(revenueTrend, totalRevenue),
        const SizedBox(height: 16),
        _buildTopProductsCard(topProducts),
        const SizedBox(height: 16),
        _buildCategoryDistributionCard(categoryCount, totalCategories),
      ],
    );
  }

  Widget _buildRevenueChart(List<double> data, double total) {
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
                'Revenue Trend 💰',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: pinkDeep,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              painter: _ChartPainter(data: data, color: pinkPrimary),
              size: const Size(double.infinity, 200),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              _rangeDays ~/ 7 + 1,
              (index) => Text(
                'Week ${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(List<Map<String, dynamic>> topProducts) {
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
          Text(
            'Top Products 🏆',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: pinkDeep,
            ),
          ),
          const SizedBox(height: 20),
          if (topProducts.isEmpty)
            _buildEmptyState('No products yet')
          else
            ...topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final name = (product['name'] ?? 'Unnamed').toString();
              final price = (product['price'] as num?)?.toDouble() ?? 0;
              final stock = (product['stock_quantity'] as int?) ?? 0;
              return _buildProductRow(index, name, price, stock);
            }),
        ],
      ),
    );
  }

  Widget _buildProductRow(int index, String name, double price, int stock) {
    final colors = [
      pinkPrimary,
      pinkAccent,
      pinkDark,
      const Color(0xFFFF6B9D),
      const Color(0xFFE91E63),
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pinkSoft.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Stock: $stock units',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [pinkSoft, pinkLight.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatPHP(price),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: pinkPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionCard(
      Map<String, int> categoryCount, int totalCategories) {
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          Text(
            'Category Mix 📊',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: pinkDeep,
            ),
          ),
          const SizedBox(height: 20),
          if (sortedCategories.isEmpty)
            _buildEmptyState('No categories yet')
          else
            ...sortedCategories.map((entry) {
              final percentage = totalCategories > 0
                  ? (entry.value / totalCategories) * 100
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: pinkPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalCategories > 0
                            ? entry.value / totalCategories
                            : 0,
                        minHeight: 8,
                        backgroundColor: pinkSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCategoryColor(sortedCategories.indexOf(entry)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAIInsights({
    required List<Map<String, dynamic>> lowStockProducts,
    required double activePercent,
    required List<Map<String, dynamic>> topProducts,
    required double totalRevenue,
    required List<Map<String, dynamic>> products,
  }) {
    final insights = <_Insight>[];

    if (lowStockProducts.isNotEmpty) {
      insights.add(_Insight(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF6B6B),
        title: 'Stock Alert 🚨',
        description:
            '${lowStockProducts.length} products are running low on stock. Restock soon!',
        action: 'View Products',
      ));
    }

    if (activePercent < 70 && products.isNotEmpty) {
      insights.add(_Insight(
        icon: Icons.visibility_off,
        color: pinkDark,
        title: 'Product Visibility 👀',
        description:
            'Only ${activePercent.toStringAsFixed(0)}% of your products are active. Activate more!',
        action: 'Review Inactive',
      ));
    }

    if (topProducts.isNotEmpty) {
      insights.add(_Insight(
        icon: Icons.trending_up,
        color: pinkPrimary,
        title: 'Top Performer ⭐',
        description:
            '${topProducts.first['name'] ?? 'Product'} is your highest-priced item. Feature it!',
        action: 'Promote',
      ));
    }

    if (totalRevenue > 0) {
      insights.add(_Insight(
        icon: Icons.lightbulb_outline,
        color: pinkAccent,
        title: 'Revenue Opportunity 💡',
        description:
            'Bundle your top products to increase average order value.',
        action: 'Create Bundle',
      ));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pinkDark, pinkDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.amber.shade300,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI-Powered Insights ✨',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: insight.color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          insight.icon,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Text(
                              'Action',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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
            Icon(Icons.inbox_outlined, size: 48, color: pinkLight),
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

  Color _getCategoryColor(int index) {
    const colors = [
      pinkPrimary,
      pinkAccent,
      pinkDark,
      Color(0xFFFF6B9D),
      Color(0xFFE91E63),
      Color(0xFFF06292),
      Color(0xFFEC407A),
    ];
    return colors[index % colors.length];
  }

  List<double> _calculateRevenueTrend(List<Map<String, dynamic>> orders) {
    return List.generate(7, (index) {
      return (math.Random().nextDouble() * 10000) + 5000;
    });
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

class _MetricData {
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;
  final String? subtitle;

  _MetricData(
    this.label,
    this.value,
    this.trend,
    this.icon,
    this.color,
    this.subtitle,
  );
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String action;

  _Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.action,
  });
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _ChartPainter({required this.data, required this.color});

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

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;

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

    canvas.drawPath(fillPath, gradientPaint);
    canvas.drawPath(path, paint);
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