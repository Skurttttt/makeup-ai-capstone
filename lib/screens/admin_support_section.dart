// lib/screens/admin_support_section.dart
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import 'admin_shared.dart';

class AdminSupportSection extends StatefulWidget {
  final int initialTabIndex;
  const AdminSupportSection({super.key, this.initialTabIndex = 0});

  @override
  State<AdminSupportSection> createState() => _AdminSupportSectionState();
}

class _AdminSupportSectionState extends State<AdminSupportSection> {
  final SupabaseService _supabase = SupabaseService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supports = await _supabase.getSupportRequests();
      final feedbacks = await _supabase.getFeedbacks();
      if (!mounted) return;
      setState(() {
        // merge, supports first then feedbacks
        _requests = [...supports, ...feedbacks];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _exportAsPdf(Map<String, dynamic> r) async {
    try {
      final doc = pw.Document();
      final source = (r['_source'] as String?) ?? 'support';
      final subject = r['subject']?.toString() ?? (source == 'feedback' ? 'App Feedback' : 'Support Request');
      final message = r['message']?.toString() ?? '';
      final created = r['created_at']?.toString() ?? '';
      final email = (r['accounts']?['email'] as String?) ?? r['email'] as String? ?? '';

      doc.addPage(pw.Page(build: (pw.Context ctx) {
        return pw.Column(
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
        );
      }));

      final bytes = await doc.save();
      final suggestedName = '${source}_${r['id'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await getSavePath(suggestedName: suggestedName, acceptedTypeGroups: [XTypeGroup(label: 'PDF', extensions: ['pdf'])]);
      if (path == null) return;
      final file = File(path);
      await file.writeAsBytes(bytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await _updateStatusForSource(id, status, 'support');
  }

  Future<void> _updateStatusForSource(String id, String status, String source) async {
    try {
      if (source == 'feedback') {
        await _supabase.updateFeedbackStatus(feedbackId: id, status: status);
      } else {
        await _supabase.updateSupportRequestStatus(requestId: id, status: status);
      }
      await _loadRequests();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Center(child: Text('No items'));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = items[i];
        final id = r['id']?.toString() ?? '';
        final source = (r['_source'] as String?) ?? 'support';
        final subject = r['subject']?.toString() ??
            (source == 'feedback' ? 'App Feedback' : 'Support Request');
        final message = r['message']?.toString() ?? '';
        final status = r['status']?.toString() ?? 'open';
        final created = r['created_at']?.toString();
        final email =
            (r['accounts']?['email'] as String?) ?? r['email'] as String? ?? '';
        final userName = (r['accounts']?['full_name'] as String?) ?? '';
        final rating = (r['rating'] as num?)?.toInt();
        DateTime? dt;
        if (created != null) dt = DateTime.tryParse(created);

        final statusColor = switch (status) {
          'resolved' => Colors.green,
          'in_progress' => Colors.orange,
          'closed' => Colors.grey,
          _ => Colors.blue,
        };

        return ListTile(
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: source == 'feedback'
                      ? Colors.purple.withOpacity(0.12)
                      : Colors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source == 'feedback' ? 'FEEDBACK' : 'SUPPORT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: source == 'feedback'
                        ? Colors.purple.shade700
                        : Colors.teal.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (rating != null)
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (i) => Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: i < rating
                                  ? const Color(0xFFFFB400)
                                  : Colors.grey.shade300,
                            )),
                    const SizedBox(width: 4),
                    Text('$rating/5',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFFF8A00))),
                  ],
                ),
              if (rating != null) const SizedBox(height: 4),
              Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (userName.isNotEmpty)
                    Text(userName,
                        style: TextStyle(color: Colors.grey[600])),
                  if (email.isNotEmpty) ...[
                    if (userName.isNotEmpty) const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(
                            'mailto:$email?subject=${Uri.encodeComponent(subject)}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      child: Text(email,
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.primary)),
                    ),
                  ],
                  const SizedBox(width: 12),
                  if (dt != null)
                    Text(DateFormat('MMM d • HH:mm').format(dt),
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reply') {
                final uri = Uri.parse(
                    'mailto:$email?subject=${Uri.encodeComponent('Re: $subject')}');
                launchUrl(uri);
              } else if (v == 'export') {
                _exportAsPdf(r);
              } else {
                _updateStatusForSource(id, v, source);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Mark Open')),
              const PopupMenuItem(
                  value: 'in_progress', child: Text('Mark In Progress')),
              const PopupMenuItem(
                  value: 'resolved', child: Text('Mark Resolved')),
              const PopupMenuDivider(),
              if (email.isNotEmpty)
                const PopupMenuItem(
                    value: 'reply', child: Text('Reply via Email')),
              const PopupMenuItem(value: 'export', child: Text('Export PDF')),
            ],
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: statusColor.withOpacity(0.1),
              ),
              child: Text(
                status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: statusColor),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _requests.where((r) => (r['_source'] as String?) == 'support').toList();
    final feedbacks = _requests.where((r) => (r['_source'] as String?) == 'feedback').toList();

    return Container(
      padding: const EdgeInsets.all(24),
      color: AdminTheme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Support / Feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 40, color: Colors.red),
                            const SizedBox(height: 8),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadRequests,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : DefaultTabController(
                    length: 2,
                    initialIndex: widget.initialTabIndex,
                    child: Column(
                      children: [
                        const TabBar(tabs: [Tab(text: 'Contacts'), Tab(text: 'Feedbacks')]),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Contacts
                              _buildList(contacts),
                              // Feedbacks
                              _buildList(feedbacks),
                            ],
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
}
