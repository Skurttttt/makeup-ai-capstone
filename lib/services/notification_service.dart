// lib/services/notification_service.dart
//
// Notification system for both sellers (business dashboard) and buyers (HomeScreen):
//  Seller: new orders, low stock, incoming customer messages
//  Buyer:  order status changes, new bot/seller messages
//
// Uses Supabase realtime + light polling for low-stock. Exposes a
// ChangeNotifier so the bell badge auto-updates, plus a stream of new
// notifications so the host screen can "ping" the user with a snackbar.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppNotificationType { order, lowStock, message }

/// Whether this service instance is running as a seller or buyer.
enum _Role { seller, buyer }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? meta;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.meta,
    this.read = false,
  });
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final SupabaseClient _client = Supabase.instance.client;

  String? _id; // business_id (seller) or user uid (buyer)
  _Role _role = _Role.seller;
  bool _started = false;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  /// Emits each newly-arrived notification so the UI can ping the user.
  final StreamController<AppNotification> _newController =
      StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get onNewNotification => _newController.stream;

  StreamSubscription<List<Map<String, dynamic>>>? _orderItemsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _conversationsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _buyerOrdersSub;
  Timer? _lowStockTimer;

  // De-dupe sets for realtime streams (which re-emit the full table on init).
  final Set<String> _seenOrderItemIds = {};
  final Map<String, DateTime> _seenConversationStamps = {};
  final Map<String, String> _seenOrderStatuses = {};
  final Set<String> _seenLowStockIds = {};
  bool _orderItemsBootstrapped = false;
  bool _conversationsBootstrapped = false;
  bool _buyerOrdersBootstrapped = false;

  /// Call once when the **seller** (business dashboard) mounts.
  Future<void> start(String businessId) async {
    if (_started && _id == businessId && _role == _Role.seller) return;
    if (_started) await stop();
    _id = businessId;
    _role = _Role.seller;
    _started = true;

    _subscribeOrderItems();
    _subscribeSellerConversations();
    _startLowStockPolling();
  }

  /// Call once when the **buyer** (HomeScreen) mounts.
  Future<void> startForBuyer(String userId) async {
    if (_started && _id == userId && _role == _Role.buyer) return;
    if (_started) await stop();
    _id = userId;
    _role = _Role.buyer;
    _started = true;

    _subscribeBuyerConversations();
    _subscribeBuyerOrders();
  }

  Future<void> stop() async {
    _started = false;
    await _orderItemsSub?.cancel();
    await _conversationsSub?.cancel();
    await _buyerOrdersSub?.cancel();
    _orderItemsSub = null;
    _conversationsSub = null;
    _buyerOrdersSub = null;
    _lowStockTimer?.cancel();
    _lowStockTimer = null;
    _seenOrderItemIds.clear();
    _seenConversationStamps.clear();
    _seenOrderStatuses.clear();
    _seenLowStockIds.clear();
    _orderItemsBootstrapped = false;
    _conversationsBootstrapped = false;
    _buyerOrdersBootstrapped = false;
  }

  void markAllRead() {
    var changed = false;
    for (final n in _items) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void markRead(String id) {
    for (final n in _items) {
      if (n.id == id && !n.read) {
        n.read = true;
        notifyListeners();
        return;
      }
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void _push(AppNotification n) {
    _items.insert(0, n);
    if (_items.length > 100) _items.removeLast();
    notifyListeners();
    if (!_newController.isClosed) _newController.add(n);
  }

  // ═══════════════════════════════════════════════ SELLER ════

  void _subscribeOrderItems() {
    final bid = _id;
    if (bid == null) return;
    _orderItemsSub = _client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('business_id', bid)
        .listen(
          (rows) async {
            if (!_orderItemsBootstrapped) {
              for (final r in rows) {
                final id = r['id']?.toString();
                if (id != null) _seenOrderItemIds.add(id);
              }
              _orderItemsBootstrapped = true;
              return;
            }
            for (final row in rows) {
              final id = row['id']?.toString();
              if (id == null || _seenOrderItemIds.contains(id)) continue;
              _seenOrderItemIds.add(id);
              await _emitOrderNotification(row);
            }
          },
          onError: (_) {},
        );
  }

  Future<void> _emitOrderNotification(Map<String, dynamic> item) async {
    String productName = 'Product';
    final productId = item['product_id']?.toString();
    if (productId != null) {
      try {
        final p = await _client
            .from('products')
            .select('name')
            .eq('id', productId)
            .maybeSingle();
        if (p != null && p['name'] != null) {
          productName = p['name'].toString();
        }
      } catch (_) {}
    }
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final total = (item['total_price'] as num?)?.toDouble() ?? 0;
    _push(AppNotification(
      id: 'order_${item['id']}',
      type: AppNotificationType.order,
      title: 'New order received! 🛍️',
      body: '$qty × $productName • ₱${total.toStringAsFixed(2)}',
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
          DateTime.now(),
      meta: {'order_id': item['order_id'], 'product_id': productId},
    ));
  }

  void _subscribeSellerConversations() {
    final bid = _id;
    if (bid == null) return;
    _conversationsSub = _client
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .eq('seller_id', bid)
        .listen(
          (rows) {
            if (!_conversationsBootstrapped) {
              for (final r in rows) {
                final id = r['id']?.toString();
                final stamp = DateTime.tryParse(
                    r['last_message_at']?.toString() ?? '');
                if (id != null && stamp != null) {
                  _seenConversationStamps[id] = stamp;
                }
              }
              _conversationsBootstrapped = true;
              return;
            }
            for (final row in rows) {
              final id = row['id']?.toString();
              if (id == null) continue;
              final stamp = DateTime.tryParse(
                  row['last_message_at']?.toString() ?? '');
              if (stamp == null) continue;
              final prev = _seenConversationStamps[id];
              if (prev == null || stamp.isAfter(prev)) {
                _seenConversationStamps[id] = stamp;
                if (prev != null) _emitMessageNotification(row, isBuyer: false);
              }
            }
          },
          onError: (_) {},
        );
  }

  void _emitMessageNotification(Map<String, dynamic> conv, {required bool isBuyer}) {
    final preview = (conv['last_message'] ?? '').toString();
    _push(AppNotification(
      id: 'msg_${conv['id']}_${conv['last_message_at']}',
      type: AppNotificationType.message,
      title: isBuyer ? 'New reply in your chat 💬' : 'New customer message 💬',
      body: preview.isEmpty ? 'You have a new message' : preview,
      createdAt: DateTime.tryParse(conv['last_message_at']?.toString() ?? '') ??
          DateTime.now(),
      meta: {'conversation_id': conv['id']},
    ));
  }

  void _startLowStockPolling() {
    Future.delayed(const Duration(seconds: 4), _checkLowStock);
    _lowStockTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkLowStock(),
    );
  }

  Future<void> _checkLowStock() async {
    final bid = _id;
    if (bid == null) return;
    try {
      final rows = await _client
          .from('products')
          .select('id, name, stock_quantity')
          .eq('business_id', bid)
          .lte('stock_quantity', 5);

      final currentLow = <String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null) continue;
        currentLow.add(id);
        if (_seenLowStockIds.contains(id)) continue;
        _seenLowStockIds.add(id);
        final stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
        final name = (row['name'] ?? 'Product').toString();
        _push(AppNotification(
          id: 'low_${id}_${DateTime.now().millisecondsSinceEpoch}',
          type: AppNotificationType.lowStock,
          title: stock == 0 ? 'Out of stock ⚠️' : 'Low stock alert 📉',
          body: stock == 0
              ? '"$name" is out of stock — restock soon.'
              : '"$name" is running low ($stock left).',
          createdAt: DateTime.now(),
          meta: {'product_id': id},
        ));
      }
      _seenLowStockIds.removeWhere((id) => !currentLow.contains(id));
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════ BUYER ════

  void _subscribeBuyerConversations() {
    final uid = _id;
    if (uid == null) return;
    _conversationsSub = _client
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', uid)
        .listen(
          (rows) {
            if (!_conversationsBootstrapped) {
              for (final r in rows) {
                final id = r['id']?.toString();
                final stamp = DateTime.tryParse(
                    r['last_message_at']?.toString() ?? '');
                if (id != null && stamp != null) {
                  _seenConversationStamps[id] = stamp;
                }
              }
              _conversationsBootstrapped = true;
              return;
            }
            for (final row in rows) {
              final id = row['id']?.toString();
              if (id == null) continue;
              final stamp = DateTime.tryParse(
                  row['last_message_at']?.toString() ?? '');
              if (stamp == null) continue;
              final prev = _seenConversationStamps[id];
              if (prev == null || stamp.isAfter(prev)) {
                _seenConversationStamps[id] = stamp;
                // Don't notify for the buyer's own outgoing messages.
                // last_message is set by sendMessage so we check sender_role
                // via last_message prefix heuristic — but simpler: only fire
                // when the last message role on the conv is not 'buyer'.
                if (prev != null) {
                  final lastRole = row['last_sender_role']?.toString() ?? '';
                  if (lastRole != 'buyer') {
                    _emitMessageNotification(row, isBuyer: true);
                  }
                }
              }
            }
          },
          onError: (_) {},
        );
  }

  void _subscribeBuyerOrders() {
    final uid = _id;
    if (uid == null) return;
    _buyerOrdersSub = _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', uid)
        .listen(
          (rows) {
            if (!_buyerOrdersBootstrapped) {
              for (final r in rows) {
                final id = r['id']?.toString();
                final st = r['status']?.toString() ?? '';
                if (id != null) _seenOrderStatuses[id] = st;
              }
              _buyerOrdersBootstrapped = true;
              return;
            }
            for (final row in rows) {
              final id = row['id']?.toString();
              if (id == null) continue;
              final status = (row['status'] ?? '').toString();
              final prev = _seenOrderStatuses[id];
              if (prev == status) continue;
              _seenOrderStatuses[id] = status;
              if (prev == null) continue; // brand-new order, skip
              _push(AppNotification(
                id: 'buyer_order_${id}_$status',
                type: AppNotificationType.order,
                title: _orderStatusTitle(status),
                body: 'Order #${id.substring(0, 8)} is now $status.',
                createdAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                    DateTime.now(),
                meta: {'order_id': id},
              ));
            }
          },
          onError: (_) {},
        );
  }

  String _orderStatusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Order confirmed ✅';
      case 'processing':
        return 'Order is being processed 📦';
      case 'shipped':
        return 'Your order is on the way 🚚';
      case 'delivered':
        return 'Order delivered! 🎉';
      case 'cancelled':
        return 'Order cancelled ❌';
      default:
        return 'Order update 🛍️';
    }
  }
}
