// lib/screens/market_tab_enhanced.dart - Enhanced market with Shopee/Lazada-like UI
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'chat_screen.dart';
import '../services/cart_service.dart';
import '../services/chat_service.dart';

class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _loadingProductId;

  // Cart state (loaded from CartService so it persists across logout)
  List<Map<String, dynamic>> _cartItems = [];
  int _cartItemCount = 0;

  // Filter state
  String? _selectedCategory;
  double _minPrice = 0;
  double _maxPrice = 10000;
  List<String> _dbCategories = [];
  String _sortBy = 'newest';
  bool _showFilters = false;
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Animation
  late AnimationController _cartAnimationController;

  @override
  void initState() {
    super.initState();
    _cartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fetchProducts();
    _loadCartFromDb();
  }

  Future<void> _loadCartFromDb() async {
    try {
      final items = await CartService.instance.loadCart();
      if (!mounted) return;
      setState(() {
        _cartItems = items;
        _cartItemCount = _cartItems.fold(
          0,
          (sum, item) => sum + (item['quantity'] as int? ?? 0),
        );
      });
    } catch (e) {
      debugPrint('Failed to load cart: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('products')
          .select(
            'id, name, price, currency, image_url, category, is_active, stock_quantity, description, business_id, variations, created_at, hex_code, shade_name, color_family',
          )
          .eq('is_active', true);

      var products = List<Map<String, dynamic>>.from(response);

      final categories = products
          .map((p) => (p['category'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      debugPrint('Products found: ${products.length}');

      if (products.isEmpty) {
        setState(() {
          _isLoading = false;
          _allProducts = [];
          _dbCategories = categories;
          _errorMessage = null;
        });
        return;
      }

      products = _applyFiltersAndSort(products);

      setState(() {
        _allProducts = products;
        _dbCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
      setState(() {
        _errorMessage = 'Failed to load products: $e';
        _isLoading = false;
        _allProducts = [];
      });
    }
  }

  List<Map<String, dynamic>> _extractVariations(Map<String, dynamic> product) {
    final rawVariations = product['variations'];
    if (rawVariations is List) {
      return rawVariations
          .whereType<Map>()
          .map((variation) => Map<String, dynamic>.from(variation))
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _applyFiltersAndSort(
    List<Map<String, dynamic>> products,
  ) {
    var filtered = List<Map<String, dynamic>>.from(products);

    if (_selectedCategory != null &&
        _selectedCategory!.isNotEmpty &&
        _selectedCategory != 'All') {
      filtered = filtered
          .where(
            (p) =>
                (p['category'] ?? '').toString().toLowerCase() ==
                _selectedCategory!.toLowerCase(),
          )
          .toList();
    }

    filtered = filtered.where((p) {
      final price = (p['price'] ?? 0).toDouble();
      return price >= _minPrice && price <= _maxPrice;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final category = (p['category'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || category.contains(query);
      }).toList();
    }

    switch (_sortBy) {
      case 'price_asc':
        filtered.sort(
          (a, b) => (a['price'] as num).compareTo(b['price'] as num),
        );
        break;
      case 'price_desc':
        filtered.sort(
          (a, b) => (b['price'] as num).compareTo(a['price'] as num),
        );
        break;
      case 'newest':
        filtered.sort((a, b) {
          final aDate = a['created_at'] != null
              ? DateTime.tryParse(a['created_at'].toString())
              : null;
          final bDate = b['created_at'] != null
              ? DateTime.tryParse(b['created_at'].toString())
              : null;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        break;

      case 'oldest':
        filtered.sort((a, b) {
          final aDate = a['created_at'] != null
              ? DateTime.tryParse(a['created_at'].toString())
              : null;
          final bDate = b['created_at'] != null
              ? DateTime.tryParse(b['created_at'].toString())
              : null;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
        break;

      default:
        break;
    }

    return filtered;
  }

  Future<void> _addToCart(
    Map<String, dynamic> product, {
    Map<String, dynamic>? variation,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add items to your cart.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await CartService.instance.addItem(
        productId: product['id'].toString(),
        quantity: 1,
        variation: variation,
      );
      await _loadCartFromDb();
      if (!mounted) return;
      // Play a quick bump animation: forward then reverse on completion.
      _cartAnimationController
          .forward(from: 0)
          .then((_) {
        if (mounted) _cartAnimationController.reverse();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Added to cart: ${product['name']}')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _buyNow(
    Map<String, dynamic> product, {
    Map<String, dynamic>? variation,
  }) async {
    // Create a single-item cart and proceed to checkout
    final singleItem = [
      {
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'image_url': product['image_url'],
        'business_id': product['business_id'],
        'quantity': 1,
        'variation': variation,
      },
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CheckoutScreen(cartItems: singleItem, onCheckoutComplete: () {}),
      ),
    );
  }

  Future<void> _openChatWithSeller(Map<String, dynamic> product) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to chat with the seller.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final sellerId = product['business_id']?.toString() ??
        await ChatService.instance.getDefaultSellerId();
    if (sellerId == null || sellerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No seller is available right now.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (sellerId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can't chat with yourself."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final conv = await ChatService.instance.getOrCreateConversation(
        sellerId: sellerId,
        productId: product['id']?.toString(),
      );
      if (conv == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conv['id'].toString(),
            otherDisplayName: 'Fashion 21',
            productId: product['id']?.toString(),
            productName: product['name']?.toString(),
            productImage: product['image_url']?.toString(),
            productPrice: product['price'] is num
                ? (product['price'] as num).toDouble()
                : double.tryParse(product['price']?.toString() ?? ''),
            productCurrency: product['currency']?.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper for readable contrast on chips
  Color _contrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  List<Map<String, dynamic>> get _marketCategories {
    return [
      {'name': 'All', 'icon': Icons.grid_view, 'color': 0xFFFF4D97},
      ..._dbCategories.map((category) {
        return {
          'name': category,
          'icon': _iconForCategory(category),
          'color': _colorForCategory(category),
        };
      }),
    ];
  }

  IconData _iconForCategory(String category) {
    final c = category.toLowerCase();

    if (c.contains('lip')) return Icons.color_lens;
    if (c.contains('blush')) return Icons.brush;
    if (c.contains('foundation')) return Icons.opacity;
    if (c.contains('concealer')) return Icons.face;
    if (c.contains('eyeshadow')) return Icons.visibility;
    if (c.contains('eyeliner')) return Icons.draw;
    if (c.contains('mascara')) return Icons.remove_red_eye;
    if (c.contains('tool') || c.contains('brush')) return Icons.build;
    if (c.contains('setting')) return Icons.spa;

    return Icons.shopping_bag_outlined;
  }

  int _colorForCategory(String category) {
    final c = category.toLowerCase();

    if (c.contains('lip')) return 0xFFE91E63;
    if (c.contains('blush')) return 0xFFF48FB1;
    if (c.contains('foundation')) return 0xFFD2B48C;
    if (c.contains('concealer')) return 0xFFF5DEB3;
    if (c.contains('eyeshadow')) return 0xFF9C27B0;
    if (c.contains('eyeliner')) return 0xFF3F51B5;
    if (c.contains('mascara')) return 0xFF009688;
    if (c.contains('tool') || c.contains('brush')) return 0xFF607D8B;
    if (c.contains('setting')) return 0xFFFF9800;

    return 0xFFFF4D97;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Shopee-style App Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFFF4D97),
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 16,
                title: Row(
                  children: [
                    const Icon(Icons.store, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Fashion21 Marketplace',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Official Fashion21 products',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartScreen(),
                              ),
                            );
                            if (mounted) await _loadCartFromDb();
                          },
                        ),
                        if (_cartItemCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _cartItemCount > 9
                                    ? '9+'
                                    : '$_cartItemCount',
                                style: const TextStyle(
                                  color: Color(0xFFFF4D97),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                            _fetchProducts();
                          });
                        },
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade500,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _fetchProducts();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Grid - Shopee Style
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _marketCategories.length,
                          itemBuilder: (context, index) {
                            final category = _marketCategories[index];
                            final isSelected =
                                _selectedCategory == category['name'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category['name'] == 'All'
                                      ? null
                                      : category['name'];
                                  _fetchProducts();
                                });
                              },
                              child: Container(
                                width: 70,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFFF4D97)
                                                .withOpacity(0.15)
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(25),
                                        border: isSelected
                                            ? Border.all(
                                                color: const Color(0xFFFF4D97),
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: Icon(
                                        category['icon'] as IconData,
                                        color: isSelected
                                            ? const Color(0xFFFF4D97)
                                            : Color(category['color'] as int),
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      category['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? const Color(0xFFFF4D97)
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Filter Row
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildFilterButton(
                                    icon: Icons.filter_list,
                                    label: 'Filters',
                                    isActive: _showFilters,
                                    onTap: () => setState(
                                      () => _showFilters = !_showFilters,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildFilterButton(
                                    icon: Icons.sort,
                                    label: _getSortLabel(),
                                    isActive: false,
                                    onTap: () => _showSortDialog(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filter Panel
                    if (_showFilters)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Price Range',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _minPrice = 0;
                                      _maxPrice = 10000;
                                      _fetchProducts();
                                    });
                                  },
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFFF4D97),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            RangeSlider(
                              values: RangeValues(
                                _minPrice.clamp(0, 10000),
                                _maxPrice.clamp(0, 10000),
                              ),
                              min: 0,
                              max: 10000,
                              divisions: 100,
                              labels: RangeLabels(
                                '₱${_minPrice.toStringAsFixed(0)}',
                                '₱${_maxPrice.toStringAsFixed(0)}',
                              ),
                              onChanged: (values) {
                                setState(() {
                                  _minPrice = values.start;
                                  _maxPrice = values.end;
                                });
                              },
                              onChangeEnd: (values) => _fetchProducts(),
                              activeColor: const Color(0xFFFF4D97),
                              inactiveColor: Colors.grey.shade300,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₱${_minPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '₱${_maxPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Product Count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _isLoading
                            ? 'Loading...'
                            : '${_allProducts.length} Products',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Products Grid
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4D97)),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchProducts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4D97),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_allProducts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try adjusting your search or filters'
                              : 'Products will appear here once added',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty ||
                            _selectedCategory != null) ...[
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _selectedCategory = null;
                                _minPrice = 0;
                                _maxPrice = 10000;
                                _fetchProducts();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFF4D97)),
                              foregroundColor: const Color(0xFFFF4D97),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Clear All Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildShopeeStyleCard(
                        context,
                        _allProducts[index],
                      ),
                      childCount: _allProducts.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // Floating chat-with-seller bubble
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'market_chat_fab',
              backgroundColor: const Color(0xFFFF4D97),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text(
                'Chat with Seller',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _openChatWithSeller(const {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF4D97).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFFFF4D97) : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFFF4D97)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'newest':
        return 'Newest';
      case 'oldest':
        return 'Oldest';
      case 'price_asc':
        return 'Price: Low to High';
      case 'price_desc':
        return 'Price: High to Low';
      default:
        return 'Sort';
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7FA),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD3E5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF171725),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSortOption('Newest', 'newest'),
                _buildSortOption('Oldest', 'oldest'),
                _buildSortOption('Price: Low to High', 'price_asc'),
                _buildSortOption('Price: High to Low', 'price_desc'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFFE5F0)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF4D97)
              : const Color(0xFFFFD8E8),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected
                ? const Color(0xFFFF3D93)
                : const Color(0xFF33333A),
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFFF3D93),
                size: 22,
              )
            : null,
        onTap: () {
          setState(() => _sortBy = value);
          Navigator.pop(context);
          _fetchProducts();
        },
      ),
    );
  }

  Widget _buildShopeeStyleCard(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final name = product['name']?.toString() ?? 'Unnamed Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url']?.toString();
    final shadeName = product['shade_name']?.toString() ?? '';
    final hexCode = product['hex_code']?.toString() ?? '';
    final shadeColor = _safeParseColor(hexCode);
    final stockQuantity = (product['stock_quantity'] as int?) ?? 0;
    final isLoading = _loadingProductId == product['id']?.toString();
    final isOutOfStock = stockQuantity <= 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      child: InkWell(
        onTap: () => _showProductDetail(context, product),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD8E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.12,
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: imageUrl == null || imageUrl.isEmpty
                          ? const Icon(
                              Icons.image_outlined,
                              size: 42,
                              color: Colors.grey,
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                size: 42,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  if (isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.70),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: Color(0xFF171725),
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '₱${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFFF3D93),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 5),

                      if (shadeName.isNotEmpty || shadeColor != null)
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: shadeColor ?? const Color(0xFFFFD3E5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.08),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                shadeName.isEmpty ? 'Shade' : shadeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),

                      const Spacer(),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: OutlinedButton(
                                onPressed: isOutOfStock
                                    ? null
                                    : () => _addToCart(product),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFFF4D97),
                                  ),
                                  padding: EdgeInsets.zero,
                                  foregroundColor: const Color(0xFFFF4D97),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 13,
                                        width: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFF4D97),
                                        ),
                                      )
                                    : const Text(
                                        'Cart',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                onPressed:
                                    isOutOfStock ? null : () => _buyNow(product),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4D97),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 13,
                                        width: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Buy',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetail(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProductDetailModal(context, product),
    );
  }

  Widget _buildProductDetailModal(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final name = product['name']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url']?.toString();
    final description = product['description']?.toString() ?? '';
    final stockQuantity = (product['stock_quantity'] as int?) ?? 0;
    final category = product['category']?.toString() ?? '';
    final variations = _extractVariations(product);

    final isOutOfStock = stockQuantity <= 0;
    int selectedQuantity = 1;
    Map<String, dynamic>? selectedVariation;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setModalState) {
          double getTotalPrice() {
            if (selectedVariation != null &&
                selectedVariation!['price'] != null) {
              return (selectedVariation!['price'] as num).toDouble() *
                  selectedQuantity;
            }
            return price * selectedQuantity;
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 1, // square — like Shopee/Lazada
                        child: Container(
                          width: double.infinity,
                          color: Colors.grey[100],
                          child: imageUrl == null || imageUrl.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₱${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFFFF4D97),
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            if (category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF4D97,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Color(0xFFFF4D97),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOutOfStock
                              ? 'Out of Stock'
                              : 'In Stock ($stockQuantity available)',
                          style: TextStyle(
                            color: isOutOfStock ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (description.isNotEmpty) ...[
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (variations.isNotEmpty) ...[
                          const Text(
                            'Select Variation',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: variations.map((variation) {
                              final colorName =
                                  (variation['color_name'] ??
                                          variation['name'] ??
                                          'Variant')
                                      .toString();
                              final hexCode = (variation['hex_code'] ?? '')
                                  .toString();
                              final varPrice = variation['price'];
                              final varStock = variation['stock'];
                              final isSelected = selectedVariation == variation;
                              final varOutOfStock = (varStock as int?) == 0;
                              final chipColor =
                                  _safeParseColor(hexCode) ??
                                  const Color(0xFFFF4D97);
                              final stockLabel = varOutOfStock
                                  ? 'Out of stock'
                                  : 'Stock: ${varStock ?? 0}';

                              // Use contrast helper for readable text
                              final contrast = _contrastColor(chipColor);

                              return FilterChip(
                                label: Column(
                                  children: [
                                    Text(
                                      colorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: isSelected
                                            ? contrast
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (varPrice != null)
                                      Text(
                                        '₱${varPrice.toString()}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? contrast.withOpacity(0.8)
                                              : Colors.black54,
                                        ),
                                      ),
                                    Text(
                                      stockLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? contrast.withOpacity(0.8)
                                            : (varOutOfStock
                                                  ? Colors.red.shade400
                                                  : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: varOutOfStock
                                    ? null
                                    : (selected) => setModalState(
                                        () => selectedVariation = selected
                                            ? variation
                                            : null,
                                      ),
                                backgroundColor: chipColor.withOpacity(0.15),
                                selectedColor: chipColor,
                                side: BorderSide(
                                  color: isSelected
                                      ? chipColor
                                      : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!isOutOfStock) ...[
                          const Text(
                            'Quantity',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: () => setModalState(() {
                                        if (selectedQuantity > 1) {
                                          selectedQuantity--;
                                        }
                                      }),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                    ),
                                    Container(
                                      width: 40,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$selectedQuantity',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () {
                                        final maxStock =
                                            selectedVariation != null
                                            ? (selectedVariation!['stock']
                                                      as int? ??
                                                  stockQuantity)
                                            : stockQuantity;
                                        if (selectedQuantity < maxStock) {
                                          setModalState(
                                            () => selectedQuantity++,
                                          );
                                        }
                                      },
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${(selectedVariation != null ? (selectedVariation!['stock'] as int? ?? stockQuantity) : stockQuantity)} available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '₱${getTotalPrice().toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Color(0xFFFF4D97),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Chat with Seller row
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openChatWithSeller(product);
                            },
                            icon: const Icon(Icons.chat_bubble_outline,
                                size: 18),
                            label: const Text(
                              'Chat with Seller',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Action Buttons - FIXED with explicit foregroundColor
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isOutOfStock
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _addToCart(
                                          product,
                                          variation: selectedVariation,
                                        );
                                      },
                                icon: const Icon(Icons.shopping_cart, size: 18),
                                label: const Text(
                                  'Add to Cart',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF4D97),
                                  side: const BorderSide(
                                    color: Color(0xFFFF4D97),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isOutOfStock
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _buyNow(
                                          product,
                                          variation: selectedVariation,
                                        );
                                      },
                                icon: const Icon(Icons.flash_on, size: 18),
                                label: const Text(
                                  'Buy Now',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4D97),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color? _safeParseColor(String hexCode) {
    final value = hexCode.trim();
    if (value.isEmpty) return null;
    var normalized = value.replaceAll('#', '').trim();
    if (normalized.length == 6) normalized = 'FF$normalized';
    if (normalized.length != 8) return null;
    try {
      return Color(int.parse(normalized, radix: 16));
    } catch (_) {
      return null;
    }
  }
}