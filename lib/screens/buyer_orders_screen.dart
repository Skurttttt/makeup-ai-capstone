// lib/screens/buyer_orders_screen.dart
//
// Buyer-side order history & tracking screen.
// Modern, friendly UI: gradient header with summary, pill filter chips,
// elegant cards with product thumbnails and animated progress.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import 'chat_screen.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';

// ─── palette ─────────────────────────────────────────────────────────────────
const Color _kPink = Color(0xFFFF4D97);
const Color _kPinkDark = Color(0xFFCC3A7A);
const Color _kPinkDeep = Color(0xFFC71563);
const Color _kPinkSoft = Color(0xFFFFF0F5);
const Color _kPinkLight = Color(0xFFFFB8D4);
const Color _kBg = Color(0xFFFAF6F8);

// ─── status helpers ──────────────────────────────────────────────────────────
const _statusOrder = ['pending', 'paid', 'processing', 'shipped', 'delivered'];

Color _statusColor(String s) {
  switch (s) {
    case 'pending':
      return const Color(0xFFFF9F1C);
    case 'paid':
      return const Color(0xFF3B82F6);
    case 'processing':
      return const Color(0xFFA855F7);
    case 'shipped':
      return const Color(0xFF14B8A6);
    case 'delivered':
      return const Color(0xFF22C55E);
    case 'canceled':
    case 'failed':
      return const Color(0xFFEF4444);
    case 'refunded':
      return const Color(0xFF6366F1);
    default:
      return Colors.grey;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'Awaiting Payment';
    case 'paid':
      return 'Paid';
    case 'processing':
      return 'Preparing';
    case 'shipped':
      return 'On the way';
    case 'delivered':
      return 'Delivered';
    case 'canceled':
      return 'Cancelled';
    case 'failed':
      return 'Failed';
    case 'refunded':
      return 'Refunded';
    default:
      return s;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'pending':
      return Icons.hourglass_top_rounded;
    case 'paid':
      return Icons.payments_rounded;
    case 'processing':
      return Icons.inventory_2_rounded;
    case 'shipped':
      return Icons.local_shipping_rounded;
    case 'delivered':
      return Icons.verified_rounded;
    case 'canceled':
    case 'failed':
      return Icons.cancel_rounded;
    case 'refunded':
      return Icons.undo_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

// ─── screen ──────────────────────────────────────────────────────────────────


class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  final _client = Supabase.instance.client;

  static const _filters = [
    _FilterDef('all',       'All',              Icons.apps_rounded),
    _FilterDef('to_ship',   'To ship',          Icons.inventory_2_outlined),
    _FilterDef('shipped',   'Shipped',          Icons.local_shipping_rounded),
    _FilterDef('completed', 'Completed',        Icons.check_circle_outline_rounded),
    _FilterDef('pending',   'Pending',          Icons.hourglass_empty_rounded),
    _FilterDef('canceled',  'Canceled',         Icons.cancel_outlined),
    _FilterDef('failed',    'Failed delivery',  Icons.error_outline_rounded),
  ];

  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('Not logged in');

      final rows = await _client
          .from('orders')
          .select(
            'id, status, total, currency, created_at, updated_at, '
            'payment_method, tracking_number, courier, '
            'shipped_at, delivered_at, seller_notes, '
            'shipping_address, shipping_city, shipping_postal_code, '
            'order_items(id, product_id, product_name, product_image_url, '
            'quantity, unit_price, total_price, variation_name, business_id, '
            'products(name, image_url, business_id))',
          )
          .eq('buyer_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(rows);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _subscribeRealtime() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    _sub = _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', uid)
        .listen((_) => _load());
  }

  List<Map<String, dynamic>> _filtered(String f) {
    switch (f) {
      case 'to_ship':   return _orders.where((o) => ['paid', 'processing'].contains(o['status']?.toString())).toList();
      case 'shipped':   return _orders.where((o) => o['status']?.toString() == 'shipped').toList();
      case 'completed': return _orders.where((o) => o['status']?.toString() == 'delivered').toList();
      case 'pending':   return _orders.where((o) => o['status']?.toString() == 'pending').toList();
      case 'canceled':  return _orders.where((o) => o['status']?.toString() == 'canceled').toList();
      case 'failed':    return _orders.where((o) => o['status']?.toString() == 'failed').toList();
      default:          return _orders; // 'all'
    }
  }

  int _countFor(String f) => _filtered(f).length;

  // Summary stats
  int get _activeCount => _orders
      .where((o) => ['pending', 'paid', 'processing', 'shipped']
          .contains(o['status']?.toString()))
      .length;

  double get _totalSpent => _orders
      .where((o) => !['canceled', 'failed', 'refunded']
          .contains(o['status']?.toString()))
      .fold<double>(
          0, (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0));

  Future<void> _openChat(Map<String, dynamic> order) async {
    final myUid = _client.auth.currentUser?.id;
    if (myUid == null) return;

    final items = List<Map<String, dynamic>>.from(
        order['order_items'] as List? ?? []);
    if (items.isEmpty) return;
    final sellerId = items.first['business_id']?.toString();
    if (sellerId == null) return;

    try {
      Map<String, dynamic>? convo;
      final existing = await _client
          .from('chat_conversations')
          .select('id')
          .eq('buyer_id', myUid)
          .eq('seller_id', sellerId)
          .maybeSingle();
      if (existing != null) {
        convo = Map<String, dynamic>.from(existing);
      } else {
        final inserted = await _client
            .from('chat_conversations')
            .insert({'buyer_id': myUid, 'seller_id': sellerId})
            .select('id')
            .single();
        convo = Map<String, dynamic>.from(inserted);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convo!['id'].toString(),
            otherDisplayName: 'Fashion 21',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open chat: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final list = _filtered(_selectedFilter);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            const SizedBox(height: 4),
            Expanded(
              child: _loading && _orders.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPink))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: _kPink,
                          child: list.isEmpty
                              ? _buildEmpty()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 24),
                                  itemCount: list.length,
                                  itemBuilder: (_, i) => _BuyerOrderCard(
                                    order: list[i],
                                    onChat: () => _openChat(list[i]),
                                    onRefresh: _load,
                                  ),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── header ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPink, _kPinkDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x33CC3A7A),
              blurRadius: 20,
              offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.store,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Track every package, every step',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── filter chips ───────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final isSelected = _selectedFilter == f.key;
          final count = _countFor(f.key);

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _kPink : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? _kPink : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: _kPink.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.icon,
                    size: 16,
                    color: isSelected ? Colors.white : _kPinkDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : _kPinkSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : _kPinkDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── empty / error ──────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final isFiltered = _selectedFilter != 'all';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPinkSoft, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _kPink.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Icon(
                  isFiltered
                      ? Icons.filter_list_off_rounded
                      : Icons.shopping_bag_outlined,
                  size: 56,
                  color: _kPinkLight,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isFiltered
                    ? 'No orders here yet'
                    : 'Your order journey starts here',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kPinkDeep),
              ),
              const SizedBox(height: 8),
              Text(
                isFiltered
                    ? 'Try a different filter to see more orders.'
                    : 'Discover beauty products from amazing sellers and your orders will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    height: 1.4),
              ),
              if (!isFiltered) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  icon:
                      const Icon(Icons.shopping_bag_rounded, size: 18),
                  label: const Text('Browse Market'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Colors.red, size: 56),
              const SizedBox(height: 12),
              const Text('Could not load orders',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FilterDef {
  final String key;
  final String label;
  final IconData icon;
  const _FilterDef(this.key, this.label, this.icon);
}

// ─── stat card (header) ──────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORDER CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _BuyerOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onChat;
  final Future<void> Function() onRefresh;
  const _BuyerOrderCard({
    required this.order,
    required this.onChat,
    required this.onRefresh,
  });

  @override
  State<_BuyerOrderCard> createState() => _BuyerOrderCardState();
}

class _BuyerOrderCardState extends State<_BuyerOrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order['status']?.toString() ?? 'pending';
    final color = _statusColor(status);
    final shortId = (order['id']?.toString() ?? '')
        .replaceAll('-', '')
        .substring(0, 8)
        .toUpperCase();
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final currency = order['currency']?.toString() ?? 'PHP';
    final createdAt =
        DateTime.tryParse(order['created_at']?.toString() ?? '') ??
            DateTime.now();
    final items = List<Map<String, dynamic>>.from(
        order['order_items'] as List? ?? []);
    final isTerminal = ['delivered', 'canceled', 'failed', 'refunded']
        .contains(status);
    final showTracking = status == 'shipped' || status == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── status banner ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(_statusIcon(status),
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#$shortId · ${DateFormat('MMM d, yyyy').format(createdAt)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$currency ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kPinkDeep),
                ),
              ],
            ),
          ),

          // ── progress stepper ──────────────────────────────────────────
          if (!isTerminal)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _StatusStepper(status: status),
            ),

          // ── product items (collapsible) ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                ...items
                    .take(_expanded ? items.length : 2)
                    .map((it) => _ItemRow(item: it)),
                if (items.length > 2)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      child: Text(
                        _expanded
                            ? 'Show less'
                            : '+${items.length - 2} more item${items.length - 2 == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: _expanded
                                ? Colors.grey.shade500
                                : _kPinkDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── tracking card ─────────────────────────────────────────────
          if (showTracking)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _TrackingCard(order: order),
            ),

          // ── primary CTA: confirm received / rate products ──────────────
          if (status == 'shipped')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmReceived(context),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Mark as Received',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          if (status == 'delivered')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openRateSheet(context, items),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Rate Your Products',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB400),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          // ── pay now + cancel buttons (pending only) ───────────────────
          if (status == 'pending') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payNow(context),
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('Pay Now',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOrder(context),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Order',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],

          // ── action row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16),
                    label: const Text('Chat Seller',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPinkDark,
                      side: const BorderSide(color: _kPinkLight),
                      padding:
                          const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetailsSheet(context, order),
                    icon: const Icon(Icons.info_outline_rounded,
                        size: 16),
                    label: const Text('Details',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsSheet(BuildContext context, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(order: order),
    );
  }

  Future<void> _payNow(BuildContext context) async {
    // Step 1: show payment method selection
    String? selectedMethod = await showDialog<String>(
      context: context,
      builder: (ctx) => _PaymentMethodDialog(),
    );
    if (selectedMethod == null) return;

    if (!context.mounted) return;

    // Show loading
    final messenger = ScaffoldMessenger.of(context);
    final progressOverlay = OverlayEntry(
      builder: (_) => const ColoredBox(
        color: Color(0x55000000),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
    Overlay.of(context).insert(progressOverlay);

    try {
      final result = await SupabaseService().payExistingOrder(
        orderId: widget.order['id'].toString(),
        paymentMethod: selectedMethod,
      );
      progressOverlay.remove();

      final checkoutUrl = result['checkout_url']?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw 'No checkout URL returned';
      }

      final uri = Uri.parse(checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not open payment page';
      }

      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Complete your payment in the browser. Your order will update once paid.'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      progressOverlay.remove();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Order',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final client = Supabase.instance.client;
      await client.from('orders').update({
        'status': 'canceled',
      }).eq('id', widget.order['id']);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Re-add cancelled order items back to the cart
      final items = List<Map<String, dynamic>>.from(
          widget.order['order_items'] as List? ?? []);
      for (final item in items) {
        final productId = item['product_id']?.toString();
        if (productId == null) continue;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final variationName = item['variation_name']?.toString();
        await CartService.instance.addItem(
          productId: productId,
          quantity: qty,
          variation: variationName != null ? {'color_name': variationName} : null,
        );
      }

      await widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not cancel: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmReceived(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Receipt',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Have you received this order in good condition? '
          'You\u2019ll be able to rate the products afterwards.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not yet',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, received'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final client = Supabase.instance.client;
      await client.from('orders').update({
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.order['id']);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as received \u2728'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onRefresh();
      if (!context.mounted) return;
      // Prompt for rating right away
      final items = List<Map<String, dynamic>>.from(
          widget.order['order_items'] as List? ?? []);
      _openRateSheet(context, items);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not update: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _openRateSheet(
      BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(
        order: widget.order,
        items: items,
        onSubmitted: widget.onRefresh,
      ),
    );
  }
}

// ─── status stepper (animated) ───────────────────────────────────────────────
class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = ['paid', 'processing', 'shipped', 'delivered'];
    const labels = ['Paid', 'Preparing', 'Shipped', 'Delivered'];
    final currentIdx = _statusOrder.indexOf(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final reached =
              currentIdx >= _statusOrder.indexOf(steps[stepIdx + 1]);
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: reached ? _kPink : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final stepStatus = steps[idx];
        final stepOrder = _statusOrder.indexOf(stepStatus);
        final reached = currentIdx >= stepOrder;
        final isActive = status == stepStatus;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: isActive ? 32 : 24,
              height: isActive ? 32 : 24,
              decoration: BoxDecoration(
                color: reached ? _kPink : Colors.grey.shade200,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color: _kPink.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ]
                    : null,
              ),
              child: Icon(
                reached ? Icons.check_rounded : _statusIcon(stepStatus),
                size: isActive ? 16 : 12,
                color: reached ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 60,
              child: Text(
                labels[idx],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight:
                      isActive ? FontWeight.w800 : FontWeight.w500,
                  color: reached ? _kPinkDark : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── tracking card ───────────────────────────────────────────────────────────
class _TrackingCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _TrackingCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final tracking = order['tracking_number']?.toString() ?? '';
    final courier = order['courier']?.toString() ?? 'Courier';
    final notes = order['seller_notes']?.toString() ?? '';
    final shippedAt =
        DateTime.tryParse(order['shipped_at']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.cyan.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade100, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_shipping_rounded,
                    color: Colors.teal.shade700, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shipping with',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.teal.shade600,
                            fontWeight: FontWeight.w600)),
                    Text(courier,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.teal.shade900)),
                  ],
                ),
              ),
              if (shippedAt != null)
                Text(
                  DateFormat('MMM d').format(shippedAt),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal.shade600,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (tracking.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_rounded,
                      size: 16, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tracking,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.teal.shade900,
                          letterSpacing: 0.3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: tracking));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: const Text(
                                'Tracking number copied! 📋'),
                            backgroundColor: Colors.teal.shade700,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.copy_rounded,
                          size: 14, color: Colors.teal.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 14, color: Colors.teal.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade800,
                        fontStyle: FontStyle.italic,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── item row ────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final productJoin = item['products'] as Map?;
    final name = (item['product_name']?.toString().isNotEmpty == true
            ? item['product_name']?.toString()
            : productJoin?['name']?.toString()) ??
        'Product';
    final rawImage =
        (item['product_image_url']?.toString().isNotEmpty == true
            ? item['product_image_url']?.toString()
            : productJoin?['image_url']?.toString());
    final imageUrl = (rawImage?.isNotEmpty == true) ? rawImage : null;
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final variation = item['variation_name']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? Image.network(imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (variation != null && variation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kPinkSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(variation,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: _kPinkDark,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '×$qty · ₱${price.toStringAsFixed(2)} each',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₱${(price * qty).toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _kPinkDeep),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPinkSoft, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.image_outlined,
            size: 24, color: _kPinkLight),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAYMENT METHOD DIALOG
// ═══════════════════════════════════════════════════════════════════════════════
class _PaymentMethodDialog extends StatefulWidget {
  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  String _selected = 'xendit';

  static const _methods = [
    {'key': 'xendit', 'label': 'Credit / Debit Card', 'sub': 'Visa, Mastercard via Xendit', 'icon': Icons.credit_card_rounded},
    {'key': 'gcash', 'label': 'GCash', 'sub': 'Pay via GCash e-wallet', 'icon': Icons.account_balance_wallet_rounded},
    {'key': 'paymaya', 'label': 'Maya', 'sub': 'Pay via Maya e-wallet', 'icon': Icons.wallet_rounded},
    {'key': 'otc', 'label': 'Over-the-Counter', 'sub': '7-Eleven, Bayad Center, etc.', 'icon': Icons.store_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPinkSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment_rounded, color: _kPink, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Select Payment Method',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kPinkDeep),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._methods.map((m) {
              final key = m['key'] as String;
              final isSelected = _selected == key;
              return GestureDetector(
                onTap: () => setState(() => _selected = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? _kPinkSoft : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _kPink : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(m['icon'] as IconData,
                          color: isSelected ? _kPink : Colors.grey.shade500, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['label'] as String,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isSelected ? _kPinkDeep : Colors.black87)),
                            Text(m['sub'] as String,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: _kPink, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORDER DETAILS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _OrderDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderDetailsSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'pending';
    final color = _statusColor(status);
    final shortId = (order['id']?.toString() ?? '')
        .replaceAll('-', '')
        .substring(0, 8)
        .toUpperCase();
    final createdAt =
        DateTime.tryParse(order['created_at']?.toString() ?? '') ??
            DateTime.now();
    final shippedAt =
        DateTime.tryParse(order['shipped_at']?.toString() ?? '');
    final deliveredAt =
        DateTime.tryParse(order['delivered_at']?.toString() ?? '');
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final currency = order['currency']?.toString() ?? 'PHP';
    final paymentMethod = order['payment_method']?.toString() ?? '—';
    final addr = [
      order['shipping_address'],
      order['shipping_city'],
      order['shipping_postal_code'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_statusIcon(status),
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #$shortId',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            Text(_statusLabel(status),
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  _DetailSection(
                    title: 'Timeline',
                    icon: Icons.schedule_rounded,
                    children: [
                      _TimelineRow(
                        icon: Icons.shopping_cart_checkout_rounded,
                        label: 'Order Placed',
                        time: createdAt,
                        color: const Color(0xFF3B82F6),
                        done: true,
                      ),
                      if (shippedAt != null)
                        _TimelineRow(
                          icon: Icons.local_shipping_rounded,
                          label: 'Shipped',
                          time: shippedAt,
                          color: Colors.teal,
                          done: true,
                          isLast: deliveredAt == null,
                        ),
                      if (deliveredAt != null)
                        _TimelineRow(
                          icon: Icons.check_circle_rounded,
                          label: 'Delivered',
                          time: deliveredAt,
                          color: Colors.green,
                          done: true,
                          isLast: true,
                        ),
                    ],
                  ),

                  if (addr.isNotEmpty)
                    _DetailSection(
                      title: 'Shipping Address',
                      icon: Icons.location_on_rounded,
                      children: [
                        Text(addr,
                            style: const TextStyle(
                                fontSize: 13.5, height: 1.4)),
                      ],
                    ),

                  _DetailSection(
                    title: 'Payment',
                    icon: Icons.payments_rounded,
                    children: [
                      _kvRow('Method', paymentMethod.toUpperCase()),
                      const SizedBox(height: 8),
                      _kvRow('Total',
                          '$currency ${total.toStringAsFixed(2)}',
                          bold: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          Text(v,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? _kPinkDeep : Colors.black87)),
        ],
      );
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _DetailSection(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPinkSoft.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPinkSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _kPinkDark),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kPinkDeep,
                      letterSpacing: 0.2)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime time;
  final Color color;
  final bool done;
  final bool isLast;
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
    this.done = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: done ? color : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 12),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, yyyy · h:mm a').format(time),
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade600),
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

// ═══════════════════════════════════════════════════════════════════════════════
// RATING SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _RatingSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onSubmitted;
  const _RatingSheet({
    required this.order,
    required this.items,
    required this.onSubmitted,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _comments = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final it in widget.items) {
      final id = it['id'].toString();
      _ratings[id] = 0;
      _comments[id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final toSubmit = widget.items.where((it) {
      final id = it['id'].toString();
      return (_ratings[id] ?? 0) > 0;
    }).toList();

    if (toSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap a star to rate at least one product'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw Exception('Not logged in');

      final rows = toSubmit.map((it) {
        final id = it['id'].toString();
        return {
          'order_id': widget.order['id'],
          'order_item_id': id,
          'product_id': it['product_id'],
          'buyer_id': uid,
          'business_id': it['business_id'],
          'rating': _ratings[id],
          'comment': _comments[id]!.text.trim().isEmpty
              ? null
              : _comments[id]!.text.trim(),
        };
      }).toList();

      // Upsert so user can update an existing review.
      await client
          .from('product_reviews')
          .upsert(rows, onConflict: 'order_item_id,buyer_id');

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for your review! \u2b50'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not submit review: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB400), Color(0xFFFF8A00)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rate Your Products',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text(
                          'Help other shoppers with honest feedback',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final it = widget.items[i];
                  final id = it['id'].toString();
                  return _RateItemCard(
                    item: it,
                    rating: _ratings[id] ?? 0,
                    commentCtrl: _comments[id]!,
                    onRate: (r) => setState(() => _ratings[id] = r),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Submit Reviews',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
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

class _RateItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rating;
  final TextEditingController commentCtrl;
  final ValueChanged<int> onRate;
  const _RateItemCard({
    required this.item,
    required this.rating,
    required this.commentCtrl,
    required this.onRate,
  });

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Amazing'];

  @override
  Widget build(BuildContext context) {
    final productJoin = item['products'] as Map?;
    final name = (item['product_name']?.toString().isNotEmpty == true
            ? item['product_name']?.toString()
            : productJoin?['name']?.toString()) ??
        'Product';
    final rawImage =
        (item['product_image_url']?.toString().isNotEmpty == true
            ? item['product_image_url']?.toString()
            : productJoin?['image_url']?.toString());
    final imageUrl = (rawImage?.isNotEmpty == true) ? rawImage : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color: _kPinkSoft,
                              child: const Icon(Icons.image_outlined,
                                  color: _kPinkLight),
                            ))
                    : Container(
                        width: 48,
                        height: 48,
                        color: _kPinkSoft,
                        child: const Icon(Icons.image_outlined,
                            color: _kPinkLight),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < rating;
              return GestureDetector(
                onTap: () => onRate(i + 1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 34,
                    color: filled
                        ? const Color(0xFFFFB400)
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                _labels[rating],
                style: const TextStyle(
                    color: Color(0xFFFF8A00),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: commentCtrl,
            maxLines: 2,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Share your thoughts (optional)',
              hintStyle:
                  TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
              counterText: '',
              filled: true,
              fillColor: _kPinkSoft.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
