import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==================== MAIN PRODUCT SECTION ====================
class ClientProductsSection extends StatefulWidget {
  final Map<String, dynamic> clientData;
  final void Function(String businessId) onAddProduct;
  final void Function(Map<String, dynamic> product) onEditProduct;
  final void Function(dynamic productId, dynamic productName) onDeleteProduct;
  final Future<void> Function(Map<String, dynamic> product) onToggleProductStatus;

  const ClientProductsSection({
    super.key,
    required this.clientData,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.onToggleProductStatus,
  });

  @override
  State<ClientProductsSection> createState() => _ClientProductsSectionState();
}

class _ClientProductsSectionState extends State<ClientProductsSection>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  String _sortBy = 'Newest';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Pink theme colors
  static const Color pinkPrimary = Color(0xFFFF4D8C);
  static const Color pinkDark = Color(0xFFD6336C);
  static const Color pinkLight = Color(0xFFFFB8D4);
  static const Color pinkSoft = Color(0xFFFFF0F5);
  static const Color pinkAccent = Color(0xFFFF6B9D);
  static const Color pinkDeep = Color(0xFFC71563);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> products) {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = products;

    if (query.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = (product['name'] ?? '').toString().toLowerCase();
        final category = (product['category'] ?? '').toString().toLowerCase();
        final description = (product['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || category.contains(query) || description.contains(query);
      }).toList();
    }

    switch (_statusFilter) {
      case 'Active':
        filtered = filtered.where((p) => p['is_active'] == true).toList();
        break;
      case 'Inactive':
        filtered = filtered.where((p) => p['is_active'] != true).toList();
        break;
      case 'Low Stock':
        filtered = filtered.where((p) => (p['stock_quantity'] as int? ?? 0) <= 5 && (p['stock_quantity'] as int? ?? 0) > 0).toList();
        break;
      case 'Out of Stock':
        filtered = filtered.where((p) => (p['stock_quantity'] as int? ?? 0) == 0).toList();
        break;
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'Name':
          return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        case 'Price':
          return ((b['price'] as num?)?.toDouble() ?? 0).compareTo((a['price'] as num?)?.toDouble() ?? 0);
        case 'Stock':
          return ((b['stock_quantity'] as num?)?.toInt() ?? 0).compareTo((a['stock_quantity'] as num?)?.toInt() ?? 0);
        default:
          return 0;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_id', widget.clientData['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: pinkPrimary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 12),
                Text('Error loading products', style: TextStyle(fontSize: 16, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${snapshot.error}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final products = snapshot.data ?? [];
        final activeProducts = products.where((p) => p['is_active'] == true).toList();
        final lowStockProducts = products.where((p) => (p['stock_quantity'] as int? ?? 0) <= 5 && (p['stock_quantity'] as int? ?? 0) > 0).toList();
        final outOfStockProducts = products.where((p) => (p['stock_quantity'] as int? ?? 0) == 0).toList();
        final totalValue = products.fold(0.0, (sum, p) => sum + ((p['price'] as num?)?.toDouble() ?? 0) * ((p['stock_quantity'] as num?)?.toDouble() ?? 0));
        final filteredProducts = _applyFilters(products);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: pinkSoft.withOpacity(0.5),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(products.length, activeProducts.length),
                  const SizedBox(height: 24),
                  _buildSearchFilterSection(filteredProducts.length),
                  const SizedBox(height: 20),
                  _buildQuickStats(products.length, activeProducts.length, lowStockProducts.length, outOfStockProducts.length),
                  const SizedBox(height: 20),
                  _buildInventoryValueBanner(totalValue),
                  const SizedBox(height: 24),
                  if (filteredProducts.isEmpty)
                    _buildEmptyState()
                  else
                    _buildProductGrid(filteredProducts, context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(int totalProducts, int activeProducts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pinkDark, pinkPrimary, pinkAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: pinkPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 8)]),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Inventory ✨', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('$totalProducts total • $activeProducts active', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: pinkPrimary.withOpacity(0.3),
            child: InkWell(
              onTap: () => widget.onAddProduct(widget.clientData['id'].toString()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: pinkPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Add Product', style: TextStyle(color: pinkPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterSection(int resultCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: pinkPrimary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: pinkPrimary, size: 20),
              suffixIcon: _searchController.text.trim().isEmpty ? null : IconButton(icon: Icon(Icons.clear_rounded, color: Colors.grey.shade500, size: 18), onPressed: () { _searchController.clear(); setState(() {}); }),
              filled: true,
              fillColor: pinkSoft.withOpacity(0.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pinkLight.withOpacity(0.3))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: pinkPrimary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['All', 'Active', 'Inactive', 'Low Stock', 'Out of Stock'].map((label) {
              final isSelected = _statusFilter == label;
              return GestureDetector(
                onTap: () => setState(() => _statusFilter = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected ? LinearGradient(colors: [pinkPrimary, pinkAccent]) : null,
                    color: isSelected ? null : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                    boxShadow: isSelected ? [BoxShadow(color: pinkPrimary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : Colors.grey.shade700)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.sort_rounded, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text('Sort:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pinkSoft, borderRadius: BorderRadius.circular(6)),
                child: DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  isDense: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: pinkPrimary, size: 16),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  items: const [
                    DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'Name', child: Text('Name')),
                    DropdownMenuItem(value: 'Price', child: Text('Price')),
                    DropdownMenuItem(value: 'Stock', child: Text('Stock')),
                  ],
                  onChanged: (value) => setState(() => _sortBy = value ?? 'Newest'),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [pinkSoft, pinkLight.withOpacity(0.3)]), borderRadius: BorderRadius.circular(6)),
                child: Text('${resultCount} result${resultCount == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pinkPrimary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(int total, int active, int lowStock, int outOfStock) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(icon: Icons.inventory_2_rounded, label: 'Total', value: '$total', color: pinkPrimary)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(icon: Icons.check_circle_rounded, label: 'Active', value: '$active', color: Colors.green.shade600)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(icon: Icons.warning_amber_rounded, label: 'Low Stock', value: '$lowStock', color: Colors.orange.shade600)),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pinkDeep)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInventoryValueBanner(double totalValue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [pinkDark, pinkDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: pinkPrimary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Inventory Value', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(_formatPHP(totalValue), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
          ),
          Icon(Icons.trending_up_rounded, color: Colors.white.withOpacity(0.5), size: 28),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 1200 ? 4 : (width > 800 ? 3 : (width > 500 ? 2 : 1)),
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductCard(products[index], context),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, BuildContext context) {
    final stock = (product['stock_quantity'] as int?) ?? 0;
    final isLowStock = stock <= 5 && stock > 0;
    final isOutOfStock = stock == 0;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final productName = (product['name'] ?? 'Unnamed').toString();
    final category = (product['category'] ?? 'Uncategorized').toString();
    final isActive = product['is_active'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [pinkSoft, pinkLight.withOpacity(0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: product['image_url'] != null && product['image_url'].toString().isNotEmpty
                      ? Image.network(
                          product['image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade300, size: 32)),
                        )
                      : Center(child: Icon(Icons.inventory_2_rounded, color: pinkPrimary.withOpacity(0.3), size: 32)),
                ),
              ),
              if (isOutOfStock)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(8)),
                    child: const Text('OUT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                )
              else if (isLowStock)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(8)),
                    child: const Text('LOW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (!isActive)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          
          // Product Info - Compact
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade800, height: 1.2),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatCompactCurrency(price),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: pinkPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.red.shade50 : isLowStock ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 4, color: isOutOfStock ? Colors.red.shade600 : isLowStock ? Colors.orange.shade600 : Colors.green.shade600),
                          const SizedBox(width: 3),
                          Text(
                            '$stock',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOutOfStock ? Colors.red.shade700 : isLowStock ? Colors.orange.shade700 : Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _buildMiniActionButton(icon: Icons.edit_rounded, color: pinkPrimary, onPressed: () => widget.onEditProduct(product)),
                    const SizedBox(width: 4),
                    _buildMiniActionButton(icon: isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: isActive ? Colors.orange.shade600 : Colors.green.shade600, onPressed: () => widget.onToggleProductStatus(product)),
                    const SizedBox(width: 4),
                    _buildMiniActionButton(icon: Icons.delete_outline_rounded, color: Colors.red.shade400, onPressed: () => widget.onDeleteProduct(product['id'], productName)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: pinkLight.withOpacity(0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: pinkSoft, shape: BoxShape.circle), child: Icon(Icons.inventory_2_rounded, size: 64, color: pinkPrimary.withOpacity(0.5))),
          const SizedBox(height: 24),
          Text('No Products Yet ✨', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Start building your inventory by adding your first product', style: TextStyle(fontSize: 14, color: Colors.grey.shade500), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Material(
            color: pinkPrimary,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            shadowColor: pinkPrimary.withOpacity(0.3),
            child: InkWell(
              onTap: () => widget.onAddProduct(widget.clientData['id'].toString()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, color: Colors.white, size: 20), SizedBox(width: 8), Text('Add Your First Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(1)}K';
    }
    return _formatPHP(amount);
  }

  String _formatPHP(double amount) {
    final format = NumberFormat.currency(locale: 'fil_PH', symbol: '₱', decimalDigits: amount == amount.toInt() ? 0 : 2);
    return format.format(amount);
  }
}