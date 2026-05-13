// lib/screens/chat_screen.dart
//
// Single-conversation chat UI using ChatService. Subscribes to realtime
// messages and posts a rule-based bot reply when the seller hasn't replied
// within a short window.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';

const Color _kPink = Color(0xFFFF4D97);

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherDisplayName;
  final String? productName;
  final bool currentUserIsSeller;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherDisplayName,
    this.productName,
    this.currentUserIsSeller = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _service = ChatService.instance;

  late final Stream<List<Map<String, dynamic>>> _stream;
  StreamSubscription? _sub;
  Timer? _botTimer;
  String? _myUid;

  String get _role => widget.currentUserIsSeller ? 'seller' : 'buyer';

  @override
  void initState() {
    super.initState();
    _myUid = Supabase.instance.client.auth.currentUser?.id;
    _stream = _service.messagesStream(widget.conversationId);
    _sub = _stream.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _botTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _service.sendMessage(
      conversationId: widget.conversationId,
      body: text,
      role: _role,
    );

    // For buyer messages, schedule a bot fallback if seller hasn't replied
    // within a few seconds.
    if (_role == 'buyer') {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(seconds: 4), () async {
        // Check if a seller message came after this point.
        final msgs = await _service.loadMessages(widget.conversationId);
        if (msgs.isEmpty) return;
        final last = msgs.last;
        if (last['sender_role'] == 'buyer') {
          final reply = await _service.botReplyFor(text);
          if (reply != null) {
            await _service.sendMessage(
              conversationId: widget.conversationId,
              body: reply,
              role: 'bot',
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: _kPink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherDisplayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.productName != null)
              Text(widget.productName!,
                  style:
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                final msgs = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    msgs.isEmpty) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kPink));
                }
                if (msgs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            widget.currentUserIsSeller
                                ? 'No messages yet from this customer.'
                                : 'Say hi to the seller! 👋',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final role = m['sender_role'] as String? ?? 'buyer';
                    final isMine = m['sender_id']?.toString() == _myUid &&
                        role != 'bot';
                    final isBot = role == 'bot';
                    return _MessageBubble(
                      text: (m['body'] ?? '').toString(),
                      isMine: isMine,
                      isBot: isBot,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final bool isBot;

  const _MessageBubble({
    required this.text,
    required this.isMine,
    required this.isBot,
  });

  @override
  Widget build(BuildContext context) {
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isBot
        ? const Color(0xFFEDE7F6)
        : (isMine ? _kPink : Colors.white);
    final fg = isBot ? Colors.deepPurple.shade700 : (isMine ? Colors.white : Colors.black87);
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: isMine
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBot)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.smart_toy_outlined,
                      size: 13, color: Colors.deepPurple),
                  const SizedBox(width: 4),
                  Text('Assistant',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700)),
                ],
              ),
            if (isBot) const SizedBox(height: 4),
            Text(text, style: TextStyle(color: fg, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _kPink,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
