// lib/screens/client_orders_screen.dart
//
// Seller order-management screen.
// Shows all orders that contain the seller's products, grouped by status.
// Seller can: mark as Processing → Shipped (enter tracking) → Delivered.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'waybill_preview_screen.dart';
import 'delivery_confirmation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

// ─── colour palette (matches client_dashboard_screen) ────────────────────────
const _kPink = Color(0xFFFF4D8C);
const _kPinkDark = Color(0xFFD6336C);
const _kPinkDeep = Color(0xFFC71563);
const _kPinkSoft = Color(0xFFFFF0F5);
const _kPinkLight = Color(0xFFFFB8D4);

// ─── order status helpers ─────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.orange;
    case 'paid':
      return Colors.blue;
    case 'processing':
      return Colors.purple;
    case 'shipped':
      return Colors.teal;
    case 'delivered':
      return Colors.green;
    case 'failed':
    case 'canceled':
      return Colors.red;
    case 'refunded':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.hourglass_empty_rounded;
    case 'paid':
      return Icons.payment_rounded;
    case 'processing':
      return Icons.inventory_2_outlined;
    case 'shipped':
      return Icons.local_shipping_rounded;
    case 'delivered':
      return Icons.check_circle_rounded;
    case 'failed':
    case 'canceled':
      return Icons.cancel_rounded;
    case 'refunded':
      return Icons.reply_rounded;
    default:
      return Icons.circle_outlined;
  }
}

String _statusLabel(String status) =>
    status[0].toUpperCase() + status.substring(1);

/// Returns the next logical status a seller can advance an order to,
/// or null if the order is terminal / already delivered.
String? _nextStatus(String current) {
  switch (current) {
    case 'pending':
      return 'processing'; // seller accepts unpaid/COD-pending order
    case 'paid':
      return 'shipped'; // open ship dialog directly (skip manual processing step)
    case 'processing':
      return 'shipped';
    case 'shipped':
      return 'delivered';
    case 'failed':
      return 'shipped'; // re-ship failed delivery
    default:
      return null;
  }
}

String _tabLabel(String key) {
  switch (key) {
    case 'all':       return 'All';
    case 'to_ship':   return 'To ship';
    case 'shipped':   return 'Shipped';
    case 'completed': return 'Completed';
    case 'pending':   return 'Pending';
    case 'canceled':  return 'Canceled';
    case 'failed':    return 'Failed delivery';
    default:          return key;
  }
}

IconData _tabIcon(String key) {
  switch (key) {
    case 'all':       return Icons.shopping_bag_outlined;
    case 'to_ship':   return Icons.inventory_2_outlined;
    case 'shipped':   return Icons.local_shipping_rounded;
    case 'completed': return Icons.check_circle_outline_rounded;
    case 'pending':   return Icons.hourglass_empty_rounded;
    case 'canceled':  return Icons.cancel_outlined;
    case 'failed':    return Icons.error_outline_rounded;
    default:          return Icons.inbox_outlined;
  }
}

// ─── screen ───────────────────────────────────────────────────────────────────
class ClientOrdersScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;
  const ClientOrdersScreen({super.key, required this.clientData});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  final _svc    = SupabaseService();
  late TabController _tabs;

  static const _tabStatuses = [
    'all',
    'to_ship',
    'shipped',
    'completed',
    'pending',
    'canceled',
    'failed',
  ];

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  /// Last courier the seller used — persisted across sessions.
  String _preferredCourier = _couriers.first;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabStatuses.length, vsync: this);
    _load();
    _loadPreferredCourier();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferredCourier() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('preferred_courier');
    if (saved != null && _couriers.contains(saved) && mounted) {
      setState(() => _preferredCourier = saved);
    }
  }

  Future<void> _savePreferredCourier(String courier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_courier', courier);
    if (mounted) setState(() => _preferredCourier = courier);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bid = widget.clientData['id']?.toString();
      if (bid == null) throw Exception('No business id');

      // Step 1: find all order_ids that belong to this seller
      final itemRows = await _client
          .from('order_items')
          .select('order_id')
          .eq('business_id', bid);

      final orderIds = itemRows
          .map((r) => r['order_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (orderIds.isEmpty) {
        if (mounted) setState(() { _orders = []; _loading = false; _error = null; });
        return;
      }

      // Step 2: fetch those orders + all their items for this business
      final rows = await _client
          .from('orders')
          .select(
            'id, status, total, currency, created_at, updated_at, '
            'buyer_id, buyer_name, buyer_email, buyer_phone, '
            'shipping_address, shipping_city, shipping_postal_code, '
            'payment_method, tracking_number, courier, '
            'shipped_at, delivered_at, seller_notes, '
            'order_items(id, product_id, product_name, product_image_url, '
            'quantity, unit_price, total_price, variation_name, business_id, '
            'products(name, image_url))',
          )
          .inFilter('id', orderIds)
          .order('created_at', ascending: false);

      // Keep only items from this seller in each order's item list
      final filtered = (rows as List).map((o) {
        final order = Map<String, dynamic>.from(o as Map);
        final allItems =
            List<Map<String, dynamic>>.from(order['order_items'] as List? ?? []);
        order['order_items'] =
            allItems.where((i) => i['business_id']?.toString() == bid).toList();
        return order;
      }).toList();

      if (mounted) {
        setState(() {
          _orders = filtered;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _subscribeRealtime() {
    final bid = widget.clientData['id']?.toString();
    if (bid == null) return;
    _sub = _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((_) => _load());
  }

  List<Map<String, dynamic>> _filtered(String tab) {
    switch (tab) {
      case 'to_ship':   return _orders.where((o) => ['paid', 'processing'].contains(o['status'])).toList();
      case 'shipped':   return _orders.where((o) => o['status'] == 'shipped').toList();
      case 'completed': return _orders.where((o) => o['status'] == 'delivered').toList();
      case 'pending':   return _orders.where((o) => o['status'] == 'pending').toList();
      case 'canceled':  return _orders.where((o) => o['status'] == 'canceled').toList();
      case 'failed':    return _orders.where((o) => o['status'] == 'failed').toList();
      default:          return _orders; // 'all'
    }
  }

  // ── advance order status ──────────────────────────────────────────────────
  Future<void> _advanceStatus(Map<String, dynamic> order) async {
    final next = _nextStatus(order['status'] as String? ?? '');
    if (next == null) return;

    if (next == 'shipped') {
      await _showShipDialog(order);
    } else {
      await _updateStatus(order['id'] as String, next, {});
    }
  }

  // Philippine couriers list
  static const _couriers = [
    'J&T Express',
    'LBC Express',
    'Ninja Van',
    'Grab Express',
    'Lalamove',
    'DHL',
    'FedEx',
    'SPX Express (Shopee)',
    'Flash Express',
    'AP Cargo',
    'JRS Express',
    'Other',
  ];

  static const _courierAbbr = {
    'J&T Express': 'J&T',
    'LBC Express': 'LBC',
    'Ninja Van': 'NINJA',
    'Grab Express': 'GRAB',
    'Lalamove': 'LALA',
    'DHL': 'DHL',
    'FedEx': 'FEDEX',
    'SPX Express (Shopee)': 'SPX',
    'Flash Express': 'FLASH',
    'AP Cargo': 'APC',
    'JRS Express': 'JRS',
    'Other': '···',
  };

  static const _courierDays = <String, List<int>>{
    'Grab Express': [0, 0],
    'Lalamove': [0, 0],
    'J&T Express': [2, 5],
    'Ninja Van': [2, 5],
    'FedEx': [2, 5],
    'SPX Express (Shopee)': [2, 5],
    'Flash Express': [2, 4],
    'LBC Express': [3, 7],
    'DHL': [3, 7],
    'AP Cargo': [3, 7],
    'JRS Express': [3, 7],
    'Other': [3, 7],
  };

  String _estimatedDelivery(String courier) {
    final range = _courierDays[courier] ?? [3, 7];
    if (range[0] == 0) return 'Same day';
    final now  = DateTime.now();
    final from = now.add(Duration(days: range[0]));
    final to   = now.add(Duration(days: range[1]));
    final fmt  = DateFormat('MMM d');
    return range[0] == range[1]
        ? fmt.format(from)
        : '${fmt.format(from)} – ${fmt.format(to)}';
  }

  /// Generates a short unique tracking number: PREFIX-YYYYMMDD-XXXXXX
  String _generateTracking(String courier) {
    final prefix = courier.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final shortPrefix = prefix.length >= 3 ? prefix.substring(0, 3) : prefix.padRight(3, 'X');
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final rand = (DateTime.now().millisecondsSinceEpoch % 1000000)
        .toString()
        .padLeft(6, '0');
    return '$shortPrefix-$date-$rand';
  }

  Future<void> _showShipDialog(Map<String, dynamic> order) async {
    String selectedCourier =
        _couriers.contains(order['courier']?.toString())
            ? order['courier'].toString()
            : _preferredCourier;

    final existingTracking = order['tracking_number']?.toString() ?? '';
    final trackCtrl = TextEditingController(
        text: existingTracking.isNotEmpty
            ? existingTracking
            : _generateTracking(selectedCourier));
    final notesCtrl =
        TextEditingController(text: order['seller_notes']?.toString() ?? '');

    bool isShipping = false;
    String? generatedOtp;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (bsCtx) => StatefulBuilder(
        builder: (bsCtx, setS) {
          final items = List<Map<String, dynamic>>.from(
              order['order_items'] as List? ?? []);
          final totalQty = items.fold<int>(
              0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0));
          final bottomPad = MediaQuery.of(bsCtx).viewInsets.bottom;

          return Container(
            height: MediaQuery.of(bsCtx).size.height * 0.93,
            padding: EdgeInsets.only(bottom: bottomPad),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // ── drag handle ───────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ── header ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kPinkSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.local_shipping_rounded,
                            color: _kPink,
                            size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ship Order',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          Text(
                            '#${order['id']?.toString().replaceAll('-', '').substring(0, 8).toUpperCase() ?? ''}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(bsCtx),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade100),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── body ──────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: generatedOtp != null
                        // ── SUCCESS STATE ──────────────────────────
                        ? _shipSuccessCard(
                            otp: generatedOtp!,
                            order: order,
                            bsCtx: bsCtx)
                        // ── FORM STATE ─────────────────────────────
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // buyer / address card
                              _shipSectionLabel('Delivery Info'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FB),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    _shipInfoRow(
                                        Icons.person_outline_rounded,
                                        order['buyer_name']
                                                ?.toString() ??
                                            '—'),
                                    if ((order['buyer_phone']
                                                ?.toString()
                                                .isNotEmpty ??
                                            false)) ...[  
                                      const SizedBox(height: 6),
                                      _shipInfoRow(
                                          Icons.phone_outlined,
                                          order['buyer_phone']
                                              .toString()),
                                    ],
                                    const SizedBox(height: 6),
                                    _shipInfoRow(
                                      Icons.location_on_outlined,
                                      [
                                        order['shipping_address'],
                                        order['shipping_city'],
                                        order[
                                            'shipping_postal_code'],
                                      ]
                                          .where((v) =>
                                              v != null &&
                                              v
                                                  .toString()
                                                  .isNotEmpty)
                                          .join(', '),
                                    ),
                                    const SizedBox(height: 6),
                                    _shipInfoRow(
                                      Icons.inventory_2_outlined,
                                      '$totalQty item${totalQty == 1 ? '' : 's'}',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),

                              // courier cards
                              _shipSectionLabel('Select Courier'),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 76,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _couriers.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final c = _couriers[i];
                                    final sel = c == selectedCourier;
                                    return GestureDetector(
                                      onTap: () => setS(() {
                                        selectedCourier = c;
                                        trackCtrl.text =
                                            _generateTracking(c);
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 180),
                                        width: 72,
                                        decoration: BoxDecoration(
                                          color: sel
                                              ? _kPink
                                              : Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  14),
                                          border: Border.all(
                                            color: sel
                                                ? _kPinkDark
                                                : Colors
                                                    .grey.shade200,
                                            width: sel ? 2 : 1,
                                          ),
                                          boxShadow: sel
                                              ? [
                                                  BoxShadow(
                                                    color: _kPink
                                                        .withOpacity(
                                                            0.28),
                                                    blurRadius: 10,
                                                    offset:
                                                        const Offset(
                                                            0, 4),
                                                  )
                                                ]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _courierAbbr[c] ??
                                                c
                                                    .substring(0, 3)
                                                    .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color: sel
                                                  ? Colors.white
                                                  : Colors
                                                      .grey.shade700,
                                            ),
                                            textAlign:
                                                TextAlign.center,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: Colors.teal),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Est. delivery: ${_estimatedDelivery(selectedCourier)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              // tracking number
                              _shipSectionLabel('Tracking Number'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: trackCtrl,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                            Icons.pin_outlined,
                                            color: _kPink),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    12)),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              const BorderSide(
                                                  color: _kPink,
                                                  width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Copy',
                                    child: IconButton(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: trackCtrl.text));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content:
                                              Text('Tracking copied!'),
                                          duration:
                                              Duration(seconds: 1),
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ));
                                      },
                                      icon: const Icon(
                                          Icons.copy_rounded,
                                          color: _kPink),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _kPinkSoft,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10)),
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message: 'Regenerate',
                                    child: IconButton(
                                      onPressed: () => setS(() =>
                                          trackCtrl.text =
                                              _generateTracking(
                                                  selectedCourier)),
                                      icon: const Icon(
                                          Icons.refresh_rounded,
                                          color: _kPink),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _kPinkSoft,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              // notes
                              _shipSectionLabel(
                                  'Notes to Buyer (optional)'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: notesCtrl,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText:
                                      'e.g. Handle with care, fragile…',
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(bottom: 44),
                                    child: Icon(Icons.note_outlined,
                                        color: _kPink),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: _kPink, width: 2),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.all(14),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ship button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  onPressed: isShipping
                                      ? null
                                      : () async {
                                          if (trackCtrl.text
                                              .trim()
                                              .isEmpty) return;
                                          setS(() => isShipping = true);
                                          try {
                                            final orderId =
                                                order['id'] as String;
                                            await _updateStatus(
                                                orderId, 'shipped', {
                                              'tracking_number':
                                                  trackCtrl.text.trim(),
                                              'courier': selectedCourier,
                                              'seller_notes':
                                                  notesCtrl.text.trim(),
                                              'shipped_at': DateTime.now()
                                                  .toIso8601String(),
                                            });
                                            // Remember this courier for next time
                                            await _savePreferredCourier(
                                                selectedCourier);
                                            String? otp;
                                            try {
                                              otp = await _svc
                                                  .generateDeliveryOtp(
                                                      orderId: orderId);
                                            } catch (_) {}
                                            if (mounted) {
                                              setS(() {
                                                generatedOtp = otp ?? '—';
                                                isShipping = false;
                                              });
                                            }
                                          } catch (_) {
                                            if (mounted) {
                                              setS(() =>
                                                  isShipping = false);
                                            }
                                          }
                                        },
                                  icon: isShipping
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(
                                          Icons.local_shipping_rounded,
                                          size: 20),
                                  label: Text(
                                    isShipping
                                        ? 'Processing…'
                                        : 'Ship Order',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kPink,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _kPink.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  '✓ Tracking & delivery OTP auto-generated on ship',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── ship dialog helpers ───────────────────────────────────────────────────

  Widget _shipSuccessCard({
    required String otp,
    required Map<String, dynamic> order,
    required BuildContext bsCtx,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 52),
                const SizedBox(height: 10),
                const Text('Order Shipped!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Status updated & OTP generated automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // OTP card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _kPinkSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPinkLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_rounded, color: _kPink, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Packing Slip OTP',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(otp,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 7,
                              color: _kPink)),
                      Text('Print this on the packing slip.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: otp)),
                  icon: const Icon(Icons.copy_rounded, color: _kPink),
                  tooltip: 'Copy OTP',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(bsCtx);
                    await _printWaybill(order);
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print Waybill'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPink,
                    side: const BorderSide(color: _kPink),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(bsCtx),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      );

  Widget _shipSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151)),
      );

  Widget _shipInfoRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      );

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: _kPink),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPink, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Future<void> _updateStatus(
      String orderId, String status, Map<String, dynamic> extra) async {
    try {
      final updates = <String, dynamic>{'status': status, ...extra};
      if (status == 'delivered') {
        updates['delivered_at'] = DateTime.now().toIso8601String();
      }
      await _client.from('orders').update(updates).eq('id', orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Order marked as ${_statusLabel(status)} ✓'),
          backgroundColor: _statusColor(status),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── print waybill ─────────────────────────────────────────────────────────
  Future<void> _printWaybill(Map<String, dynamic> order) async {
    try {
      // Try to fetch the seller's business profile for the "FROM" block.
      Map<String, dynamic>? shopInfo;
      try {
        final myUid = _client.auth.currentUser?.id;
        if (myUid != null) {
          final res = await _client
              .from('accounts')
              .select(
                  'business_name, full_name, phone, business_phone, business_address')
              .eq('id', myUid)
              .maybeSingle();
          if (res != null) {
            shopInfo = {
              'business_name': res['business_name'] ?? res['full_name'],
              'phone': res['business_phone'] ?? res['phone'],
              'address': res['business_address'],
            };
          }
        }
      } catch (_) {
        // Non-fatal — fall back to defaults.
      }

      if (!mounted) return;
      // Show preview screen first; user can then print/share/download.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              WaybillPreviewScreen(order: order, shopInfo: shopInfo),
        ),
      );
    } catch (e, st) {
      debugPrint('Waybill error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open waybill: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── open delivery confirmation ──────────────────────────────────────────
  Future<void> _openDeliveryConfirmation(Map<String, dynamic> order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryConfirmationPage(
          orderId:        order['id']?.toString() ?? '',
          trackingNumber: order['tracking_number']?.toString(),
          courierName:    order['courier']?.toString(),
          buyerName:      order['buyer_name']?.toString(),
          shippingAddress: [
            order['shipping_address'],
            order['shipping_city'],
            order['shipping_postal_code'],
          ].where((v) => v != null && v.toString().isNotEmpty).join(', '),
        ),
      ),
    );
    // Reload orders after returning (status may have auto-changed)
    await _load();
  }

  // ── cancel order ──────────────────────────────────────────────────────────
  // ── chat with customer ──────────────────────────────────────────────────
  Future<void> _openChat(Map<String, dynamic> order) async {
    final myUid = _client.auth.currentUser?.id;
    final buyerId = order['buyer_id']?.toString();
    final buyerName = order['buyer_name']?.toString() ?? 'Customer';
    if (myUid == null || buyerId == null) return;
    // look up existing conversation or create one
    try {
      Map<String, dynamic>? convo;
      final existing = await _client
          .from('chat_conversations')
          .select('id')
          .eq('seller_id', myUid)
          .eq('buyer_id', buyerId)
          .maybeSingle();
      if (existing != null) {
        convo = Map<String, dynamic>.from(existing);
      } else {
        final inserted = await _client
            .from('chat_conversations')
            .insert({'seller_id': myUid, 'buyer_id': buyerId})
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
            otherDisplayName: buyerName,
            currentUserIsSeller: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order?'),
        content:
            const Text('This will mark the order as cancelled. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateStatus(order['id'] as String, 'canceled', {});
    }
  }

  Future<void> _refundOrder(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Issue Refund?'),
        content: const Text(
            'Mark this order as refunded. The buyer will see the updated status. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Refund', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateStatus(order['id'] as String, 'refunded', {});
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // LayoutBuilder causes a re-entrant layout error when this widget is a
    // child of AnimatedSwitcher (which lays out both old and new children via
    // a Stack simultaneously).  Use MediaQuery directly so no nested layout
    // call is issued.
    final mq = MediaQuery.of(context);
    final effectiveHeight = mq.size.height -
        kToolbarHeight -
        kBottomNavigationBarHeight -
        mq.padding.vertical;
    return SizedBox(
      height: effectiveHeight,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: _kPinkDark,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: _kPink,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            tabs: _tabStatuses.map((s) {
              final count = _filtered(s).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tabLabel(s)),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Body
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kPink))
              : _error != null
                  ? _buildError()
                  : TabBarView(
                      controller: _tabs,
                      children: _tabStatuses.map((s) {
                        final list = _filtered(s);
                        if (list.isEmpty) return _buildEmpty(s);
                        return RefreshIndicator(
                          onRefresh: _load,
                          color: _kPink,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _OrderCard(
                                  order: list[i],
                                  onAdvance: () => _advanceStatus(list[i]),
                                  onCancel: () => _cancelOrder(list[i]),
                                  onChat: () => _openChat(list[i]),
                                  onPrintWaybill: () => _printWaybill(list[i]),
                                  onConfirmDelivery: () => _openDeliveryConfirmation(list[i]),
                                  onReship: () { _showShipDialog(list[i]); },
                                  onRefund: () => _refundOrder(list[i]),
                                ),
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String tab) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: _kPinkSoft, shape: BoxShape.circle),
                child: Icon(
                  _tabIcon(tab),
                  size: 40,
                  color: _kPinkLight,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tab == 'all'
                    ? 'No orders yet'
                    : 'No ${_tabLabel(tab).toLowerCase()} orders',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Orders from buyers will appear here.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Unknown error',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: _kPink),
              ),
            ],
          ),
        ),
      );
}

// ─── order card ───────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAdvance;
  final VoidCallback onCancel;
  final VoidCallback onChat;
  final VoidCallback onPrintWaybill;
  final VoidCallback onConfirmDelivery;
  final VoidCallback onReship;
  final VoidCallback onRefund;

  const _OrderCard({
    required this.order,
    required this.onAdvance,
    required this.onCancel,
    required this.onChat,
    required this.onPrintWaybill,
    required this.onConfirmDelivery,
    required this.onReship,
    required this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] as String? ?? 'pending');
    final color = _statusColor(status);
    final next = _nextStatus(status);
    final isTerminal = ['delivered', 'canceled', 'refunded']
        .contains(status);
    final isFailed = status == 'failed';
    final canCancel = !isTerminal && !isFailed && status != 'shipped';

    final createdAt = DateTime.tryParse(
            order['created_at']?.toString() ?? '') ??
        DateTime.now();
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final currency = order['currency']?.toString() ?? 'PHP';
    final shortId =
        (order['id']?.toString() ?? '').replaceAll('-', '').substring(0, 8).toUpperCase();
    final items =
        List<Map<String, dynamic>>.from(order['order_items'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _kPink.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(_statusIcon(status), color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #$shortId',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _kPinkDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: order['id']?.toString() ?? ''));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Order ID copied'),
                                duration: Duration(seconds: 1),
                              ));
                            },
                            child: const Icon(Icons.copy_outlined,
                                size: 14, color: _kPink),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(createdAt.toLocal()),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // ── buyer info ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: _kPink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order['buyer_name']?.toString() ?? 'Unknown Buyer',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order['buyer_phone'] != null) ...[
                  const Icon(Icons.phone_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      order['buyer_phone'].toString(),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (order['shipping_address'] != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: _kPink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        order['shipping_address'],
                        order['shipping_city'],
                        order['shipping_postal_code'],
                      ].where((v) => v != null && v.toString().isNotEmpty)
                          .join(', '),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── items ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => _ItemRow(item: item)).toList(),
            ),
          ),

          // ── tracking info (if shipped) ──────────────────────────────────
          if (status == 'shipped' || status == 'delivered') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded,
                            size: 15, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text(
                          order['courier']?.toString() ?? 'Courier',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.teal),
                        ),
                      ],
                    ),
                    if ((order['tracking_number']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 21),
                          Text(
                            'Tracking: ${order['tracking_number']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => Clipboard.setData(ClipboardData(
                                text: order['tracking_number'].toString())),
                            child: const Icon(Icons.copy_outlined,
                                size: 13, color: Colors.teal),
                          ),
                        ],
                      ),
                    ],
                    if ((order['seller_notes']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 21),
                          Expanded(
                            child: Text(
                              order['seller_notes'].toString(),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── total + actions ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    Text(
                      '$currency ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kPinkDeep),
                    ),
                  ],
                ),
                const Spacer(),
                // Chat button — always visible
                IconButton(
                  onPressed: onChat,
                  tooltip: 'Chat with customer',
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      color: _kPink, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _kPinkSoft,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 4),
                // Print waybill — available once order is paid/processing/shipped
                if (!isTerminal && status != 'pending')
                  IconButton(
                    onPressed: onPrintWaybill,
                    tooltip: 'Print waybill',
                    icon: const Icon(Icons.print_rounded,
                        color: _kPink, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: _kPinkSoft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                if (!isTerminal && status != 'pending') const SizedBox(width: 4),
                // Confirm delivery button — shown for shipped orders
                if (status == 'shipped') ...[
                  ElevatedButton.icon(
                    onPressed: onConfirmDelivery,
                    icon: const Icon(Icons.verified_rounded, size: 16),
                    label: const Text('Confirm Delivery',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // View proof button — shown for delivered orders
                if (status == 'delivered') ...[
                  IconButton(
                    onPressed: onConfirmDelivery,
                    tooltip: 'View delivery proof',
                    icon: const Icon(Icons.verified_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (isFailed) ...[
                  TextButton(
                    onPressed: onRefund,
                    style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                    child: const Text('Refund', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: onReship,
                    icon: const Icon(Icons.local_shipping_rounded, size: 16),
                    label: const Text('Re-ship', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else ...[
                  if (canCancel)
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  if (next != null && status != 'shipped') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onAdvance,
                      icon: Icon(_nextIcon(next), size: 16),
                      label: Text(_nextLabel(next), style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _statusColor(next),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _nextIcon(String status) {
    switch (status) {
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      default:
        return Icons.arrow_forward;
    }
  }

  String _nextLabel(String status) {
    switch (status) {
      case 'processing':
        return 'Process';
      case 'shipped':
        return 'Ship Out';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    // Prefer stored product_name/image, fall back to joined products row for older orders
    final productJoin = item['products'] as Map?;
    final name = (item['product_name']?.toString().isNotEmpty == true
            ? item['product_name']?.toString()
            : productJoin?['name']?.toString()) ??
        'Product';
    final rawImageUrl = (item['product_image_url']?.toString().isNotEmpty == true
        ? item['product_image_url']?.toString()
        : productJoin?['image_url']?.toString());
    final imageUrl = (rawImageUrl?.isNotEmpty == true) ? rawImageUrl : null;
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final variation = item['variation_name']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                    width: 40, height: 40, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderBox())
                : _placeholderBox(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (variation != null && variation.isNotEmpty)
                  Text(variation,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '×$qty',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
          const SizedBox(width: 10),
          Text(
            '₱${(price * qty).toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kPinkDeep),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBox() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kPinkSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined, size: 20, color: _kPinkLight),
      );
}
