// lib/services/chat_service.dart
//
// Chat between buyer and seller backed by Supabase tables
// (chat_conversations, chat_messages). Includes a smart, context-aware
// assistant that pulls live product data from Supabase to answer buyer
// questions without relying on an external LLM.

import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Resolves the default marketplace seller (single-seller setup).
  /// Picks the first business / client account, preferring those that have
  /// products listed.
  Future<String?> getDefaultSellerId() async {
    try {
      // Try a client/business account that owns at least one product first.
      final productRow = await _client
          .from('products')
          .select('business_id')
          .not('business_id', 'is', null)
          .limit(1)
          .maybeSingle();
      if (productRow != null && productRow['business_id'] != null) {
        return productRow['business_id'].toString();
      }
    } catch (_) {}
    try {
      final acc = await _client
          .from('accounts')
          .select('id')
          .or('role.eq.client,account_type.eq.business')
          .limit(1)
          .maybeSingle();
      if (acc != null && acc['id'] != null) return acc['id'].toString();
    } catch (_) {}
    return null;
  }

  /// Returns existing conversation between current user (buyer) and [sellerId],
  /// creating one if needed.
  Future<Map<String, dynamic>?> getOrCreateConversation({
    required String sellerId,
    String? productId,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final existing = await _client
          .from('chat_conversations')
          .select('*')
          .eq('buyer_id', uid)
          .eq('seller_id', sellerId)
          .maybeSingle();
      if (existing != null) return Map<String, dynamic>.from(existing);

      final inserted = await _client
          .from('chat_conversations')
          .insert({
            'buyer_id': uid,
            'seller_id': sellerId,
            'product_id': productId,
          })
          .select()
          .single();
      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listConversationsForBuyer() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('chat_conversations')
          .select('*, accounts!chat_conversations_seller_id_fkey(full_name, business_name, avatar_url)')
          .eq('buyer_id', uid)
          .order('last_message_at', ascending: false, nullsFirst: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      // Fall back without join
      try {
        final rows = await _client
            .from('chat_conversations')
            .select('*')
            .eq('buyer_id', uid)
            .order('updated_at', ascending: false);
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> listConversationsForSeller() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('chat_conversations')
          .select('*, accounts!chat_conversations_buyer_id_fkey(full_name, avatar_url)')
          .eq('seller_id', uid)
          .order('last_message_at', ascending: false, nullsFirst: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from('chat_conversations')
            .select('*')
            .eq('seller_id', uid)
            .order('updated_at', ascending: false);
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadMessages(String conversationId) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Streams new messages for a conversation in realtime.
  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
    required String role, // 'buyer' | 'seller' | 'bot'
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    final trimmed = body.trim();
    if (trimmed.isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;
    final preview = trimmed.isNotEmpty
        ? trimmed
        : (imageUrl != null ? '📷 Photo' : '');
    try {
      await _client.from('chat_messages').insert({
        'conversation_id': conversationId,
        'sender_id': role == 'bot' ? null : uid,
        'sender_role': role,
        'body': trimmed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      });
      await _client.from('chat_conversations').update({
        'last_message': preview,
        'last_message_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (_) {}
  }

  /// Sends a structured bot reply (text + optional suggestion chips +
  /// optional product cards). Each product card becomes its own image
  /// message so it renders as a tappable mini product card in the chat.
  Future<void> sendBotReply({
    required String conversationId,
    required BotReply reply,
  }) async {
    if (reply.text.trim().isNotEmpty || reply.suggestions.isNotEmpty) {
      await sendMessage(
        conversationId: conversationId,
        body: reply.text,
        role: 'bot',
        metadata: reply.suggestions.isEmpty
            ? null
            : {'suggestions': reply.suggestions},
      );
    }
    for (final card in reply.productCards) {
      await sendMessage(
        conversationId: conversationId,
        body: card.caption,
        role: 'bot',
        imageUrl: card.imageUrl,
        metadata: {
          'product_card': {
            'id': card.id,
            'name': card.name,
            'price': card.price,
            'currency': card.currency,
            'stock': card.stock,
          }
        },
      );
    }
  }

  /// Uploads a local image file to the `chat-images` Supabase storage bucket
  /// under `<conversationId>/<timestamp>.<ext>` and returns its public URL,
  /// or null on failure.
  Future<String?> uploadChatImage({
    required String conversationId,
    required File file,
  }) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final safeExt = ext.length <= 5 ? ext : 'jpg';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '$conversationId/$ts.$safeExt';
      await _client.storage.from('chat-images').upload(
            path,
            file,
            fileOptions: FileOptions(
              contentType: 'image/$safeExt',
              upsert: false,
            ),
          );
      return _client.storage.from('chat-images').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Generates a smart, context-aware reply for [userMessage]. Returns a
  /// rich [BotReply] containing the text, contextual suggestion chips, and
  /// optional product cards (rendered inline as image bubbles).
  Future<BotReply> botReply(
    String userMessage, {
    String? conversationId,
  }) async {
    final raw = userMessage.trim();
    if (raw.isEmpty) return const BotReply(text: '');
    final m = raw.toLowerCase();

    // ── Load conversational context ──────────────────────────────────────
    final ctx = await _loadChatContext(conversationId);
    final firstName = ctx.buyerFirstName;
    final hello = firstName != null ? 'Hi $firstName' : 'Hi there';

    // ── Sentiment / complaint escalation ─────────────────────────────────
    if (_isComplaint(m)) {
      return BotReply(
        text:
            "I'm really sorry you're dealing with that 💔 I've flagged this conversation for the seller — they'll get back to you ASAP. In the meantime, can you share your order number and a photo so we can fix it faster?",
        suggestions: const [
          'My order is damaged',
          'I want a refund',
          'Wrong item received',
          'Talk to a human',
        ],
      );
    }

    // ── Order tracking / "where is my order" ─────────────────────────────
    if (_matchesAny(m, [
      'where is my order', "where's my order", 'order status',
      'track order', 'tracking', 'my order', 'order update',
      'nasaan order', 'nasaan na', 'kelan dating', 'kailan dating',
    ])) {
      final orders = await _recentOrders();
      if (orders.isNotEmpty) {
        final lines = orders.take(3).map((o) {
          final id = (o['id']?.toString() ?? '').substring(0, 8);
          final st = (o['status'] ?? 'processing').toString();
          final tot = (o['total'] as num?)?.toStringAsFixed(2) ?? '—';
          return '• #$id — *$st* (₱$tot)';
        }).join('\n');
        return BotReply(
          text: "Here are your recent orders 📦:\n$lines\n\nTap *Profile → My Orders* for full details and tracking.",
          suggestions: const [
            'How long is shipping?',
            'Cancel my order',
            'Talk to seller',
          ],
        );
      }
      return const BotReply(
        text:
            "I couldn't find any orders on your account yet 🤔 Once you check out, you'll be able to track them from here.",
        suggestions: ['How to order', 'Show me bestsellers', 'Talk to seller'],
      );
    }

    // ── Multi-turn yes/no follow-up ──────────────────────────────────────
    if (_isAffirmative(m) && ctx.lastBotMessage != null) {
      final lb = ctx.lastBotMessage!.toLowerCase();
      if (lb.contains('add it to cart') || lb.contains('add to cart')) {
        return const BotReply(
          text:
              "Great! 🛒 Open the marketplace, tap the product, then *Add to Cart*. From the cart icon at the top, you can checkout and pay via COD, GCash, or card.",
          suggestions: ['How to pay', 'Shipping fee', 'Track my order'],
        );
      }
      if (lb.contains('want a recommendation') ||
          lb.contains('shall i suggest') ||
          lb.contains('want me to suggest')) {
        final recs = await _personalizedRecommendations(ctx);
        return BotReply(
          text: recs.isNotEmpty
              ? "Here are picks I think you'll love 💖"
              : "Hmm, I couldn't find good matches right now. Try browsing the marketplace!",
          productCards: recs.take(3).map(_toProductCard).toList(),
          suggestions: const [
            'Cheaper options',
            'Best for my undertone',
            'Show bestsellers',
          ],
        );
      }
    }

    // ── Greetings ────────────────────────────────────────────────────────
    if (_matchesAny(m, [
      'hi', 'hello', 'hey ', 'hey,', 'yo ', 'hiya', 'kumusta', 'kamusta',
      'good morning', 'good afternoon', 'good evening', 'good day',
    ])) {
      final productHint = ctx.product != null
          ? " I see you're asking about *${ctx.product!['name']}*."
          : "";
      return BotReply(
        text: "$hello! 👋 I'm Fashion21's beauty assistant.$productHint What can I help with?",
        suggestions: ctx.product != null
            ? const [
                'Is this still available?',
                'Will it match my undertone?',
                'How long is shipping?',
                'Any cheaper options?',
              ]
            : const [
                'Show me bestsellers',
                'Recommend by undertone',
                'How to order',
                'Track my order',
              ],
      );
    }

    // ── Thanks / goodbye ─────────────────────────────────────────────────
    if (_matchesAny(m, ['thank', 'thanks', 'thx', ' ty ', ' ty', 'salamat'])) {
      return BotReply(
        text:
            "You're welcome${firstName != null ? ', $firstName' : ''}! 💖 Tell me anytime if you need shade advice or product picks.",
        suggestions: const ['Recommend products', 'Track my order'],
      );
    }
    if (_matchesAny(m, ['bye', 'goodbye', 'see you', 'paalam'])) {
      return const BotReply(text: "Bye! Come back anytime — Fashion21 is open 24/7. ✨");
    }

    // ── Talk to a human / seller ─────────────────────────────────────────
    if (_matchesAny(m, [
      'talk to a human', 'talk to seller', 'human agent', 'real person',
      'live agent', 'customer service', 'csr',
    ])) {
      return const BotReply(
        text:
            "I've pinged the seller for you 🔔 They'll jump in as soon as they're online. While you wait, I can still help with prices, stock, or shade advice.",
        suggestions: ['Show bestsellers', 'Track my order', 'How to pay'],
      );
    }

    // ── Help / capabilities ──────────────────────────────────────────────
    if (_matchesAny(m, ['help', 'what can you do', 'menu', 'options'])) {
      return const BotReply(
        text:
            "I can help you with:\n• 💄 Finding products (e.g. \"red matte lipstick\")\n• 🎨 Shade matching for your undertone & skin type\n• 💰 Live prices and stock\n• 🚚 Shipping & delivery times\n• 💳 Payment (COD, GCash, PayMongo)\n• ↩️ Returns and refunds\n• 📦 Tracking your orders",
        suggestions: [
          'Show bestsellers',
          'Track my order',
          'How to pay',
          'Shade match',
        ],
      );
    }

    // ── Order / how to buy ───────────────────────────────────────────────
    if (_matchesAny(m, [
      'how to order', 'how to buy', 'how do i order', 'how do i buy',
      'where to buy', 'place order', 'checkout', 'paano umorder',
    ])) {
      return const BotReply(
        text:
            "Easy! 🛒\n1. Tap any product to view details\n2. Pick a variation (if any) and tap *Add to Cart*\n3. Open the cart icon at the top right\n4. Tap *Proceed to Checkout*, fill in your address, and pay",
        suggestions: ['Payment methods', 'Shipping fee', 'Show bestsellers'],
      );
    }

    // ── Payment ──────────────────────────────────────────────────────────
    if (_matchesAny(m, [
      'cod', 'cash on delivery', 'cash-on-delivery',
      'gcash', 'paymongo', 'paymaya', 'payment', 'pay ', 'how to pay',
      'credit card', 'debit card', 'bayad',
    ])) {
      return const BotReply(
        text:
            "We accept 💳:\n• Cash on Delivery (COD)\n• GCash\n• Credit / Debit cards via PayMongo\nYou can pick your preferred method at checkout.",
        suggestions: ['Shipping fee', 'How to order', 'Track my order'],
      );
    }

    // ── Shipping ─────────────────────────────────────────────────────────
    if (_matchesAny(m, [
      'ship', 'deliver', 'arrive', 'arrival', 'how long',
      'kelan', 'kailan darating', 'lbc', 'j&t', 'courier', 'tracking',
    ])) {
      return const BotReply(
        text:
            "🚚 Delivery times:\n• Metro Manila: 2–4 business days\n• Luzon: 3–5 business days\n• Visayas / Mindanao: 5–7 business days\nFree shipping on orders over ₱1,500. A tracking link is emailed once dispatched.",
        suggestions: ['Track my order', 'Payment methods', 'Returns'],
      );
    }

    // ── Returns ──────────────────────────────────────────────────────────
    if (_matchesAny(m, [
      'return', 'refund', 'exchange', 'wrong item', 'damaged', 'defect',
    ])) {
      return const BotReply(
        text:
            "↩️ You can request a return within 7 days of delivery if the item is unopened or arrived damaged. Reply here with your order number and a photo and we'll sort it out.",
        suggestions: ['Talk to seller', 'Track my order'],
      );
    }

    // ── Authenticity ─────────────────────────────────────────────────────
    if (_matchesAny(m, ['authentic', 'original', 'legit', 'fake', 'real'])) {
      return const BotReply(
        text:
            "✅ Every product on Fashion21 Marketplace is 100% authentic and sourced directly from official suppliers.",
        suggestions: ['Show bestsellers', 'Recommend for me'],
      );
    }

    // ── Discount / promo ─────────────────────────────────────────────────
    if (_matchesAny(m, [
      'discount', 'promo', 'coupon', 'voucher', 'sale ', 'mura', 'deals',
    ])) {
      return const BotReply(
        text:
            "🎉 We run promos regularly. Free shipping kicks in automatically over ₱1,500, and bundle deals appear on the product page when active.",
        suggestions: ['Cheaper options', 'Show bestsellers'],
      );
    }

    // ── Application / how-to-use tutorials ───────────────────────────────
    final tip = _applicationTip(m, ctx.product);
    if (tip != null) {
      return BotReply(
        text: tip,
        suggestions: const [
          'Will it suit my undertone?',
          'Cheaper options',
          'Add to cart',
        ],
      );
    }

    // ── Shade / undertone / skin-type matching ───────────────────────────
    if (_matchesAny(m, [
      'shade', 'undertone', 'match', 'fit me', 'fit my', 'matches my',
      'will it suit', 'suit me', 'good for my skin', 'good for me',
      'will this work', 'compatible',
    ])) {
      return BotReply(
        text: _shadeMatchReply(ctx),
        suggestions: const [
          'Show me alternatives',
          "What's my undertone?",
          'Add to cart',
        ],
      );
    }

    // ── How to find your undertone / skin type ───────────────────────────
    if (_matchesAny(m, [
      "what's my undertone", 'what is my undertone', 'find my undertone',
      'know my undertone', "don't know my undertone",
    ])) {
      return const BotReply(
        text:
            "Quick test 🌟: Look at the veins on your wrist in natural light.\n• Greenish veins → *warm* undertone\n• Bluish/purple → *cool* undertone\n• A mix → *neutral* undertone\nOr run our in-app skin scan from the Home tab — it detects your undertone and skin type for you!",
        suggestions: ['Run skin scan', 'Recommend for me'],
      );
    }
    if (_matchesAny(m, [
      'find my skin type', 'know my skin type', 'what skin type',
      "what's my skin type",
    ])) {
      return const BotReply(
        text:
            "Try the in-app skin scan on the Home tab — it analyzes oiliness, dryness and texture, and tags your skin type. ✨",
        suggestions: ['Run skin scan', 'Recommend for me'],
      );
    }

    // ── Cheaper / budget alternatives ────────────────────────────────────
    if (_matchesAny(m, [
      'cheaper', 'mas mura', 'budget', 'affordable', 'lower price',
      'something less', 'mas tipid',
    ])) {
      final alt = await _findCheaperAlternatives(ctx);
      if (alt.isNotEmpty) {
        final base = ctx.product?['name'];
        final intro = base != null
            ? "Here are more budget-friendly options similar to *$base* 💸"
            : "Here are some affordable picks 💸";
        return BotReply(
          text: intro,
          productCards: alt.take(3).map(_toProductCard).toList(),
          suggestions: const ['Best for me', 'Compare top 2', 'Show bestsellers'],
        );
      }
    }

    // ── Compare two products ─────────────────────────────────────────────
    if (_matchesAny(m, [' vs ', 'compare', 'difference between'])) {
      final compare = await _maybeComparison(m);
      if (compare != null) {
        return BotReply(
          text: compare,
          suggestions: const ['Best for me', 'Cheaper options'],
        );
      }
    }

    // ── Price / stock / product lookup (live Supabase) ───────────────────
    final wantsPrice = _matchesAny(m, [
      'price', 'how much', 'magkano', 'cost', 'presyo',
    ]);
    final wantsStock = _matchesAny(m, [
      'stock', 'available', 'availability', 'in stock', 'sold out',
      'meron pa', 'meron ba', 'still available',
    ]);
    final wantsRecommendation = _matchesAny(m, [
      'recommend', 'suggest', 'best', 'top ', 'popular', 'bestseller',
      'show me', 'looking for', 'do you have', 'do you sell',
      'meron ba kayo', 'mayroon ba', 'any ', 'anything',
    ]);

    if ((wantsPrice || wantsStock) &&
        ctx.product != null &&
        !_messageMentionsAnyProduct(m)) {
      final p = ctx.product!;
      return BotReply(
        text: _formatProductReply(
          [p],
          wantsPrice: wantsPrice,
          wantsStock: wantsStock,
        ),
        suggestions: const [
          'Add to cart',
          'Will it match my undertone?',
          'Cheaper options',
          'Shipping fee',
        ],
      );
    }

    if (wantsPrice || wantsStock || wantsRecommendation) {
      final products = await _searchProducts(m);
      if (products.isNotEmpty) {
        if (products.length == 1) {
          return BotReply(
            text: _formatProductReply(
              products,
              wantsPrice: wantsPrice,
              wantsStock: wantsStock,
            ),
            productCards: [_toProductCard(products.first)],
            suggestions: const [
              'Add to cart',
              'Cheaper options',
              'Will it match me?',
            ],
          );
        }
        return BotReply(
          text: "Found a few that match 💄",
          productCards: products.take(3).map(_toProductCard).toList(),
          suggestions: const [
            'Cheaper options',
            'Best for me',
            'Compare top 2',
          ],
        );
      }
    }

    // ── Category keyword fallback ────────────────────────────────────────
    final category = _detectCategory(m);
    if (category != null) {
      final products = await _searchProductsByCategory(category);
      if (products.isNotEmpty) {
        return BotReply(
          text: "Here's what we have in $category 💄",
          productCards: products.take(3).map(_toProductCard).toList(),
          suggestions: const ['Cheaper options', 'Best for me'],
        );
      }
      return BotReply(
        text:
            "We don't have any $category in stock right now. Browse the marketplace for similar items, or check back soon!",
        suggestions: const ['Show bestsellers', 'Recommend for me'],
      );
    }

    // ── Personalized recommendation fallback ────────────────────────────
    if (wantsRecommendation) {
      final picks = await _personalizedRecommendations(ctx);
      if (picks.isNotEmpty) {
        return BotReply(
          text: "Based on your beauty profile, you might love these 💖",
          productCards: picks.take(3).map(_toProductCard).toList(),
          suggestions: const ['Cheaper options', 'Compare top 2'],
        );
      }
    }

    // ── Default fallback ────────────────────────────────────────────────
    return BotReply(
      text:
          "Got it — I've passed your message to the seller. While you wait, what would you like to do?",
      suggestions: const [
        'Show bestsellers',
        'Recommend for my undertone',
        'Track my order',
        'How to pay',
      ],
    );
  }

  /// Back-compat shim — returns just the reply text.
  Future<String?> botReplyFor(
    String userMessage, {
    String? conversationId,
  }) async {
    final r = await botReply(userMessage, conversationId: conversationId);
    if (r.text.trim().isEmpty) return null;
    return r.text;
  }

  // ───── Helpers ─────

  bool _matchesAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }

  static const Map<String, List<String>> _categoryKeywords = {
    'Lipstick': ['lipstick', 'lip tint', 'lip gloss', 'lippie', 'labi'],
    'Blush': ['blush', 'blusher', 'pampula ng pisngi'],
    'Foundation': ['foundation', 'base', 'fdn'],
    'Concealer': ['concealer', 'pantakip'],
    'Eyeshadow': ['eyeshadow', 'eye shadow', 'palette'],
    'Eyeliner': ['eyeliner', 'liner'],
    'Mascara': ['mascara', 'pilik', 'lashes'],
    'Tools': ['brush', 'sponge', 'beauty blender', 'tool'],
  };

  String? _detectCategory(String text) {
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (text.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  /// Searches the products table using the most distinctive words in [query].
  Future<List<Map<String, dynamic>>> _searchProducts(String query) async {
    // Strip common stop words / question words.
    const stop = {
      'a', 'an', 'the', 'is', 'are', 'do', 'you', 'have', 'me',
      'show', 'price', 'stock', 'available', 'how', 'much', 'cost',
      'i', 'want', 'looking', 'for', 'and', 'or', 'with', 'in', 'on',
      'sell', 'recommend', 'suggest', 'best', 'top', 'popular',
      'magkano', 'meron', 'mayroon', 'ba', 'kayo', 'ng',
    };
    final words = query
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stop.contains(w))
        .toList();
    if (words.isEmpty) return [];
    try {
      final orFilter = words.map((w) => 'name.ilike.%$w%').join(',');
      final rows = await _client
          .from('products')
          .select('id, name, price, stock_quantity, category, image_url, currency')
          .or(orFilter)
          .eq('is_active', true)
          .limit(5);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchProductsByCategory(
      String category) async {
    try {
      final rows = await _client
          .from('products')
          .select('id, name, price, stock_quantity, category, image_url, currency')
          .eq('category', category)
          .eq('is_active', true)
          .order('stock_quantity', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  String _formatProductReply(
    List<Map<String, dynamic>> products, {
    required bool wantsPrice,
    required bool wantsStock,
  }) {
    if (products.length == 1) {
      final p = products.first;
      final name = p['name'] ?? 'this product';
      final price = (p['price'] as num?)?.toStringAsFixed(2) ?? '—';
      final stock = (p['stock_quantity'] as int?) ?? 0;
      final stockText =
          stock > 0 ? '$stock left in stock' : 'currently out of stock';
      if (wantsPrice && wantsStock) {
        return "$name is ₱$price and $stockText. Want me to help you add it to cart?";
      }
      if (wantsPrice) {
        return "$name is ₱$price 💖 ($stockText).";
      }
      if (wantsStock) {
        return "$name is $stockText. Current price: ₱$price.";
      }
      return "Found it — $name (₱$price, $stockText). Tap it on the marketplace screen to see more.";
    }
    return "I found a few that match 💄:\n${_listProducts(products)}\n\nTap any product on the marketplace to see full details.";
  }

  String _listProducts(List<Map<String, dynamic>> products) {
    return products.map((p) {
      final name = p['name'] ?? 'Product';
      final price = (p['price'] as num?)?.toStringAsFixed(2) ?? '—';
      final stock = (p['stock_quantity'] as int?) ?? 0;
      final tag = stock > 0 ? '' : ' (sold out)';
      return '• $name — ₱$price$tag';
    }).join('\n');
  }

  // ───── Conversational context ─────

  Future<_ChatContext> _loadChatContext(String? conversationId) async {
    if (conversationId == null) return const _ChatContext();
    String? buyerId;
    Map<String, dynamic>? product;
    Map<String, dynamic>? buyer;
    String? lastBot;

    try {
      final conv = await _client
          .from('chat_conversations')
          .select('buyer_id, product_id')
          .eq('id', conversationId)
          .maybeSingle();
      if (conv != null) {
        buyerId = conv['buyer_id']?.toString();
        final pid = conv['product_id']?.toString();
        if (pid != null && pid.isNotEmpty) {
          try {
            final p = await _client
                .from('products')
                .select(
                    'id, name, price, stock_quantity, category, undertone, compatible_skin_type, image_url, currency')
                .eq('id', pid)
                .maybeSingle();
            if (p != null) product = Map<String, dynamic>.from(p);
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (buyerId != null) {
      try {
        final b = await _client
            .from('accounts')
            .select('id, full_name, undertone, skin_type')
            .eq('id', buyerId)
            .maybeSingle();
        if (b != null) buyer = Map<String, dynamic>.from(b);
      } catch (_) {}
    }

    try {
      final rows = await _client
          .from('chat_messages')
          .select('body, sender_role, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(8);
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        if (r['sender_role'] == 'bot') {
          lastBot = r['body']?.toString();
          break;
        }
      }
    } catch (_) {}

    return _ChatContext(
      product: product,
      buyer: buyer,
      lastBotMessage: lastBot,
    );
  }

  bool _isAffirmative(String m) {
    return _matchesAny(m, [
      'yes', 'yeah', 'yep', 'sure', 'ok', 'okay', 'please do',
      'go ahead', 'sige', 'oo', 'opo',
    ]);
  }

  bool _messageMentionsAnyProduct(String m) {
    // If the buyer uses a referential pronoun ("this", "it", "that one",
    // "this product", "the item", "ito", "yan"), they're talking about the
    // current/linked product — NOT naming a different one.
    if (RegExp(
      r'\b(this|that|it|this one|that one|this product|the product|the item|ito|yan|yun)\b',
    ).hasMatch(m)) {
      return false;
    }
    // Otherwise, look for any meaningful noun-like word that isn't a generic
    // stop word.
    const stop = {
      'the', 'this', 'that', 'a', 'an', 'how', 'much', 'is', 'are', 'do',
      'does', 'did', 'has', 'have', 'had', 'will', 'would', 'can', 'could',
      'should', 'may', 'might', 'it', 'its', 'one', 'still', 'item', 'thing',
      'price', 'magkano', 'stock', 'available', 'availability',
      'pa', 'na', 'po', 'ba', 'sold', 'out', 'left', 'meron', 'mayroon',
      'kayo', 'mo', 'ko', 'nyo', 'ito', 'yan', 'yun',
    };
    final words = m
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stop.contains(w))
        .toList();
    return words.isNotEmpty;
  }

  String _shadeMatchReply(_ChatContext ctx) {
    final p = ctx.product;
    final buyerUndertone = ctx.buyer?['undertone']?.toString().toLowerCase();
    final buyerSkinType = ctx.buyer?['skin_type']?.toString().toLowerCase();

    if (p == null) {
      if (buyerUndertone == null && buyerSkinType == null) {
        return "I can match shades for you 🎨 — but I need your undertone and skin type first. Run the in-app skin scan from the Home tab, or tell me (e.g. \"warm, oily\").";
      }
      return "Tell me which product you're eyeing and I'll check if it matches your ${buyerUndertone ?? 'undertone'} undertone${buyerSkinType != null ? ' and $buyerSkinType skin' : ''}.";
    }

    final productUndertone =
        p['undertone']?.toString().toLowerCase();
    final productSkin =
        p['compatible_skin_type']?.toString().toLowerCase();
    final name = p['name'] ?? 'this product';

    if (buyerUndertone == null && buyerSkinType == null) {
      return "*$name* is best for ${productUndertone ?? 'all'} undertones${productSkin != null ? ' and $productSkin skin' : ''}. Run the in-app skin scan and I can tell you exactly how well it matches you.";
    }

    final undertoneOk = productUndertone == null ||
        productUndertone == 'all' ||
        productUndertone == buyerUndertone ||
        buyerUndertone == null;
    final skinOk = productSkin == null ||
        productSkin == 'all' ||
        productSkin.contains(buyerSkinType ?? '') ||
        buyerSkinType == null;

    final you =
        "your ${buyerUndertone ?? '—'} undertone${buyerSkinType != null ? ' and $buyerSkinType skin' : ''}";
    if (undertoneOk && skinOk) {
      return "✨ Great match! *$name* suits $you really well.";
    }
    if (!undertoneOk && skinOk) {
      return "Heads up — *$name* is tuned for ${productUndertone ?? 'a different'} undertones, so it may pull a bit off on $you. Want me to suggest something that matches your undertone better?";
    }
    if (undertoneOk && !skinOk) {
      return "*$name* is formulated for ${productSkin ?? 'a different'} skin, so it may not feel ideal on $you. Shall I suggest a better fit?";
    }
    return "*$name* is geared toward ${productUndertone ?? '?'} undertones and ${productSkin ?? '?'} skin — not the closest match for $you. Want a recommendation that matches?";
  }

  String? _applicationTip(String m, Map<String, dynamic>? product) {
    final cat = product?['category']?.toString().toLowerCase();
    bool ask(List<String> kws) => _matchesAny(m, kws);

    if (ask(['how to apply', 'how do i apply', 'how do i use', 'how to use', 'paano gamitin'])) {
      if (cat == 'foundation' || ask(['foundation'])) {
        return "💡 Foundation tip: Start with a pea-sized dot on the center of your face, then blend outward with a damp sponge in pressing motions (not wiping). Build up in thin layers — less is more.";
      }
      if (cat == 'lipstick' || ask(['lipstick', 'lip tint'])) {
        return "💡 Lipstick tip: Exfoliate lips first, line with a matching pencil, then apply from the center outward. Blot once with tissue and reapply for longer wear.";
      }
      if (cat == 'concealer' || ask(['concealer'])) {
        return "💡 Concealer tip: Dab (don't drag) under the eyes in a triangle shape with the point toward the cheek, then blend gently with a damp sponge.";
      }
      if (cat == 'eyeshadow' || ask(['eyeshadow', 'palette'])) {
        return "💡 Eyeshadow tip: Sweep a neutral shade across the lid as a base, deepen the outer corner with a darker shade, then highlight the inner corner and brow bone.";
      }
      if (cat == 'blush' || ask(['blush'])) {
        return "💡 Blush tip: Smile, find the apples of your cheeks, and sweep upward toward your temples for a lifted look. Cream blushes go on bare skin; powder goes after foundation.";
      }
      if (cat == 'mascara' || ask(['mascara', 'lashes'])) {
        return "💡 Mascara tip: Wiggle the wand at the base of your lashes, then sweep up in a Z-motion. Two thin coats beats one heavy coat for definition without clumps.";
      }
      return "💡 Tip: Always start with clean, moisturized skin and work in thin layers — that's the secret to a natural finish.";
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _findCheaperAlternatives(
      _ChatContext ctx) async {
    final p = ctx.product;
    try {
      if (p != null) {
        final price = (p['price'] as num?)?.toDouble();
        final cat = p['category']?.toString();
        if (cat != null && price != null) {
          final rows = await _client
              .from('products')
              .select('id, name, price, stock_quantity, category, image_url, currency')
              .eq('category', cat)
              .lt('price', price)
              .eq('is_active', true)
              .order('price', ascending: true)
              .limit(5);
          return List<Map<String, dynamic>>.from(rows);
        }
      }
      // Generic cheap picks
      final rows = await _client
          .from('products')
          .select('id, name, price, stock_quantity, category, image_url, currency')
          .eq('is_active', true)
          .order('price', ascending: true)
          .limit(5);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  Future<String?> _maybeComparison(String m) async {
    // Try splitting on "vs" or "or"
    final parts = m
        .split(RegExp(r'\s+(?:vs|or|versus)\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2) return null;
    try {
      final a = await _searchProducts(parts[0]);
      final b = await _searchProducts(parts[1]);
      if (a.isEmpty || b.isEmpty) return null;
      final pa = a.first;
      final pb = b.first;
      final pap = (pa['price'] as num?)?.toStringAsFixed(2) ?? '—';
      final pbp = (pb['price'] as num?)?.toStringAsFixed(2) ?? '—';
      final winner = (pa['price'] as num? ?? 0) <
              (pb['price'] as num? ?? 0)
          ? pa['name']
          : pb['name'];
      return "Comparison 🆚\n• ${pa['name']} — ₱$pap (${pa['category'] ?? 'product'})\n• ${pb['name']} — ₱$pbp (${pb['category'] ?? 'product'})\n\n*$winner* is the more budget-friendly pick. Want me to recommend based on your skin type?";
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _personalizedRecommendations(
      _ChatContext ctx) async {
    final undertone = ctx.buyer?['undertone']?.toString();
    final skinType = ctx.buyer?['skin_type']?.toString();
    try {
      var query = _client
          .from('products')
          .select('id, name, price, stock_quantity, category, undertone, compatible_skin_type, image_url, currency')
          .eq('is_active', true);
      final rows = await query.limit(50);
      final list = List<Map<String, dynamic>>.from(rows);
      // Score by match
      list.sort((a, b) {
        int score(Map<String, dynamic> p) {
          var s = 0;
          final pu = p['undertone']?.toString().toLowerCase();
          final ps = p['compatible_skin_type']?.toString().toLowerCase();
          if (undertone != null &&
              pu != null &&
              (pu == undertone.toLowerCase() || pu == 'all')) s += 2;
          if (skinType != null &&
              ps != null &&
              (ps.contains(skinType.toLowerCase()) || ps == 'all')) s += 2;
          if ((p['stock_quantity'] as int? ?? 0) > 0) s += 1;
          return s;
        }
        return score(b).compareTo(score(a));
      });
      return list.take(5).toList();
    } catch (_) {
      return [];
    }
  }

  // ───── Sentiment / order helpers ─────

  bool _isComplaint(String m) {
    return _matchesAny(m, [
      'angry', 'mad', 'furious', 'frustrated', 'disappointed',
      'scam', 'fraud', 'rip off', 'rip-off', 'cheated',
      'terrible', 'horrible', 'worst', 'awful', 'sucks',
      'damaged', 'broken', 'leaking', 'expired', 'fake',
      'never received', "haven't received", 'not yet received',
      'nawawala', 'sira', 'panloko', 'walang dating',
      '!!!',
    ]);
  }

  Future<List<Map<String, dynamic>>> _recentOrders() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('orders')
          .select('id, status, total, created_at')
          .eq('buyer_id', uid)
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  BotProductCard _toProductCard(Map<String, dynamic> p) {
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final stock = (p['stock_quantity'] as int?) ?? 0;
    final stockText = stock > 0 ? '$stock in stock' : 'sold out';
    return BotProductCard(
      id: p['id']?.toString() ?? '',
      name: p['name']?.toString() ?? 'Product',
      price: price,
      currency: p['currency']?.toString() ?? 'PHP',
      imageUrl: p['image_url']?.toString() ?? '',
      stock: stock,
      caption: '${p['name'] ?? 'Product'} — ₱${price.toStringAsFixed(2)} • $stockText',
    );
  }
}

/// Structured AI reply: a text bubble plus optional follow-up suggestion
/// chips and inline product cards.
class BotReply {
  final String text;
  final List<String> suggestions;
  final List<BotProductCard> productCards;
  const BotReply({
    required this.text,
    this.suggestions = const [],
    this.productCards = const [],
  });
}

class BotProductCard {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String imageUrl;
  final int stock;
  final String caption;
  const BotProductCard({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.imageUrl,
    required this.stock,
    required this.caption,
  });
}

class _ChatContext {
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? buyer;
  final String? lastBotMessage;
  const _ChatContext({this.product, this.buyer, this.lastBotMessage});

  String? get buyerFirstName {
    final full = buyer?['full_name']?.toString().trim();
    if (full == null || full.isEmpty) return null;
    final first = full.split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : first;
  }
}

