// lib/screens/admin_audit_logs_section.dart
// Audit Logs section: full audit-log table with CSV export.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/export_helper.dart';
import '../utils/responsive.dart';
import 'admin_shared.dart';

class AdminAuditLogsSection extends StatefulWidget {
  const AdminAuditLogsSection({super.key});

  @override
  State<AdminAuditLogsSection> createState() => _AdminAuditLogsSectionState();
}

class _AdminAuditLogsSectionState extends State<AdminAuditLogsSection> {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();

  List<dynamic> _logs = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _actionFilter = 'all';
  bool _isExporting = false;
  double _exportProgress = 0.0;

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
      final logs = await _supabaseService.getAuditLogs();
      if (!mounted) return;
      setState(() { _logs = logs; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _distinctActions {
    final actions = _logs
        .map((l) => l['action']?.toString() ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return actions;
  }

  List<dynamic> get _filteredLogs {
    return _logs.where((log) {
      final action = log['action']?.toString() ?? '';
      final target = log['target']?.toString() ?? '';
      final user = log['accounts']?['email']?.toString() ?? '';
      final matchesSearch = _searchQuery.isEmpty ||
          action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          target.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesAction =
          _actionFilter == 'all' || action == _actionFilter;
      return matchesSearch && matchesAction;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminTheme.accentColor));
    }

    if (_error != null) {
      return Center(
        child: buildErrorState('Failed to load audit logs',
            details: _error, onRetry: _loadData),
      );
    }

    final filtered = _filteredLogs;
    final today = DateTime.now();
    final todayCount = _logs.where((l) {
      final dt = DateTime.tryParse(l['created_at']?.toString() ?? '');
      return dt != null &&
          dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }).length;

    // Build action filter items
    final actionItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Actions')),
      ..._distinctActions.map((a) => DropdownMenuItem(
            value: a,
            child: Text(a.replaceAll('_', ' '),
                overflow: TextOverflow.ellipsis),
          )),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(_sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          buildSectionHeader(
            context,
            'System Audit Logs',
            actions: [
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: primaryButtonStyle(AdminTheme.successColor),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _exportAuditLogs(filtered, onlyFiltered: filtered.length != _logs.length),
                icon: _isExporting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: _exportProgress > 0 ? _exportProgress : null,
                            color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_isExporting
                    ? '${(_exportProgress * 100).toInt()}%'
                    : filtered.length != _logs.length
                        ? 'Export Filtered (${filtered.length})'
                        : 'Export All (${_logs.length})'),
                style: primaryButtonStyle(AdminTheme.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Stats ──
          buildAdaptiveCardGrid(
            minWidth: 160,
            children: [
              buildSummaryCard('Total Logs', '${_logs.length}',
                  Icons.list_alt_rounded, AdminTheme.accentColor),
              buildSummaryCard('Today', '$todayCount',
                  Icons.today_rounded, AdminTheme.successColor),
              buildSummaryCard(
                  'Action Types',
                  '${_distinctActions.length}',
                  Icons.category_rounded,
                  AdminTheme.warningColor),
              buildSummaryCard(
                  'Showing',
                  '${filtered.length}',
                  Icons.filter_list_rounded,
                  AdminTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 24),

          // ── Filters ──
          buildFilterBar(
            searchController: _searchController,
            searchHint: 'Search by action, user, or target...',
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onClearSearch: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            filters: [
              FilterDropdown(
                value: _actionFilter,
                label: 'Action',
                items: actionItems,
                onChanged: (v) => setState(() => _actionFilter = v ?? 'all'),
              ),
            ],
            onResetFilters: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _actionFilter = 'all'; });
            },
          ),
          const SizedBox(height: 16),

          // ── Log Timeline ──
          if (filtered.isEmpty)
            _buildEmptyState(
              _searchQuery.isNotEmpty || _actionFilter != 'all'
                  ? 'No logs match your filters'
                  : 'No audit logs recorded yet',
              Icons.history_rounded,
            )
          else
            _buildTimeline(filtered),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AdminTheme.textSecondary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  size: 40, color: AdminTheme.textSecondary.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> logs) {
    // Group by date
    final Map<String, List<dynamic>> grouped = {};
    for (final log in logs) {
      final dt = DateTime.tryParse(log['created_at']?.toString() ?? '');
      final key = dt != null
          ? DateFormat('MMM dd, yyyy').format(dt)
          : 'Unknown Date';
      grouped.putIfAbsent(key, () => []).add(log);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AdminTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.accentColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Divider(
                          color: AdminTheme.borderColor, thickness: 1)),
                  const SizedBox(width: 8),
                  Text('${entry.value.length}',
                      style: const TextStyle(
                          fontSize: 12, color: AdminTheme.textSecondary)),
                ],
              ),
            ),
            // Log entries
            ...entry.value.map((log) => _buildLogEntry(log)).toList(),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final action = log['action']?.toString() ?? 'unknown';
    final target = log['target']?.toString() ?? '';
    final user = log['accounts']?['email']?.toString() ?? 'System';
    final metadata = log['metadata'];
    final dt = DateTime.tryParse(log['created_at']?.toString() ?? '');
    final timeStr = dt != null ? DateFormat('HH:mm:ss').format(dt) : '';
    final actionColor = getActionColor(action);
    final actionIcon = getActionIcon(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(actionIcon, size: 18, color: actionColor),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Action chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: actionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: actionColor.withOpacity(0.25)),
                        ),
                        child: Text(
                          action.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: actionColor),
                        ),
                      ),
                      const Spacer(),
                      Text(timeStr,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AdminTheme.textSecondary,
                              fontFamily: 'monospace')),
                    ],
                  ),
                  if (target.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.arrow_right_rounded,
                            size: 14, color: AdminTheme.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(target,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AdminTheme.textPrimary),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 12, color: AdminTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(user,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AdminTheme.textSecondary)),
                      if (metadata != null &&
                          metadata.toString().isNotEmpty &&
                          metadata.toString() != '{}') ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.info_outline_rounded,
                            size: 12, color: AdminTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            metadata.toString(),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AdminTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== EXPORT ====================

  /// Wraps a value in CSV quotes and escapes embedded double-quotes.
  String _csvField(String? value) {
    final v = (value ?? '').replaceAll('"', '""');
    return '"$v"';
  }

  void _exportAuditLogs(List<dynamic> logs,
      {bool onlyFiltered = false}) async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });
    try {
      final buffer = StringBuffer();
      // UTF-8 BOM so Excel opens it correctly without garbling
      buffer.write('\uFEFF');
      buffer.writeln('Timestamp,User Email,User Name,Action,Target,Details');
      for (var i = 0; i < logs.length; i++) {
        final log = logs[i];
        final dt = DateTime.tryParse(log['created_at']?.toString() ?? '');
        final timestamp = dt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal())
            : '';
        buffer.writeln([
          _csvField(timestamp),
          _csvField(log['accounts']?['email']?.toString() ?? 'System'),
          _csvField(log['accounts']?['full_name']?.toString() ?? ''),
          _csvField(log['action']?.toString() ?? ''),
          _csvField(log['target']?.toString() ?? ''),
          _csvField(log['metadata']?.toString() ?? ''),
        ].join(','));
        if (mounted) {
          setState(() => _exportProgress = (i + 1) / logs.length);
        }
        // Yield every 50 rows so the progress bar can animate
        if (i % 50 == 0) await Future.delayed(Duration.zero);
      }
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final filename = onlyFiltered
          ? 'audit_logs_filtered_$ts.csv'
          : 'audit_logs_$ts.csv';
      await saveCsvFile(filename, buffer.toString());
      if (mounted) {
        showAdminSnackBar(
          context,
          'Exported ${logs.length} log${logs.length != 1 ? 's' : ''}',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdminSnackBar(context, 'Export failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 1.0;
        });
      }
    }
  }
}
