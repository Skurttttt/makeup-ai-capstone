// lib/screens/chat_list_screen.dart
//
// Lists all chat conversations for the current user (buyer or seller view).

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

const Color _kPink = Color(0xFFFF4D97);

class ChatListScreen extends StatefulWidget {
  final bool sellerMode;
  const ChatListScreen({super.key, this.sellerMode = false});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final svc = ChatService.instance;
    return widget.sellerMode
        ? svc.listConversationsForSeller()
        : svc.listConversationsForBuyer();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: _kPink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.sellerMode ? 'Customer Messages' : 'My Messages'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _kPink,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _kPink));
            }
            final conversations = snapshot.data ?? const [];
            if (conversations.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Icon(Icons.chat_bubble_outline,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      widget.sellerMode
                          ? 'No customer messages yet.'
                          : 'No conversations yet.\nStart by chatting with a seller from a product page!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, i) {
                final c = conversations[i];
                final account = c['accounts'] as Map?;
                final name = (account?['business_name'] ??
                        account?['full_name'] ??
                        (widget.sellerMode ? 'Customer' : 'Seller'))
                    .toString();
                final last = (c['last_message'] ?? 'Tap to open conversation')
                    .toString();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _kPink.withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _kPink, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    final myUid =
                        Supabase.instance.client.auth.currentUser?.id;
                    final isSellerForThis =
                        widget.sellerMode && c['seller_id'] == myUid;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: c['id'].toString(),
                          otherDisplayName: name,
                          currentUserIsSeller: isSellerForThis,
                        ),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
