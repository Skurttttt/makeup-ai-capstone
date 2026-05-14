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
  double _maxPrice = 100000;
  String _sortBy = 'newest';
  bool _showFilters = false;
  Map<String, double> _categoryMaxPrices = {};
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Quick category chips - Shopee style
  final List<Map<String, dynamic>> _quickCategories = [
    {'name': 'All', 'icon': Icons.grid_view, 'color': 0xFFFF4D97},
    {'name': 'Lipstick', 'icon': Icons.color_lens, 'color': 0xFFE91E63},
    {'name': 'Blush', 'icon': Icons.brush, 'color': 0xFFF48FB1},
    {'name': 'Foundation', 'icon': Icons.opacity, 'color': 0xFFD2B48C},
    {'name': 'Concealer', 'icon': Icons.face, 'color': 0xFFF5DEB3},
    {'name': 'Eyeshadow', 'icon': Icons.visibility, 'color': 0xFF9C27B0},
    {'name': 'Eyeliner', 'icon': Icons.draw, 'color': 0xFF3F51B5},
    {'name': 'Mascara', 'icon': Icons.remove_red_eye, 'color': 0xFF009688},
    {'name': 'Tools', 'icon': Icons.build, 'color': 0xFF607D8B},
  ];

  // Featured products

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
      var query = Supabase.instance.client
          .from('products')
          .select(
            'id, name, price, currency, image_url, category, is_active, stock_quantity, description, business_id, variations, created_at',
          )
          .eq('is_active', true);

      final response = await query;
      var products = List<Map<String, dynamic>>.from(response);

      debugPrint('Products found: ${products.length}');

      if (products.isEmpty) {
        setState(() {
          _isLoading = false;
          _allProducts = [];
          _errorMessage = null;
        });
        return;
      }

      products = _applyFiltersAndSort(products);
      _calculateCategoryMaxPrices(products);

      setState(() {
        _allProducts = products;
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
      default:
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
    }

    return filtered;
  }

  void _calculateCategoryMaxPrices(List<Map<String, dynamic>> products) {
    Map<String, double> maxPrices = {};
    for (var product in products) {
      final category = (product['category'] ?? 'Other').toString();
      final price = (product['price'] ?? 0).toDouble();
      if (!maxPrices.containsKey(category) || price > maxPrices[category]!) {
        maxPrices[category] = price;
      }
    }
    if (mounted) {
      setState(() {
        _categoryMaxPrices = maxPrices;
        if (maxPrices.values.isNotEmpty) {
          _maxPrice = maxPrices.values.reduce((a, b) => a > b ? a : b);
        }
      });
    }
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 360;
                          final tileWidth = isNarrow ? 60.0 : 70.0;
                          final iconBox = isNarrow ? 44.0 : 50.0;
                          final iconSize = isNarrow ? 24.0 : 28.0;
                          final rowHeight = isNarrow ? 82.0 : 90.0;
                          return SizedBox(
                            height: rowHeight,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _quickCategories.length,
                              itemBuilder: (context, index) {
                                final category = _quickCategories[index];
                                final isSelected =
                                    _selectedCategory == category['name'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory =
                                          category['name'] == 'All'
                                              ? null
                                              : category['name'];
                                      _fetchProducts();
                                    });
                                  },
                                  child: Container(
                                    width: tileWidth,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: iconBox,
                                          height: iconBox,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFFF4D97)
                                                    .withOpacity(0.15)
                                                : Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                                iconBox / 2),
                                            border: isSelected
                                                ? Border.all(
                                                    color: const Color(
                                                        0xFFFF4D97),
                                                    width: 2,
                                                  )
                                                : null,
                                          ),
                                          child: Icon(
                                            category['icon'] as IconData,
                                            color: isSelected
                                                ? const Color(0xFFFF4D97)
                                                : Color(
                                                    category['color'] as int),
                                            size: iconSize,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          category['name'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: isNarrow ? 10 : 11,
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
                          );
                        },
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
                                      _maxPrice = _categoryMaxPrices.isEmpty
                                          ? 100000
                                          : _categoryMaxPrices.values.reduce(
                                              (a, b) => a > b ? a : b,
                                            );
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
                              values: RangeValues(_minPrice, _maxPrice),
                              min: 0,
                              max: _categoryMaxPrices.isEmpty
                                  ? 100000
                                  : _categoryMaxPrices.values.reduce(
                                      (a, b) => a > b ? a : b,
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
                                _maxPrice = _categoryMaxPrices.isEmpty
                                    ? 100000
                                    : _categoryMaxPrices.values.reduce(
                                        (a, b) => a > b ? a : b,
                                      );
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
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      // Aim for ~170-200px wide cards. Compute column count.
                      final columns = width < 360
                          ? 2
                          : width < 600
                              ? 2
                              : width < 900
                                  ? 3
                                  : (width / 220).floor();
                      // Tune aspect ratio so card fits on every phone.
                      final aspect = width < 360 ? 0.62 : 0.66;
                      return SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: aspect,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildShopeeStyleCard(
                            context,
                            _allProducts[index],
                          ),
                          childCount: _allProducts.length,
                        ),
                      );
                    },
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Newest', 'newest'),
            _buildSortOption('Price: Low to High', 'price_asc'),
            _buildSortOption('Price: High to Low', 'price_desc'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFF4D97) : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFFFF4D97))
          : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
        _fetchProducts();
      },
    );
  }

  Widget _buildShopeeStyleCard(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final name = product['name']?.toString() ?? 'Unnamed Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url']?.toString();
    final category = product['category']?.toString();
    final stockQuantity = (product['stock_quantity'] as int?) ?? 0;
    final isLoading = _loadingProductId == product['id']?.toString();

    final isOutOfStock = stockQuantity <= 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      child: InkWell(
        onTap: () => _showProductDetail(context, product),
        splashColor: const Color(0xFFFF4D97).withOpacity(0.08),
        highlightColor: const Color(0xFFFF4D97).withOpacity(0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with badges - square, fills full card width
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: Colors.grey.shade100,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Icon(Icons.image, size: 48, color: Colors.grey)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              size: 48,
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
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Out of Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Product info — flexible so it never overflows
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '₱${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFFF4D97),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (category != null && category.isNotEmpty)
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    const Spacer(),
                    // Action buttons row — pinned to bottom
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: [
                          Expanded(
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
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFF4D97),
                                      ),
                                    )
                                  : const FittedBox(
                                      child: Text(
                                        'Cart',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFF4D97),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  isOutOfStock ? null : () => _buyNow(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D97),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const FittedBox(
                                      child: Text(
                                        'Buy',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[100],
                      ),
                      child: imageUrl == null || imageUrl.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.image,
                                size: 64,
                                color: Colors.grey,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
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

