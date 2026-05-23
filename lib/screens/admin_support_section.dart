import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_selector/file_selector.dart';
import '../services/supabase_service.dart';
import 'admin_shared.dart';

// ── colour palette ─────────────────────────────────────────────────────────
const _kOpen       = Color(0xFF3B82F6);
const _kInProgress = Color(0xFFF59E0B);
const _kResolved   = Color(0xFF10B981);
const _kClosed     = Color(0xFF94A3B8);
const _kSupport    = Color(0xFF0EA5E9);
const _kFeedback   = Color(0xFF8B5CF6);

Color _statusColor(String s) => switch (s) {
  'open'        => _kOpen,
  'in_progress' => _kInProgress,
  'resolved'    => _kResolved,
  'closed'      => _kClosed,
  _             => _kOpen,
};

IconData _statusIcon(String s) => switch (s) {
  'open'        => Icons.inbox_rounded,
  'in_progress' => Icons.timelapse_rounded,
  'resolved'    => Icons.check_circle_rounded,
  'closed'      => Icons.cancel_rounded,
  _             => Icons.inbox_rounded,
};

String _statusLabel(String s) => switch (s) {
  'open'        => 'Open',
  'in_progress' => 'In Progress',
  'resolved'    => 'Resolved',
  'closed'      => 'Closed',
  _             => 'Open',
};

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60)   return 'Just now';
  if (diff.inMinutes < 60)   return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24)   return '${diff.inHours}h ago';
  if (diff.inDays    < 7)    return '${diff.inDays}d ago';
  if (diff.inDays    < 30)   return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays    < 365)  return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

Color _avatarColor(String initial) {
  const palette = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFF8B5CF6), Color(0xFFEF4444), Color(0xFF0EA5E9),
    Color(0xFF14B8A6), Color(0xFFF97316),
  ];
  return palette[initial.codeUnitAt(0) % palette.length];
}

// ─────────────────────────────────────────────────────────────────────────────

class AdminSupportSection extends StatefulWidget {
  final int initialTabIndex;
  const AdminSupportSection({super.key, this.initialTabIndex = 0});

  @override
  State<AdminSupportSection> createState() => _AdminSupportSectionState();
}

class _AdminSupportSectionState extends State<AdminSupportSection>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  bool  _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  String _contactFilter  = 'all';
  String _feedbackFilter = 'all';
  String _search         = '';

  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final supports  = await _supabase.getSupportRequests();
      final feedbacks = await _supabase.getFeedbacks();
      if (!mounted) return;
      setState(() {
        _requests = [...supports, ...feedbacks];
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _exportAsPdf(Map<String, dynamic> r) async {
    try {
      final doc     = pw.Document();
      final source  = (r['_source'] as String?) ?? 'support';
      final subject = r['subject']?.toString() ??
          (source == 'feedback' ? 'App Feedback' : 'Support Request');
      final message = r['message']?.toString() ?? '';
      final created = r['created_at']?.toString() ?? '';
      final email   = (r['accounts']?['email'] as String?) ??
          r['email'] as String? ?? '';

      doc.addPage(pw.Page(build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(subject, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('From: $email'),
          pw.SizedBox(height: 4),
          pw.Text('Created: $created'),
          pw.SizedBox(height: 12),
          pw.Text(message),
        ],
      )));

      final bytes = await doc.save();
      final suggestedName =
          '${source}_${r['id'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await getSavePath(
          suggestedName: suggestedName,
          acceptedTypeGroups: [const XTypeGroup(label: 'PDF', extensions: ['pdf'])]);
      if (path == null) return;
      await File(path).writeAsBytes(bytes);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Exported to $path')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _setStatus(String id, String status, String source) async {
    try {
      if (source == 'feedback') {
        await _supabase.updateFeedbackStatus(feedbackId: id, status: status);
      } else {
        await _supabase.updateSupportRequestStatus(requestId: id, status: status);
      }
      await _loadRequests();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _openDetail(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (_) => _DetailDialog(
        item:            r,
        onStatusChanged: (s) => _setStatus(
            r['id']?.toString() ?? '', s,
            (r['_source'] as String?) ?? 'support'),
        onExport: () => _exportAsPdf(r),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> items, String filter) {
    var result = filter == 'all'
        ? items
        : items.where((r) => (r['status'] ?? 'open') == filter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((r) {
        return [
          r['subject'],
          r['message'],
          r['accounts']?['email'] ?? r['email'],
          r['accounts']?['full_name'],
        ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
      }).toList();
    }
    return result;
  }

  // ── stat card ──────────────────────────────────────────────────────────────
  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AdminTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── pill filter row ────────────────────────────────────────────────────────
  Widget _filterRow(String current, ValueChanged<String> onChange,
      List<Map<String, dynamic>> src) {
    const opts = [
      ('all', 'All'), ('open', 'Open'), ('in_progress', 'In Progress'),
      ('resolved', 'Resolved'), ('closed', 'Closed'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: opts.map((opt) {
            final (val, lbl) = opt;
            final active = current == val;
            final col    = val == 'all' ? AdminTheme.accentColor : _statusColor(val);
            final cnt    = val == 'all'
                ? src.length
                : src.where((r) => (r['status'] ?? 'open') == val).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap:        () => onChange(val),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color:        active ? col : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? col : AdminTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lbl,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AdminTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withOpacity(0.25)
                              : AdminTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$cnt',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: active ? Colors.white : col)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── list ───────────────────────────────────────────────────────────────────
  Widget _buildList(List<Map<String, dynamic>> items, String filter) {
    final list = _applyFilters(items, filter);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:        AdminTheme.backgroundColor,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: AdminTheme.borderColor),
              ),
              child: Icon(
                _search.isNotEmpty
                    ? Icons.search_off_rounded
                    : filter == 'all' ? Icons.inbox_outlined : _statusIcon(filter),
                size: 36, color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _search.isNotEmpty
                  ? 'No results for "$_search"'
                  : filter == 'all' ? 'Nothing here yet'
                      : 'No ${_statusLabel(filter).toLowerCase()} items',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AdminTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _search.isNotEmpty
                  ? 'Try a different search term'
                  : 'Items will appear here when users submit',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, i) => _ItemCard(
        item: list[i],
        onTap: () => _openDetail(list[i]),
        onStatusChanged: (s) => _setStatus(
            list[i]['id']?.toString() ?? '', s,
            (list[i]['_source'] as String?) ?? 'support'),
      ),
    );
  }

  Tab _buildTab(String label, int count, IconData icon, Color color) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 7),
            Text(label),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts  =
        _requests.where((r) => (r['_source'] as String?) == 'support').toList();
    final feedbacks =
        _requests.where((r) => (r['_source'] as String?) == 'feedback').toList();

    final openCount = _requests.where((r) => (r['status'] ?? 'open') == 'open').length;
    final inpCount  = _requests.where((r) => r['status'] == 'in_progress').length;
    final resCount  = _requests.where((r) => r['status'] == 'resolved').length;

    return Container(
      color: AdminTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ HEADER ══════════════════════════════════════════════════════════
          Container(
            color:   Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Support / Feedback',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800,
                                color: AdminTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Manage user support requests and app feedback',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  // ── search ──────────────────────────────────────────────
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged:  (v) => setState(() => _search = v.trim()),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:  'Search...',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: Colors.grey.shade400),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    size: 16, color: Colors.grey.shade400),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                })
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        filled:    true,
                        fillColor: AdminTheme.backgroundColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AdminTheme.borderColor)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AdminTheme.borderColor)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AdminTheme.accentColor)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _loadRequests,
                    icon:    const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh',
                    style:   IconButton.styleFrom(
                      backgroundColor: AdminTheme.backgroundColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
                // ── stats ──
                if (!_loading && _error == null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    _statCard('Total',       _requests.length, AdminTheme.accentColor, Icons.forum_rounded),
                    const SizedBox(width: 10),
                    _statCard('Open',        openCount,        _kOpen,       Icons.inbox_rounded),
                    const SizedBox(width: 10),
                    _statCard('In Progress', inpCount,         _kInProgress, Icons.timelapse_rounded),
                    const SizedBox(width: 10),
                    _statCard('Resolved',    resCount,         _kResolved,   Icons.check_circle_rounded),
                  ]),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ══ BODY ════════════════════════════════════════════════════════════
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Loading…',
                          style: TextStyle(color: AdminTheme.textSecondary)),
                    ]))
                : _error != null
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(Icons.error_outline_rounded,
                                size: 36, color: Colors.red.shade300),
                          ),
                          const SizedBox(height: 14),
                          const Text('Failed to load data',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadRequests,
                            icon:  const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0),
                          ),
                        ]))
                    : Container(
                        color: Colors.white,
                        child: Column(children: [
                          // tab bar
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(
                                  color: AdminTheme.borderColor)),
                            ),
                            child: TabBar(
                              controller:           _tabController,
                              indicatorColor:       AdminTheme.accentColor,
                              indicatorWeight:      3,
                              indicatorSize:        TabBarIndicatorSize.tab,
                              labelColor:           AdminTheme.accentColor,
                              unselectedLabelColor: AdminTheme.textSecondary,
                              labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                              unselectedLabelStyle:
                                  const TextStyle(fontSize: 13),
                              tabs: [
                                _buildTab('Contacts',  contacts.length,
                                    Icons.headset_mic_rounded,  _kSupport),
                                _buildTab('Feedbacks', feedbacks.length,
                                    Icons.rate_review_rounded, _kFeedback),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _tabPane(contacts, _contactFilter,
                                    (v) => setState(() => _contactFilter = v)),
                                _tabPane(feedbacks, _feedbackFilter,
                                    (v) => setState(() => _feedbackFilter = v)),
                              ],
                            ),
                          ),
                        ]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tabPane(List<Map<String, dynamic>> items, String filter,
      ValueChanged<String> onFilter) {
    return Container(
      color: AdminTheme.backgroundColor,
      child: Column(children: [
        _filterRow(filter, onFilter, items),
        Expanded(child: _buildList(items, filter)),
      ]),
    );
  }
}

// ── item card ─────────────────────────────────────────────────────────────────
class _ItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback         onTap;
  final ValueChanged<String> onStatusChanged;

  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r        = widget.item;
    final source   = (r['_source'] as String?) ?? 'support';
    final subject  = r['subject']?.toString() ??
        (source == 'feedback' ? 'App Feedback' : 'Support Request');
    final message  = r['message']?.toString() ?? '';
    final status   = r['status']?.toString() ?? 'open';
    final created  = r['created_at']?.toString();
    final email    =
        (r['accounts']?['email'] as String?) ?? r['email'] as String? ?? '';
    final userName = (r['accounts']?['full_name'] as String?) ?? '';
    final rating   = (r['rating'] as num?)?.toInt();

    DateTime? dt;
    if (created != null) dt = DateTime.tryParse(created);

    final sColor    = _statusColor(status);
    final isSupport = source != 'feedback';
    final srcColor  = isSupport ? _kSupport : _kFeedback;

    final initial     = (userName.isNotEmpty ? userName : email.isNotEmpty ? email : '?')[0].toUpperCase();
    final avatarColor = _avatarColor(initial);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _hovered
                  ? srcColor.withOpacity(0.4)
                  : const Color(0xFFE2E8F0)),
          boxShadow: _hovered
              ? [BoxShadow(
                  color: srcColor.withOpacity(0.1),
                  blurRadius: 14, offset: const Offset(0, 4))]
              : [const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: InkWell(
          onTap:        widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // coloured left accent strip
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: srcColor,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── top row ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // avatar
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color:        avatarColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(initial,
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700,
                                      color: avatarColor)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName.isNotEmpty ? userName : email,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: AdminTheme.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (userName.isNotEmpty && email.isNotEmpty)
                                    Text(email,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // source badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:        srcColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSupport
                                        ? Icons.headset_mic_rounded
                                        : Icons.rate_review_rounded,
                                    size: 10, color: srcColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSupport ? 'SUPPORT' : 'FEEDBACK',
                                    style: TextStyle(
                                        fontSize: 9, fontWeight: FontWeight.w800,
                                        color: srcColor)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // status dropdown pill
                            PopupMenuButton<String>(
                              tooltip:    'Change status',
                              onSelected: widget.onStatusChanged,
                              itemBuilder: (_) => [
                                _mItem('open',        Icons.inbox_rounded,        'Open',        _kOpen),
                                _mItem('in_progress', Icons.timelapse_rounded,    'In Progress', _kInProgress),
                                _mItem('resolved',    Icons.check_circle_rounded, 'Resolved',    _kResolved),
                                _mItem('closed',      Icons.cancel_rounded,       'Closed',      _kClosed),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:        sColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: sColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_statusIcon(status), size: 11, color: sColor),
                                    const SizedBox(width: 4),
                                    Text(_statusLabel(status),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: sColor)),
                                    const SizedBox(width: 2),
                                    Icon(Icons.expand_more_rounded,
                                        size: 13, color: sColor),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // subject
                        Text(subject,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: AdminTheme.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        // stars
                        if (rating != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            ...List.generate(5, (i) => Icon(
                                  i < rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 14,
                                  color: i < rating
                                      ? const Color(0xFFFFB400)
                                      : Colors.grey.shade300)),
                            const SizedBox(width: 5),
                            Text('$rating/5',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF8A00))),
                          ]),
                        ],
                        // message preview
                        const SizedBox(height: 6),
                        Text(
                          message.isEmpty ? '(no message)' : message,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500,
                              height: 1.5),
                        ),
                        // footer
                        const SizedBox(height: 10),
                        Row(children: [
                          if (dt != null) ...[
                            Icon(Icons.access_time_rounded,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(_timeAgo(dt),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400)),
                          ],
                          const Spacer(),
                          Text('Tap to view',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _hovered ? srcColor : Colors.grey.shade400,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: _hovered ? srcColor : Colors.grey.shade400),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _mItem(
      String val, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── detail dialog ─────────────────────────────────────────────────────────────
class _DetailDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback         onExport;

  const _DetailDialog({
    required this.item,
    required this.onStatusChanged,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final source   = (item['_source'] as String?) ?? 'support';
    final subject  = item['subject']?.toString() ??
        (source == 'feedback' ? 'App Feedback' : 'Support Request');
    final message  = item['message']?.toString() ?? '';
    final status   = item['status']?.toString() ?? 'open';
    final created  = item['created_at']?.toString();
    final email    =
        (item['accounts']?['email'] as String?) ?? item['email'] as String? ?? '';
    final userName = (item['accounts']?['full_name'] as String?) ?? '';
    final rating   = (item['rating'] as num?)?.toInt();

    DateTime? dt;
    if (created != null) dt = DateTime.tryParse(created);

    final sColor    = _statusColor(status);
    final isSupport = source != 'feedback';
    final srcColor  = isSupport ? _kSupport : _kFeedback;

    final initial     = (userName.isNotEmpty ? userName : email.isNotEmpty ? email : '?')[0].toUpperCase();
    final avatarColor = _avatarColor(initial);

    return Dialog(
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 580, minWidth: 380, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: isSupport
                      ? [const Color(0xFF0369A1), const Color(0xFF0EA5E9)]
                      : [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSupport
                        ? Icons.headset_mic_rounded
                        : Icons.rate_review_rounded,
                    color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(isSupport ? 'Support Request' : 'App Feedback',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
                IconButton(
                  icon:   const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),

            // body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // user row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color:        avatarColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(initial,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700,
                                  color: avatarColor)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName.isNotEmpty ? userName : email,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AdminTheme.textPrimary),
                              ),
                              if (userName.isNotEmpty && email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(email,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500)),
                              ],
                              if (dt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d, yyyy  h:mm a').format(dt),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:        sColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sColor.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_statusIcon(status), size: 13, color: sColor),
                            const SizedBox(width: 5),
                            Text(_statusLabel(status),
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: sColor)),
                          ]),
                        ),
                      ],
                    ),

                    // star rating
                    if (rating != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE58F)),
                        ),
                        child: Row(children: [
                          ...List.generate(5, (i) => Icon(
                                i < rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 22,
                                color: i < rating
                                    ? const Color(0xFFFFB400)
                                    : Colors.grey.shade300)),
                          const SizedBox(width: 10),
                          Text('$rating out of 5',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706))),
                        ]),
                      ),
                    ],

                    // message
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.message_outlined,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text('Message',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600)),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        AdminTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminTheme.borderColor),
                      ),
                      child: SelectableText(
                        message.isEmpty ? '(no message provided)' : message,
                        style: const TextStyle(
                            fontSize: 14, color: AdminTheme.textPrimary,
                            height: 1.65),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AdminTheme.borderColor))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set status',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    ...[
                      ('open',        Icons.inbox_rounded,        'Open',        _kOpen),
                      ('in_progress', Icons.timelapse_rounded,    'In Progress', _kInProgress),
                      ('resolved',    Icons.check_circle_rounded, 'Resolved',    _kResolved),
                      ('closed',      Icons.cancel_rounded,       'Closed',      _kClosed),
                    ].map((t) {
                      final (val, icon, lbl, col) = t;
                      final active = status == val;
                      return InkWell(
                        onTap: () {
                          onStatusChanged(val);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: active
                                ? col.withOpacity(0.12)
                                : AdminTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: active
                                    ? col.withOpacity(0.5)
                                    : AdminTheme.borderColor),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icon, size: 14, color: col),
                            const SizedBox(width: 6),
                            Text(lbl,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: col)),
                          ]),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    if (email.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(
                              'mailto:$email?subject=${Uri.encodeComponent('Re: $subject')}');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        icon:  const Icon(Icons.reply_rounded, size: 14),
                        label: const Text('Reply',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: srcColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        onExport();
                        Navigator.pop(context);
                      },
                      icon:  const Icon(Icons.picture_as_pdf_rounded, size: 14),
                      label: const Text('Export PDF',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
