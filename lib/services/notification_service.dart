// lib/services/notification_service.dart
//
// Business notification system:
//  - new orders (order_items where business_id == me)
//  - low stock (products where business_id == me AND stock_quantity <= 5)
//  - new chat messages (chat_conversations where seller_id == me, last_message_at advances)
//
// Uses Supabase realtime + light polling for low-stock. Exposes a
// ChangeNotifier so the bell badge auto-updates, plus a stream of new
// notifications so the host screen can "ping" the user with a snackbar.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppNotificationType { order, lowStock, message }

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

  String? _businessId;
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
  Timer? _lowStockTimer;

  // De-dupe sets for realtime streams (which re-emit the full table on init).
  final Set<String> _seenOrderItemIds = {};
  final Map<String, DateTime> _seenConversationStamps = {};
  final Set<String> _seenLowStockIds = {};
  bool _orderItemsBootstrapped = false;
  bool _conversationsBootstrapped = false;

  /// Call once when the business user logs in / dashboard mounts.
  Future<void> start(String businessId) async {
    if (_started && _businessId == businessId) return;
    if (_started) await stop();
    _businessId = businessId;
    _started = true;

    _subscribeOrderItems();
    _subscribeConversations();
    _startLowStockPolling();
  }

  Future<void> stop() async {
    _started = false;
    await _orderItemsSub?.cancel();
    await _conversationsSub?.cancel();
    _orderItemsSub = null;
    _conversationsSub = null;
    _lowStockTimer?.cancel();
    _lowStockTimer = null;
    _seenOrderItemIds.clear();
    _seenConversationStamps.clear();
    _seenLowStockIds.clear();
    _orderItemsBootstrapped = false;
    _conversationsBootstrapped = false;
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

  // --------------------------------------------------------------- orders
  void _subscribeOrderItems() {
    final bid = _businessId;
    if (bid == null) return;
    _orderItemsSub = _client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('business_id', bid)
        .listen(
          (rows) async {
            // Seed on first emission so we don't notify for historical orders.
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

  // ---------------------------------------------------------- conversations
  void _subscribeConversations() {
    final bid = _businessId;
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
                if (prev != null) {
                  _emitMessageNotification(row);
                }
              }
            }
          },
          onError: (_) {},
        );
  }

  void _emitMessageNotification(Map<String, dynamic> conv) {
    final preview = (conv['last_message'] ?? '').toString();
    _push(AppNotification(
      id: 'msg_${conv['id']}_${conv['last_message_at']}',
      type: AppNotificationType.message,
      title: 'New customer message 💬',
      body: preview.isEmpty ? 'You have a new message' : preview,
      createdAt: DateTime.tryParse(conv['last_message_at']?.toString() ?? '') ??
          DateTime.now(),
      meta: {'conversation_id': conv['id']},
    ));
  }

  // ------------------------------------------------------------- low stock
  void _startLowStockPolling() {
    // First check soon, then every 5 minutes.
    Future.delayed(const Duration(seconds: 4), _checkLowStock);
    _lowStockTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkLowStock(),
    );
  }

  Future<void> _checkLowStock() async {
    final bid = _businessId;
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
      // Allow re-notifying once a product has been restocked above the threshold.
      _seenLowStockIds.removeWhere((id) => !currentLow.contains(id));
    } catch (_) {
      // ignore
    }
  }
}
