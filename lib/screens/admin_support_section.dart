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
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
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
      if (mounted) setState(() => _loading = false);
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
        final subject = r['subject']?.toString() ?? 'Support';
        final message = r['message']?.toString() ?? '';
        final status = r['status']?.toString() ?? 'open';
        final created = r['created_at']?.toString();
        final email = (r['accounts']?['email'] as String?) ?? r['email'] as String? ?? '';
        final userName = (r['accounts']?['full_name'] as String?) ?? '';
        DateTime? dt;
        if (created != null) dt = DateTime.tryParse(created);

        return ListTile(
          title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (userName.isNotEmpty) Text(userName, style: TextStyle(color: Colors.grey[600])),
                  if (email.isNotEmpty) ...[
                    if (userName.isNotEmpty) const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      child: Text(email, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ),
                  ],
                  const SizedBox(width: 12),
                  if (dt != null) Text(DateFormat('MMM d • HH:mm').format(dt), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              final src = (r['_source'] as String?) ?? 'support';
              if (v == 'reply') {
                final uri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent('Re: $subject')}');
                launchUrl(uri);
              } else if (v == 'export') {
                _exportAsPdf(r);
              } else {
                _updateStatusForSource(id, v, src);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Mark Open')),
              const PopupMenuItem(value: 'in_progress', child: Text('Mark In Progress')),
              const PopupMenuItem(value: 'resolved', child: Text('Mark Resolved')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'reply', child: Text('Reply via Email')),
              const PopupMenuItem(value: 'export', child: Text('Export PDF')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: status == 'resolved' ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
              ),
              child: Text(status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: status == 'resolved' ? Colors.green : Colors.grey[800])),
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
