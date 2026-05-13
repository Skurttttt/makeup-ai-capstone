// lib/services/chat_service.dart
//
// Chat between buyer and seller backed by Supabase tables
// (chat_conversations, chat_messages). Includes a smart, context-aware
// assistant that pulls live product data from Supabase to answer buyer
// questions without relying on an external LLM.

import 'dart:async';
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
  }) async {
    final uid = _uid;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    try {
      await _client.from('chat_messages').insert({
        'conversation_id': conversationId,
        'sender_id': role == 'bot' ? null : uid,
        'sender_role': role,
        'body': trimmed,
      });
      await _client.from('chat_conversations').update({
        'last_message': trimmed,
        'last_message_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (_) {}
  }

  /// Generates a smart, context-aware reply for [userMessage]. Looks up live
  /// product data from Supabase when the buyer asks about price, stock,
  /// availability, categories, or specific items. Returns null if the
  /// message is empty.
  Future<String?> botReplyFor(String userMessage) async {
    final raw = userMessage.trim();
    if (raw.isEmpty) return null;
    final m = raw.toLowerCase();

    // --- Greetings ---
    if (_matchesAny(m, [
      'hi', 'hello', 'hey', 'yo', 'hiya', 'kumusta', 'kamusta',
      'good morning', 'good afternoon', 'good evening', 'good day',
    ])) {
      return "Hi there! 👋 I'm Fashion21's AI assistant. The seller will reply once they're online — meanwhile I can help with prices, stock, shipping, payment, returns, or product recommendations. What are you looking for?";
    }

    // --- Thanks / goodbye ---
    if (_matchesAny(m, ['thank', 'thanks', 'thx', 'ty ', 'salamat'])) {
      return "You're welcome! 💖 Happy shopping — let me know if you need anything else.";
    }
    if (_matchesAny(m, ['bye', 'goodbye', 'see you', 'paalam'])) {
      return "Bye! Come back anytime — Fashion21 is open 24/7. ✨";
    }

    // --- Help / capabilities ---
    if (_matchesAny(m, ['help', 'what can you do', 'menu', 'options'])) {
      return "I can help you with:\n• 💄 Finding products (just tell me what you want — e.g. \"red lipstick\")\n• 💰 Prices and current stock\n• 🚚 Shipping and delivery times\n• 💳 Payment options (COD, GCash, PayMongo)\n• ↩️ Returns and refunds\n• 🛒 How to order\nWhat would you like to know?";
    }

    // --- Order / how to buy ---
    if (_matchesAny(m, [
      'how to order', 'how to buy', 'how do i order', 'how do i buy',
      'where to buy', 'place order', 'checkout',
    ])) {
      return "Easy! 🛒\n1. Tap any product to view details\n2. Pick a variation (if any) and tap Add to Cart\n3. Open the cart icon at the top right\n4. Tap Proceed to Checkout, fill in your address, and pay\nYou can save addresses for next time too.";
    }

    // --- Payment ---
    if (_matchesAny(m, [
      'cod', 'cash on delivery', 'cash-on-delivery',
      'gcash', 'paymongo', 'paymaya', 'payment', 'pay ', 'how to pay',
      'credit card', 'debit card',
    ])) {
      return "We accept 💳:\n• Cash on Delivery (COD)\n• GCash\n• Credit / Debit cards via PayMongo\nYou can pick your preferred method during checkout.";
    }

    // --- Shipping ---
    if (_matchesAny(m, [
      'ship', 'deliver', 'arrive', 'arrival', 'how long',
      'kelan', 'kailan darating', 'lbc', 'j&t', 'courier',
    ])) {
      return "🚚 Delivery times:\n• Metro Manila: 2–4 business days\n• Luzon: 3–5 business days\n• Visayas / Mindanao: 5–7 business days\nFree shipping on orders over ₱1,500. Tracking is sent to your email once dispatched.";
    }

    // --- Returns ---
    if (_matchesAny(m, [
      'return', 'refund', 'exchange', 'wrong item', 'damaged', 'defect',
    ])) {
      return "↩️ You can request a return within 7 days of delivery if the item is unopened or arrived damaged. Just message the seller here with your order number and a photo and we'll sort it out.";
    }

    // --- Authenticity / brand ---
    if (_matchesAny(m, [
      'authentic', 'original', 'legit', 'fake', 'real',
    ])) {
      return "✅ Every product on Fashion21 Marketplace is 100% authentic and sourced directly from official suppliers.";
    }

    // --- Discount / promo ---
    if (_matchesAny(m, [
      'discount', 'promo', 'coupon', 'voucher', 'sale ', 'mura',
    ])) {
      return "🎉 We run promos regularly. Free shipping kicks in automatically over ₱1,500, and bundle deals appear on the product page when active. Ask the seller — they sometimes give loyal buyers a special code!";
    }

    // --- Price / stock / product lookup (live Supabase) ---
    final wantsPrice = _matchesAny(m, [
      'price', 'how much', 'magkano', 'cost', 'presyo',
    ]);
    final wantsStock = _matchesAny(m, [
      'stock', 'available', 'availability', 'in stock', 'sold out',
      'meron pa', 'meron ba',
    ]);
    final wantsRecommendation = _matchesAny(m, [
      'recommend', 'suggest', 'best', 'top ', 'popular', 'bestseller',
      'show me', 'looking for', 'do you have', 'do you sell',
      'meron ba kayo', 'mayroon ba',
    ]);

    if (wantsPrice || wantsStock || wantsRecommendation) {
      final products = await _searchProducts(m);
      if (products.isNotEmpty) {
        return _formatProductReply(
          products,
          wantsPrice: wantsPrice,
          wantsStock: wantsStock,
        );
      }
      // No matches — fall through to category/keyword hint below.
    }

    // --- Category keyword fallback ---
    final category = _detectCategory(m);
    if (category != null) {
      final products = await _searchProductsByCategory(category);
      if (products.isNotEmpty) {
        return "Here's what we have in $category 💄:\n${_listProducts(products)}\n\nTap a product on the marketplace screen to see full details.";
      }
      return "We don't have any $category in stock right now. Browse the marketplace for similar items, or check back soon!";
    }

    // --- Default fallback ---
    return "Got it — I've passed your message along to the seller and they'll reply as soon as they can. In the meantime, you can ask me about prices, stock, shipping, payment, or returns. 🛍️";
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
          .select('id, name, price, stock_quantity, category')
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
          .select('id, name, price, stock_quantity, category')
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
}
