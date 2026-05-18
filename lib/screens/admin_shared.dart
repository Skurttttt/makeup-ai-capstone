// lib/screens/admin_shared.dart
// Shared utilities, theme constants, data models, and widget builders
// used across all admin section screens.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/responsive.dart';

// ==================== UTILITIES ====================

String formatPHP(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'fil_PH',
    symbol: '₱',
    decimalDigits: amount == amount.toInt() ? 0 : 2,
  );
  return formatter.format(amount);
}

// ==================== THEME ====================

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

// ==================== DATA MODELS ====================

class NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  NavigationItem(this.icon, this.label, this.index);
}

class AdminQuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  AdminQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class FilterDropdown {
  final String value;
  final String label;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  FilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });
}

class TablePagination {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  TablePagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });
}

// ==================== UTILITY FUNCTIONS ====================

Color getStatusColor(String status) {
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

Color getActionColor(String action) {
  if (action.contains('create') || action.contains('add')) return AdminTheme.successColor;
  if (action.contains('delete') || action.contains('remove')) return AdminTheme.dangerColor;
  if (action.contains('update') || action.contains('edit')) return AdminTheme.accentColor;
  return AdminTheme.warningColor;
}

IconData getActionIcon(String action) {
  if (action.contains('create') || action.contains('add')) return Icons.add_circle_rounded;
  if (action.contains('delete') || action.contains('remove')) return Icons.delete_rounded;
  if (action.contains('update') || action.contains('edit')) return Icons.edit_rounded;
  return Icons.info_rounded;
}

List<Map<String, dynamic>> calculateMonthlyProfits(List<dynamic> subscriptions) {
  final Map<String, double> monthlyData = {};
  final now = DateTime.now();

  for (int i = 11; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final key = DateFormat('MMM').format(month);
    monthlyData[key] = 0.0;
  }

  for (var sub in subscriptions) {
    final date =
        DateTime.tryParse(sub['created_at']?.toString() ?? '') ?? DateTime.now();
    final key = DateFormat('MMM').format(date);
    if (monthlyData.containsKey(key)) {
      final amount = (sub['amount_paid'] as num?)?.toDouble() ?? 0;
      monthlyData[key] = (monthlyData[key] ?? 0) + amount;
    }
  }

  return monthlyData.entries
      .map((e) => {'month': e.key, 'amount': e.value})
      .toList();
}

void showAdminSnackBar(BuildContext context, String message,
    {required bool isError}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AdminTheme.dangerColor : AdminTheme.successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ),
  );
}

// ==================== SHARED WIDGET BUILDERS ====================

ButtonStyle primaryButtonStyle(Color color) {
  return ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 0,
  );
}

Widget buildSectionHeader(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  bool isSubsection = false,
}) {
  final isCompact = context.isCompact;
  return Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: isSubsection ? 18 : (isCompact ? 20 : 24),
            fontWeight: FontWeight.w700,
            color: AdminTheme.textPrimary,
          ),
        ),
      ),
      if (actions != null) ...actions,
    ],
  );
}

Widget buildKpiCard(
  BuildContext context,
  String title,
  String value,
  IconData icon,
  Color color,
  String trend,
) {
  final isCompact = context.isCompact;
  return Container(
    padding: EdgeInsets.all(isCompact ? 16 : 20),
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
            if (trend.isNotEmpty)
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: trend.startsWith('+')
                        ? AdminTheme.successColor
                        : AdminTheme.dangerColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 24 : 28,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textPrimary,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: isCompact ? 12 : 13,
            color: AdminTheme.textSecondary,
          ),
        ),
      ],
    ),
  );
}

Widget buildRevenueChart(List<dynamic> subscriptions) {
  final monthlyData = calculateMonthlyProfits(subscriptions);

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
          height: 250,
          child: monthlyData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart_rounded,
                          size: 48,
                          color: AdminTheme.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text(
                        'No revenue data available',
                        style: TextStyle(
                            color: AdminTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
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
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '₱${value.toInt()}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < monthlyData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  monthlyData[value.toInt()]['month'],
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AdminTheme.textSecondary),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            return LineTooltipItem(
                              '₱${spot.y.toStringAsFixed(0)}',
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthlyData
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(),
                                (e.value['amount'] as num).toDouble()))
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.3,
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

Widget buildFilterBar({
  required TextEditingController searchController,
  required String searchHint,
  required String searchQuery,
  required Function(String) onSearchChanged,
  required VoidCallback onClearSearch,
  required List<FilterDropdown> filters,
  required VoidCallback onResetFilters,
  bool showExport = false,
  VoidCallback? onExport,
  bool isExporting = false,
  double exportProgress = 0.0,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminTheme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdminTheme.borderColor),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: onClearSearch,
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AdminTheme.accentColor, width: 2),
                      ),
                      filled: true,
                      fillColor: AdminTheme.backgroundColor,
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                if (showExport && onExport != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isExporting ? null : onExport,
                    icon: isExporting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: exportProgress,
                            ),
                          )
                        : Icon(Icons.download_rounded,
                            color: AdminTheme.accentColor),
                    tooltip: 'Export CSV',
                    style: IconButton.styleFrom(
                      backgroundColor: AdminTheme.accentColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (filters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ...filters.map((filter) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AdminTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AdminTheme.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: filter.value,
                                isExpanded: true,
                                isDense: true,
                                hint: Text(filter.label),
                                items: filter.items,
                                onChanged: filter.onChanged,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AdminTheme.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      )),
                  TextButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      foregroundColor: AdminTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );
}

Widget buildScrollableTable({
  required List<DataColumn> columns,
  required List<DataRow> rows,
  TablePagination? pagination,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AdminTheme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdminTheme.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(AdminTheme.backgroundColor),
              headingRowHeight: 48,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              dividerThickness: 1,
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: columns,
              rows: rows,
            ),
          ),
          if (pagination != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AdminTheme.borderColor)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: pagination.currentPage > 0
                          ? () => pagination
                              .onPageChanged(pagination.currentPage - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Page ${pagination.currentPage + 1} of ${pagination.totalPages}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      onPressed: pagination.currentPage <
                              pagination.totalPages - 1
                          ? () => pagination
                              .onPageChanged(pagination.currentPage + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget buildAdaptiveCardGrid({
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
      final itemWidth = (available - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

Widget buildSummaryCard(
    String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminTheme.cardColor,
      borderRadius: BorderRadius.circular(12),
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildTableActionButton(
    IconData icon, String tooltip, Color color, VoidCallback onTap) {
  return Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

Widget buildErrorState(String title,
    {String? details, VoidCallback? onRetry}) {
  return Container(
    margin: const EdgeInsets.all(24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AdminTheme.dangerColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AdminTheme.dangerColor.withOpacity(0.2)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTheme.dangerColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.error_outline_rounded,
              size: 32, color: AdminTheme.dangerColor),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AdminTheme.dangerColor,
          ),
          textAlign: TextAlign.center,
        ),
        if (details != null) ...[
          const SizedBox(height: 8),
          Text(
            details,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 13, color: AdminTheme.textSecondary),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    ),
  );
}
