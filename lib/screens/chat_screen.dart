// lib/screens/chat_screen.dart
//
// Single-conversation chat UI using ChatService. Subscribes to realtime
// messages and posts a rule-based bot reply when the seller hasn't replied
// within a short window. Shows a pinned product context card when the
// conversation was started from a product page.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_service.dart';

const Color _kPink = Color(0xFFFF4D97);
const Color _kPinkDeep = Color(0xFFCC3A7A);
const Color _kBg = Color(0xFFF7F5FB);

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherDisplayName;
  final String? productId;
  final String? productName;
  final String? productImage;
  final double? productPrice;
  final String? productCurrency;
  final bool currentUserIsSeller;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherDisplayName,
    this.productId,
    this.productName,
    this.productImage,
    this.productPrice,
    this.productCurrency,
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
  bool _uploadingImage = false;
  bool _botTyping = false;

  // Resolved product context (passed in OR fetched from conversation row).
  String? _productId;
  String? _productName;
  String? _productImage;
  double? _productPrice;
  String? _productCurrency;

  String get _role => widget.currentUserIsSeller ? 'seller' : 'buyer';

  @override
  void initState() {
    super.initState();
    _myUid = Supabase.instance.client.auth.currentUser?.id;

    _productId = widget.productId;
    _productName = widget.productName;
    _productImage = widget.productImage;
    _productPrice = widget.productPrice;
    _productCurrency = widget.productCurrency;

    _stream = _service.messagesStream(widget.conversationId);
    _sub = _stream.listen((_) {
      // With reverse:true, position 0.0 is the bottom (newest message).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });

    // If the product wasn't passed, try to load it from the conversation.
    if (_productId == null || _productImage == null) {
      _hydrateProductContext();
    }
  }

  Future<void> _hydrateProductContext() async {
    try {
      final client = Supabase.instance.client;
      final conv = await client
          .from('chat_conversations')
          .select('product_id')
          .eq('id', widget.conversationId)
          .maybeSingle();
      final productId =
          (conv?['product_id'] ?? _productId)?.toString();
      if (productId == null || productId.isEmpty) return;

      final product = await client
          .from('products')
          .select('id, name, image_url, price, currency')
          .eq('id', productId)
          .maybeSingle();
      if (product == null || !mounted) return;
      setState(() {
        _productId = product['id']?.toString();
        _productName ??= product['name']?.toString();
        _productImage ??= product['image_url']?.toString();
        final raw = product['price'];
        _productPrice ??= raw is num
            ? raw.toDouble()
            : double.tryParse(raw?.toString() ?? '');
        _productCurrency ??= product['currency']?.toString();
      });
    } catch (_) {
      // Ignore, banner just won't show.
    }
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

    if (_role == 'buyer') {
      _botTimer?.cancel();
      // Show "typing…" almost immediately for that snappy Shopee feel.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _botTyping = true);
      });
      _botTimer = Timer(const Duration(milliseconds: 1500), () async {
        try {
          final msgs = await _service.loadMessages(widget.conversationId);
          if (msgs.isEmpty || msgs.last['sender_role'] != 'buyer') return;
          final reply = await _service.botReply(
            text,
            conversationId: widget.conversationId,
          );
          if (reply.text.isNotEmpty || reply.productCards.isNotEmpty) {
            await _service.sendBotReply(
              conversationId: widget.conversationId,
              reply: reply,
            );
          }
        } finally {
          if (mounted) setState(() => _botTyping = false);
        }
      });
    }
  }

  void _sendQuickReply(String text) {
    _input.text = text;
    _send();
  }

  String _formatPrice() {
    if (_productPrice == null) return '';
    final cur = _productCurrency ?? 'PHP';
    return '$cur ${_productPrice!.toStringAsFixed(2)}';
  }

  Future<void> _pickAndSendImage() async {
    if (_uploadingImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: _kPink),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: _kPink),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _service.uploadChatImage(
        conversationId: widget.conversationId,
        file: File(picked.path),
      );
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
        return;
      }
      final caption = _input.text.trim();
      _input.clear();
      await _service.sendMessage(
        conversationId: widget.conversationId,
        body: caption,
        role: _role,
        imageUrl: url,
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProduct = _productName != null && _productName!.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.25),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  widget.otherDisplayName.isNotEmpty
                      ? widget.otherDisplayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Active now',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPink, _kPinkDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (hasProduct) _buildProductBanner(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                final raw = snapshot.data ?? const [];
                // Always sort ascending by created_at so newest is last,
                // regardless of how the realtime stream orders rows.
                final msgs = List<Map<String, dynamic>>.from(raw)
                  ..sort((a, b) {
                    final ta = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final tb = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return ta.compareTo(tb);
                  });
                if (snapshot.connectionState == ConnectionState.waiting &&
                    msgs.isEmpty) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kPink));
                }
                if (msgs.isEmpty) {
                  return _buildEmptyState(hasProduct);
                }
                // Render newest at the bottom; reverse:true makes the list
                // sit at the bottom and grow upward as new messages arrive.
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: msgs.length + (_botTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    // Typing indicator pinned at the bottom (index 0 in reversed list).
                    if (_botTyping && i == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: _TypingIndicator(),
                      );
                    }
                    final adjusted = _botTyping ? i - 1 : i;
                    final realIndex = msgs.length - 1 - adjusted;
                    final m = msgs[realIndex];
                    final role = m['sender_role'] as String? ?? 'buyer';
                    final isMine = m['sender_id']?.toString() == _myUid &&
                        role != 'bot';
                    final isBot = role == 'bot';
                    final prev =
                        realIndex == 0 ? null : msgs[realIndex - 1];
                    final showAvatarGap = prev == null ||
                        (prev['sender_role'] != role) ||
                        (prev['sender_id']?.toString() !=
                            m['sender_id']?.toString());
                    final meta = m['metadata'];
                    Map<String, dynamic>? metaMap;
                    if (meta is Map) {
                      metaMap = Map<String, dynamic>.from(meta);
                    }
                    return Padding(
                      padding: EdgeInsets.only(top: showAvatarGap ? 8 : 2),
                      child: _MessageBubble(
                        text: (m['body'] ?? '').toString(),
                        imageUrl: m['image_url']?.toString(),
                        isMine: isMine,
                        isBot: isBot,
                        timestamp: m['created_at']?.toString(),
                        metadata: metaMap,
                        onSuggestionTap: _sendQuickReply,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            onSend: _send,
            onAttach: _pickAndSendImage,
            uploading: _uploadingImage,
          ),
        ],
      ),
    );
  }

  // ----- Product context banner (pinned below appBar) -----
  Widget _buildProductBanner() {
    final priceText = _formatPrice();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPink.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: _kPink.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFFFFF0F5),
              child: (_productImage == null || _productImage!.isEmpty)
                  ? const Icon(Icons.shopping_bag_outlined,
                      color: _kPink, size: 26)
                  : Image.network(
                      _productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: _kPink,
                        size: 26,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CHATTING ABOUT',
                    style: TextStyle(
                      color: _kPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _productName ?? 'Product',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                if (priceText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: _kPink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool hasProduct) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPink.withOpacity(0.08),
              ),
              child: const Icon(Icons.waving_hand_outlined,
                  size: 50, color: _kPink),
            ),
            const SizedBox(height: 16),
            Text(
              widget.currentUserIsSeller
                  ? 'No messages from this customer yet'
                  : 'Start the conversation',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.currentUserIsSeller
                  ? 'Their first message will appear here.'
                  : (hasProduct
                      ? 'Ask the seller anything about this product —\nshade, stock, shipping, and more.'
                      : 'Say hi to the seller!'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            if (!widget.currentUserIsSeller && hasProduct) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _quickReply('Is this still available?'),
                  _quickReply('What shades do you have?'),
                  _quickReply('How long is shipping?'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickReply(String text) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _input.text = text;
        _send();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPink.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _kPink,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isMine;
  final bool isBot;
  final String? timestamp;
  final Map<String, dynamic>? metadata;
  final ValueChanged<String>? onSuggestionTap;

  const _MessageBubble({
    required this.text,
    required this.isMine,
    required this.isBot,
    this.imageUrl,
    this.timestamp,
    this.metadata,
    this.onSuggestionTap,
  });

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final fg = isBot
        ? Colors.deepPurple.shade700
        : (isMine ? Colors.white : const Color(0xFF1A1D2E));

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMine && !isBot
                    ? const LinearGradient(
                        colors: [_kPink, _kPinkDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isBot
                    ? const Color(0xFFEDE7F6)
                    : (isMine ? null : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: isMine
                    ? [
                        BoxShadow(
                          color: _kPink.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              size: 13, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          Text(
                            'Beauty AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: text.isNotEmpty ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => _openFullImage(context, imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 240,
                              maxHeight: 320,
                            ),
                            child: Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (c, child, p) => p == null
                                  ? child
                                  : Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                      ),
                                    ),
                              errorBuilder: (_, __, ___) => Container(
                                width: 200,
                                height: 120,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style:
                          TextStyle(color: fg, fontSize: 14, height: 1.35),
                    ),
                ],
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (isBot && metadata != null) _buildBotExtras(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBotExtras(BuildContext context) {
    final children = <Widget>[];
    final pc = metadata!['product_card'];
    if (pc is Map) {
      final price = (pc['price'] as num?)?.toDouble() ?? 0;
      final cur = (pc['currency'] ?? 'PHP').toString();
      final stock = (pc['stock'] as num?)?.toInt() ?? 0;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kPink.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: _kPink.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$cur ${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _kPinkDeep,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stock > 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stock > 0 ? '$stock in stock' : 'Sold out',
                  style: TextStyle(
                    color: stock > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onSuggestionTap?.call(
                    'Tell me more about ${pc['name'] ?? 'this product'}'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPink, _kPinkDeep],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }
    final sugs = metadata!['suggestions'];
    if (sugs is List && sugs.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sugs
              .whereType<String>()
              .take(6)
              .map((s) => InkWell(
                    onTap: () => onSuggestionTap?.call(s),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _kPink.withOpacity(0.45)),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: _kPinkDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool uploading;
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: uploading ? null : onAttach,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kPink),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined,
                          color: _kPink, size: 26),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF4F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPink, _kPinkDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kPink.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: const Padding(
                    padding: EdgeInsets.all(13),
                    child: Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openFullImage(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _FullImageView(url: url),
      fullscreenDialog: true,
    ),
  );
}

class _FullImageView extends StatelessWidget {
  final String url;
  const _FullImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 64),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            Widget dot(double offset) {
              final t = ((_ctrl.value + offset) % 1.0);
              final scale = 0.6 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.6;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [dot(0.0), dot(0.2), dot(0.4)],
            );
          },
        ),
      ),
    );
  }
}
