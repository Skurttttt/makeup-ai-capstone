// lib/screens/market_tab_enhanced.dart - Enhanced market with Shopee/Lazada-like UI
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

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

  // Cart state
  final List<Map<String, dynamic>> _cartItems = [];
  bool _showCart = false;
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
  List<Map<String, dynamic>> _featuredProducts = [];

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

      if (_featuredProducts.isEmpty && products.isNotEmpty) {
        _featuredProducts = products
            .take(products.length > 5 ? 5 : products.length)
            .toList();
      }

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

  void _addToCart(
    Map<String, dynamic> product, {
    Map<String, dynamic>? variation,
  }) {
    setState(() {
      final cartItem = {
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'image_url': product['image_url'],
        'business_id': product['business_id'],
        'quantity': 1,
        'variation': variation,
      };

      final existingIndex = _cartItems.indexWhere(
        (item) =>
            item['id'] == cartItem['id'] &&
            (variation == null
                ? true
                : item['variation']?['color_name'] == variation['color_name']),
      );

      if (existingIndex != -1) {
        _cartItems[existingIndex]['quantity'] =
            (_cartItems[existingIndex]['quantity'] as int) + 1;
      } else {
        _cartItems.add(cartItem);
      }

      _cartItemCount = _cartItems.fold(
        0,
        (sum, item) => sum + (item['quantity'] as int),
      );

      _cartAnimationController.forward();
      _cartAnimationController.reverse();
    });

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

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _cartItemCount = _cartItems.fold(
        0,
        (sum, item) => sum + (item['quantity'] as int),
      );
      if (_cartItems.isEmpty) {
        _showCart = false;
      }
    });
  }

  void _updateCartQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
    } else {
      setState(() {
        _cartItems[index]['quantity'] = newQuantity;
        _cartItemCount = _cartItems.fold(
          0,
          (sum, item) => sum + (item['quantity'] as int),
        );
      });
    }
  }

  double get _cartTotal {
    return _cartItems.fold(
      0.0,
      (sum, item) =>
          sum + ((item['price'] as num).toDouble() * (item['quantity'] as int)),
    );
  }

  Future<void> _proceedToCheckout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: _cartItems,
          onCheckoutComplete: () {
            setState(() {
              _cartItems.clear();
              _cartItemCount = 0;
              _showCart = false;
            });
          },
        ),
      ),
    );
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
                expandedHeight: 120,
                pinned: true,
                backgroundColor: const Color(0xFFFF4D97),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF4D97), Color(0xFFFF6B9D)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.store,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Beauty Shop',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Cart Button
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                      onPressed: () => setState(
                                        () => _showCart = !_showCart,
                                      ),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                          itemCount: _quickCategories.length,
                          itemBuilder: (context, index) {
                            final category = _quickCategories[index];
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
                                            ? const Color(
                                                0xFFFF4D97,
                                              ).withOpacity(0.15)
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

                    // Flash Sale Banner
                    if (_featuredProducts.isNotEmpty) _buildFlashSaleBanner(),

                    const SizedBox(height: 16),

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
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildShopeeStyleCard(context, _allProducts[index]),
                      childCount: _allProducts.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // Cart Drawer
          if (_showCart) _buildCartDrawer(),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? const Color(0xFFFF4D97)
                    : Colors.grey.shade700,
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

  Widget _buildFlashSaleBanner() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash sale products coming soon!'),
            backgroundColor: Color(0xFFFF4D97),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4D97), Color(0xFFFF8DC7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D97).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FLASH SALE',
                            style: TextStyle(
                              color: Color(0xFFFF4D97),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Up to 50% OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Beauty Favorites',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '⏰\nLIMITED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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

    return GestureDetector(
      onTap: () => _showProductDetail(context, product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Icon(Icons.image, size: 48, color: Colors.grey)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
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

            // Product info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFFF4D97),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (category != null && category.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Action Buttons Row
                  Row(
                    children: [
                      // Add to Cart Button
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: isOutOfStock
                                ? null
                                : () => _addToCart(product),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFF4D97)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
                                : const Text(
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
                      const SizedBox(width: 8),
                      // Buy Now Button
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: isOutOfStock
                                ? null
                                : () => _buyNow(product),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D97),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
                                : const Text(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartDrawer() {
    return GestureDetector(
      onTap: () => setState(() => _showCart = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D97),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'My Cart (${_cartItems.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _showCart = false),
                        ),
                      ],
                    ),
                  ),
                  // Cart Items
                  Expanded(
                    child: _cartItems.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Your cart is empty',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              return _buildCartItem(item, index);
                            },
                          ),
                  ),
                  // Footer
                  if (_cartItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '₱${_cartTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF4D97),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shipping fee calculated at checkout',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _proceedToCheckout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D97),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final quantity = item['quantity'] as int;
    final price = (item['price'] as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade100,
              child:
                  item['image_url'] != null &&
                      item['image_url'].toString().isNotEmpty
                  ? Image.network(
                      item['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image, size: 30),
                    )
                  : const Icon(Icons.image, size: 30, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['variation'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['variation']['color_name']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        (item['variation']['stock'] is int &&
                                (item['variation']['stock'] as int) > 0)
                            ? 'Stock: ${item['variation']['stock']}'
                            : 'Out of stock',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              (item['variation']['stock'] is int &&
                                  (item['variation']['stock'] as int) > 0)
                              ? Colors.grey.shade500
                              : Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                Text(
                  '₱${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFFF4D97),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 24),
                onPressed: () => _updateCartQuantity(index, quantity - 1),
                color: Colors.grey.shade600,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '$quantity',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 24),
                onPressed: () => _updateCartQuantity(index, quantity + 1),
                color: const Color(0xFFFF4D97),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _removeFromCart(index),
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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
                                errorBuilder: (_, __, ___) => const Center(
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
                                        if (selectedQuantity > 1)
                                          selectedQuantity--;
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
                                        if (selectedQuantity < maxStock)
                                          setModalState(
                                            () => selectedQuantity++,
                                          );
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

// ==================== CHECKOUT SCREEN ====================
class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final VoidCallback onCheckoutComplete;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.onCheckoutComplete,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabaseService = SupabaseService();
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'paymongo';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  double _shippingFee = 99.00;
  final double _taxRate = 0.12;

  double get _subtotal => widget.cartItems.fold(
    0.0,
    (sum, item) =>
        sum + ((item['price'] as num).toDouble() * (item['quantity'] as int)),
  );
  double get _tax => _subtotal * _taxRate;
  double get _total => _subtotal + _shippingFee + _tax;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all shipping details'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw 'Please sign in to place an order.';
      }

      final orderData = {
        'buyer_id': user.id,
        'buyer_name': _nameController.text.trim(),
        'buyer_email': _emailController.text.trim(),
        'buyer_phone': _phoneController.text.trim(),
        'shipping_address': _addressController.text.trim(),
        'shipping_city': _cityController.text.trim(),
        'shipping_postal_code': _postalCodeController.text.trim(),
        'subtotal': _subtotal,
        'shipping': _shippingFee,
        'tax': _tax,
        'total': _total,
        'currency': 'PHP',
        'payment_provider': _selectedPaymentMethod,
        'payment_method': _selectedPaymentMethod,
        'status': 'pending',
      };

      final orderResponse = await Supabase.instance.client
          .from('orders')
          .insert(orderData)
          .select()
          .single();
      final orderId = orderResponse['id'];

      for (final item in widget.cartItems) {
        final orderItemData = {
          'order_id': orderId,
          'product_id': item['id'],
          'business_id': item['business_id'],
          'quantity': item['quantity'],
          'unit_price': item['price'],
          'total_price':
              (item['price'] as num).toDouble() * (item['quantity'] as int),
          'variation_name': item['variation']?['color_name'],
          'variation_hex':
              item['variation']?['hex_code'] ?? item['variation']?['hex'],
        };

        await Supabase.instance.client
            .from('order_items')
            .insert(orderItemData);
        await Supabase.instance.client.rpc(
          'decrement_stock',
          params: {'product_id': item['id'], 'quantity': item['quantity']},
        );
      }

      if (_selectedPaymentMethod == 'paymongo' || _selectedPaymentMethod == 'gcash') {
        final paymentResponse = await _supabaseService
            .createPaymongoCheckoutForOrder(items: widget.cartItems, paymentMethod: _selectedPaymentMethod);
        final checkoutUrl = paymentResponse['checkout_url']?.toString();
        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          await launchUrl(
            Uri.parse(checkoutUrl),
            mode: LaunchMode.externalApplication,
          );
          widget.onCheckoutComplete();
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        } else {
          throw 'Failed to create payment link';
        }
      } else {
        await Supabase.instance.client
            .from('orders')
            .update({'status': 'confirmed'})
            .eq('id', orderId);
        widget.onCheckoutComplete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order placed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF4D97),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFFFF4D97),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.cartItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    item['image_url'] != null &&
                                        item['image_url'].toString().isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          item['image_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.image),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? 'Product',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                    ),
                                    if (item['variation'] != null)
                                      Text(
                                        'Variant: ${item['variation']['color_name']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    Text(
                                      'Qty: ${item['quantity']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${((item['price'] as num).toDouble() * (item['quantity'] as int)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFFFF4D97),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      _buildPriceRow(
                        'Subtotal',
                        '₱${_subtotal.toStringAsFixed(2)}',
                      ),
                      _buildPriceRow(
                        'Shipping Fee',
                        '₱${_shippingFee.toStringAsFixed(2)}',
                      ),
                      _buildPriceRow(
                        'Tax (12% VAT)',
                        '₱${_tax.toStringAsFixed(2)}',
                      ),
                      const Divider(),
                      _buildPriceRow(
                        'Total',
                        '₱${_total.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shipping Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _nameController,
                        'Full Name',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _emailController,
                        'Email Address',
                        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _phoneController,
                        'Phone Number',
                        Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _addressController,
                        'Street Address',
                        Icons.home_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _cityController,
                              'City',
                              null,
                              hintText: 'City/Municipality',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              _postalCodeController,
                              'Postal Code',
                              null,
                              hintText: 'Postal code',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RadioListTile<String>(
                        value: 'paymongo',
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) =>
                            setState(() => _selectedPaymentMethod = value!),
                        title: Row(
                          children: [
                            Image.network(
                              'https://paymongo.com/favicon.ico',
                              height: 24,
                              width: 24,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.credit_card),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Credit / Debit Card',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          'Pay securely with PayMongo',
                          style: TextStyle(color: Colors.black54),
                        ),
                        activeColor: const Color(0xFFFF4D97),
                      ),
                      RadioListTile<String>(
                        value: 'cod',
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) =>
                            setState(() => _selectedPaymentMethod = value!),
                        title: const Row(
                          children: [
                            Icon(Icons.money, color: Colors.green),
                            SizedBox(width: 12),
                            Text(
                              'Cash on Delivery',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          'Pay when you receive the item',
                          style: TextStyle(color: Colors.black54),
                        ),
                        activeColor: const Color(0xFFFF4D97),
                      ),
                      RadioListTile<String>(
                        value: 'gcash',
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) =>
                            setState(() => _selectedPaymentMethod = value!),
                        title: const Row(
                          children: [
                            Icon(Icons.mobile_screen_share, color: Color(0xFF00A4EF)),
                            SizedBox(width: 12),
                            Text(
                              'GCash',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          'Pay via GCash app',
                          style: TextStyle(color: Colors.black54),
                        ),
                        activeColor: const Color(0xFFFF4D97),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D97),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Place Order • ₱${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF4D97)),
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: Colors.grey.shade600)
            : null,
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: Colors.black87,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? const Color(0xFFFF4D97) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
