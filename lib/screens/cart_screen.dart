import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  final Set<String> _selectedIds = {}; // uses cart_id as key
  bool _isLoading = true;
  bool _isBusy = false;

  static const _pink = Color(0xFFFF4D97);

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    final items = await CartService.instance.loadCart();
    if (!mounted) return;
    setState(() {
      _cartItems = items;
      // Remove selected ids that no longer exist
      _selectedIds.retainWhere(
        (id) => items.any((i) => i['cart_id'].toString() == id),
      );
      _isLoading = false;
    });
  }

  // ── Selection helpers ────────────────────────────────────────────────────

  bool get _allSelected =>
      _cartItems.isNotEmpty &&
      _cartItems.every((i) => _selectedIds.contains(i['cart_id'].toString()));

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        for (final item in _cartItems) {
          _selectedIds.add(item['cart_id'].toString());
        }
      }
    });
  }

  void _toggleItem(String cartId) {
    setState(() {
      if (_selectedIds.contains(cartId)) {
        _selectedIds.remove(cartId);
      } else {
        _selectedIds.add(cartId);
      }
    });
  }

  // ── Cart operations ──────────────────────────────────────────────────────

  Future<void> _updateQuantity(Map<String, dynamic> item, int delta) async {
    final cartId = item['cart_id'].toString();
    final newQty = (item['quantity'] as int) + delta;
    if (newQty <= 0) {
      await _removeItem(cartId);
      return;
    }
    await CartService.instance.updateQuantity(cartId, newQty);
    await _loadCart();
  }

  Future<void> _removeItem(String cartId) async {
    await CartService.instance.removeItem(cartId);
    _selectedIds.remove(cartId);
    await _loadCart();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await _confirmDelete(
      'Remove ${_selectedIds.length} item${_selectedIds.length > 1 ? 's' : ''}',
      'Remove selected items from your cart?',
    );
    if (!confirmed) return;
    setState(() => _isBusy = true);
    for (final id in List<String>.from(_selectedIds)) {
      await CartService.instance.removeItem(id);
    }
    _selectedIds.clear();
    await _loadCart();
    setState(() => _isBusy = false);
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Totals ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _selectedItems => _cartItems
      .where((i) => _selectedIds.contains(i['cart_id'].toString()))
      .toList();

  double get _selectedTotal => _selectedItems.fold(
        0.0,
        (sum, i) =>
            sum + (i['price'] as num).toDouble() * (i['quantity'] as int),
      );

  void _checkoutSelected() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one item to checkout.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: _selectedItems,
          onCheckoutComplete: () async {
            // Remove checked-out items from cart
            for (final item in _selectedItems) {
              await CartService.instance.removeItem(
                item['cart_id'].toString(),
              );
            }
            if (!mounted) return;
            setState(() => _selectedIds.clear());
            await _loadCart();
          },
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _cartItems.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSelectionBar(),
                    Expanded(child: _buildItemList()),
                    _buildCheckoutBar(),
                  ],
                ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _pink,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Cart',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (_cartItems.isNotEmpty)
            Text(
              '${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
        ],
      ),
      actions: [
        if (_selectedIds.isNotEmpty)
          IconButton(
            tooltip: 'Delete selected',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _isBusy ? null : _deleteSelected,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleSelectAll,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _allSelected ? _pink : Colors.transparent,
                    border: Border.all(
                      color: _allSelected ? _pink : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: _allSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  _allSelected ? 'Deselect All' : 'Select All',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _allSelected ? _pink : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _pink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _pink.withOpacity(0.3)),
              ),
              child: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(
                  color: _pink,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _cartItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildCartCard(_cartItems[index]),
    );
  }

  Widget _buildCartCard(Map<String, dynamic> item) {
    final cartId = item['cart_id'].toString();
    final isSelected = _selectedIds.contains(cartId);
    final price = (item['price'] as num).toDouble();
    final qty = item['quantity'] as int;
    final variation = item['variation'] as Map?;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        final imageSize = isNarrow ? 60.0 : 72.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _pink : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _pink.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleItem(cartId),
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 10 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox circle — vertically centered on the left side
                  GestureDetector(
                    onTap: () => _toggleItem(cartId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _pink : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? _pink : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      color: Colors.grey.shade100,
                      child: item['image_url'] != null &&
                              item['image_url'].toString().isNotEmpty
                          ? Image.network(
                              item['image_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 28,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              size: 30,
                              color: Colors.grey,
                            ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Info column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Product',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (variation != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _pink.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: _pink.withOpacity(0.25)),
                            ),
                            child: Text(
                              '${variation['color_name'] ?? 'Variant'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _pink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Price + total — wraps on narrow widths
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '₱${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _pink,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Total: ₱${(price * qty).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Qty stepper
                        Row(
                          children: [
                            _QtyButton(
                              icon: qty <= 1
                                  ? Icons.delete_outline
                                  : Icons.remove,
                              color:
                                  qty <= 1 ? Colors.red : Colors.grey.shade600,
                              onTap: () => _updateQuantity(item, -1),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              color: _pink,
                              onTap: () => _updateQuantity(item, 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBar() {
    final hasSelection = _selectedIds.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSelection) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Selected (${_selectedIds.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '₱${_selectedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _pink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Shipping fee calculated at checkout',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 340;
                final checkoutBtn = ElevatedButton.icon(
                  onPressed: hasSelection ? _checkoutSelected : null,
                  icon: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 18,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasSelection
                          ? 'Checkout (${_selectedIds.length})'
                          : 'Select items to checkout',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasSelection ? _pink : Colors.grey.shade300,
                    foregroundColor: hasSelection
                        ? Colors.white
                        : Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: hasSelection ? 2 : 0,
                  ),
                );

                final removeBtn = OutlinedButton.icon(
                  onPressed: _isBusy ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );

                if (!hasSelection) {
                  return SizedBox(
                    width: double.infinity,
                    child: checkoutBtn,
                  );
                }

                if (isNarrow) {
                  // Stack vertically on tiny phones
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: checkoutBtn),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: removeBtn),
                    ],
                  );
                }

                return Row(
                  children: [
                    removeBtn,
                    const SizedBox(width: 10),
                    Expanded(child: checkoutBtn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _pink.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: _pink,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products from the marketplace\nto see them here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Browse Marketplace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small helper widget ──────────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
