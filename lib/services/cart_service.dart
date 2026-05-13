// lib/services/cart_service.dart
//
// Persistent cart synchronized with Supabase `cart_items` table.
// Falls back to local-only state when the user is signed out.

import 'package:supabase_flutter/supabase_flutter.dart';

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Loads all cart items for the current user. Returns an empty list when
  /// the user is signed out or the table is unreachable.
  Future<List<Map<String, dynamic>>> loadCart() async {
    final uid = _userId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('cart_items')
          .select('id, product_id, quantity, variation, '
              'products(name, price, image_url, business_id, stock_quantity)')
          .eq('user_id', uid);

      final list = <Map<String, dynamic>>[];
      for (final row in rows as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final product = m['products'] as Map?;
        list.add({
          'cart_id': m['id'],
          'id': m['product_id'],
          'name': product?['name'] ?? '',
          'price': product?['price'] ?? 0,
          'image_url': product?['image_url'],
          'business_id': product?['business_id'],
          'quantity': m['quantity'] ?? 1,
          'variation': m['variation'],
        });
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Adds a product to the cart, incrementing quantity if it already exists.
  /// Returns the cart row id when persisted, or null when offline.
  Future<String?> addItem({
    required String productId,
    required int quantity,
    Map<String, dynamic>? variation,
  }) async {
    final uid = _userId;
    if (uid == null) return null;
    try {
      // Check existing row for same product (and matching variation key if any).
      final existing = await _client
          .from('cart_items')
          .select('id, quantity, variation')
          .eq('user_id', uid)
          .eq('product_id', productId);

      Map<String, dynamic>? match;
      for (final row in existing as List) {
        final r = Map<String, dynamic>.from(row as Map);
        final v = r['variation'];
        final sameVar = (variation == null && v == null) ||
            (variation != null &&
                v is Map &&
                variation['color_name'] == v['color_name']);
        if (sameVar) {
          match = r;
          break;
        }
      }

      if (match != null) {
        final newQty = ((match['quantity'] as int?) ?? 0) + quantity;
        await _client
            .from('cart_items')
            .update({'quantity': newQty, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', match['id']);
        return match['id']?.toString();
      } else {
        final inserted = await _client
            .from('cart_items')
            .insert({
              'user_id': uid,
              'product_id': productId,
              'quantity': quantity,
              'variation': variation,
            })
            .select('id')
            .single();
        return inserted['id']?.toString();
      }
    } catch (e) {
      // Re-throw so the UI can show a meaningful error instead of silently
      // dropping the add-to-cart action.
      rethrow;
    }
  }

  Future<void> updateQuantity(String cartId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(cartId);
      return;
    }
    try {
      await _client
          .from('cart_items')
          .update({'quantity': newQuantity, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', cartId);
    } catch (_) {}
  }

  Future<void> removeItem(String cartId) async {
    try {
      await _client.from('cart_items').delete().eq('id', cartId);
    } catch (_) {}
  }

  Future<void> clearCart() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _client.from('cart_items').delete().eq('user_id', uid);
    } catch (_) {}
  }
}
