// lib/screens/market_tab_enhanced.dart - Enhanced market with search, filters, and Shopee-like UI
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _loadingProductId;
  
  // Filter state
  String? _selectedCategory;
  double _minPrice = 0;
  double _maxPrice = 100000;
  String _sortBy = 'newest';
  bool _showFilters = false;
  Map<String, double> _categoryMaxPrices = {};

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    try {
      var query = Supabase.instance.client
          .from('products')
          .select('''id, name, price, currency, image_url, category, is_active, 
              stock_quantity, description, business_id, variations,
                    accounts:business_id(id, business_name, business_logo_url, avatar_url)''')
          .eq('is_active', true);
      
      final response = await query;
      var products = List<Map<String, dynamic>>.from(response);
      
      // Apply filters and sorting
      products = _applyFiltersAndSort(products);
      
      return products;
    } catch (e) {
      debugPrint('Error fetching products: $e');
      try {
        final fallbackResponse = await Supabase.instance.client
            .from('products')
          .select('id, name, price, currency, image_url, category, is_active, stock_quantity, description, business_id')
            .eq('is_active', true)
            .order('created_at', ascending: false);

        var fallbackProducts = List<Map<String, dynamic>>.from(fallbackResponse);
        fallbackProducts = _applyFiltersAndSort(fallbackProducts);
        return fallbackProducts;
      } catch (fallbackError) {
        debugPrint('Fallback product fetch failed: $fallbackError');
        return [];
      }
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

    if (rawVariations is String && rawVariations.trim().isNotEmpty) {
      try {
        final decoded = rawVariations;
        if (decoded.startsWith('[') || decoded.startsWith('{')) {
          return [];
        }
      } catch (_) {
        return [];
      }
    }

    return [];
  }

  List<Map<String, dynamic>> _applyFiltersAndSort(List<Map<String, dynamic>> products) {
    // Filter by category
    var filtered = products;
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((p) => (p['category'] ?? '').toString().toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }
    
    // Filter by price range
    filtered = filtered.where((p) {
      final price = (p['price'] ?? 0).toDouble();
      return price >= _minPrice && price <= _maxPrice;
    }).toList();
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final category = (p['category'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || category.contains(query);
      }).toList();
    }
    
    // Apply sorting
    switch (_sortBy) {
      case 'price_asc':
        filtered.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
        break;
      case 'price_desc':
        filtered.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
        break;
      case 'newest':
      default:
        break;
    }
    
    return filtered;
  }

  Future<void> _calculateCategoryMaxPrices(List<Map<String, dynamic>> products) async {
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
        _maxPrice = maxPrices.values.isEmpty ? 100000 : maxPrices.values.reduce((a, b) => a > b ? a : b);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFFFF4D97)),
                  SizedBox(height: 16),
                  Text('Loading products...'),
                ],
              ),
            );
          }

          final allProducts = snapshot.data ?? [];
          
          // Calculate max prices for categories
          if (_categoryMaxPrices.isEmpty && allProducts.isNotEmpty) {
            _calculateCategoryMaxPrices(allProducts);
          }

          return CustomScrollView(
            slivers: [
              // Enhanced SliverAppBar with search
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFFF4D97),
                elevation: 2,
                title: const Text(
                  'Beauty Shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                actions: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cart feature coming soon')),
                          );
                        },
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Container(
                    color: const Color(0xFFFF4D97),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                          });
                        },
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.9), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Promo Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildPromoBanner(),
                    ),
                    const SizedBox(height: 16),
                    // Filter and Sort Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              children: [
                                // Filter Button
                                FilterChip(
                                  label: const Text('Filters'),
                                  selected: _showFilters,
                                  onSelected: (value) {
                                    setState(() => _showFilters = value);
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFFFF4D97).withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _showFilters ? const Color(0xFFFF4D97) : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide(
                                    color: _showFilters ? const Color(0xFFFF4D97) : Colors.grey.shade300,
                                  ),
                                ),
                                // Sort Dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _sortBy,
                                    underline: const SizedBox(),
                                    items: const [
                                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                                      DropdownMenuItem(value: 'price_asc', child: Text('Low to High')),
                                      DropdownMenuItem(value: 'price_desc', child: Text('High to Low')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _sortBy = value);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showFilters) ...[
                      const SizedBox(height: 16),
                      // Filter Panel
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price Range Slider
                            Text(
                              'Price Range: ₱${_minPrice.toStringAsFixed(0)} - ₱${_maxPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            RangeSlider(
                              values: RangeValues(_minPrice, _maxPrice),
                              min: 0,
                              max: _categoryMaxPrices.isEmpty ? 100000 : _categoryMaxPrices.values.reduce((a, b) => a > b ? a : b),
                              onChanged: (values) {
                                setState(() {
                                  _minPrice = values.start;
                                  _maxPrice = values.end;
                                });
                              },
                              activeColor: const Color(0xFFFF4D97),
                              inactiveColor: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            // Category Selection
                            const Text(
                              'Categories',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('All Categories'),
                                  selected: _selectedCategory == null || _selectedCategory!.isEmpty,
                                  onSelected: (value) {
                                    setState(() => _selectedCategory = null);
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFFFF4D97).withValues(alpha: 0.2),
                                ),
                                ..._categoryMaxPrices.keys.map((category) => FilterChip(
                                  label: Text(category),
                                  selected: _selectedCategory == category,
                                  onSelected: (value) {
                                    setState(() => _selectedCategory = value ? category : null);
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFFFF4D97).withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _selectedCategory == category ? const Color(0xFFFF4D97) : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide(
                                    color: _selectedCategory == category ? const Color(0xFFFF4D97) : Colors.grey.shade300,
                                  ),
                                )),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Products Grid
                    if (allProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                        child: Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: allProducts.length,
                        itemBuilder: (context, index) {
                          return _buildEnhancedProductCard(context, allProducts[index]);
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4D97), Color(0xFFFF8DC7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D97).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'FLASH SALE',
                          style: TextStyle(
                            color: Color(0xFFFF4D97),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Up to 50% OFF\nBeauty Favorites',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Shop Now',
                    style: TextStyle(
                      color: Color(0xFFFF4D97),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

  Widget _buildEnhancedProductCard(BuildContext context, Map<String, dynamic> product) {
    final productId = product['id']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'Unnamed Product';
    final price = product['price'] ?? 0;
    final imageUrl = product['image_url']?.toString();
    final category = product['category']?.toString();
    final stockQuantity = product['stock_quantity'] ?? 0;
    final isLoading = _loadingProductId == productId;
    
    // Get business info
    final businessInfo = product['accounts'] as Map<String, dynamic>? ?? {};
    final businessName = (businessInfo['business_name'] ?? 'Shop').toString();
    final businessLogo = (businessInfo['business_logo_url'] ?? businessInfo['avatar_url']).toString();
    final variations = _extractVariations(product);

    final isOutOfStock = stockQuantity <= 0;
    final lowStock = stockQuantity > 0 && stockQuantity < 5;

    return GestureDetector(
      onTap: () => _showProductDetail(context, product),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Container
              Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Center(child: Icon(Icons.image, size: 48, color: Colors.grey))
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                          ),
                  ),
                  // Stock Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: isOutOfStock
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          )
                        : lowStock
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Limited Stock',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                  // Sale Badge (optional)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D97),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HOT',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Name
                      Row(
                        children: [
                          businessLogo != 'null' && businessLogo.isNotEmpty
                              ? CircleAvatar(
                                  radius: 12,
                                  backgroundImage: NetworkImage(businessLogo),
                                )
                              : CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFFF4D97).withValues(alpha: 0.2),
                                  child: const Icon(Icons.store, size: 12, color: Color(0xFFFF4D97)),
                                ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Product Name
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, height: 1.2),
                      ),
                      const Spacer(),
                      // Price and Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₱${price.toString()}',
                                style: const TextStyle(
                                  color: Color(0xFFFF4D97),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (category != null && category.isNotEmpty)
                                Text(
                                  category,
                                  style: const TextStyle(fontSize: 9, color: Colors.black38),
                                ),
                              if (variations.isNotEmpty)
                                Text(
                                  '${variations.length} variant${variations.length == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 9, color: Colors.black38),
                                ),
                            ],
                          ),
                          SizedBox(
                            height: 32,
                            width: 32,
                            child: ElevatedButton(
                              onPressed: (isLoading || isOutOfStock) ? null : () => _startCheckout(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOutOfStock ? Colors.grey : const Color(0xFFFF4D97),
                                disabledBackgroundColor: Colors.grey,
                                padding: const EdgeInsets.all(0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add_shopping_cart, size: 14, color: Colors.white),
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

  Widget _buildProductDetailModal(BuildContext context, Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? '';
    final price = product['price'] ?? 0;
    final imageUrl = product['image_url']?.toString();
    final description = product['description']?.toString() ?? '';
    final stockQuantity = product['stock_quantity'] ?? 0;
    final category = product['category']?.toString() ?? '';
    final variations = _extractVariations(product);

    // Get business info
    final businessInfo = product['accounts'] as Map<String, dynamic>? ?? {};
    final businessName = (businessInfo['business_name'] ?? 'Shop').toString();
    final businessLogo = (businessInfo['business_logo_url'] ?? businessInfo['avatar_url']).toString();

    final isOutOfStock = stockQuantity <= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              // Image
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
                      ? const Center(child: Icon(Icons.image, size: 64, color: Colors.grey))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Product Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price and Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${price.toString()}',
                          style: const TextStyle(
                            color: Color(0xFFFF4D97),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D97).withValues(alpha: 0.1),
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
                    // Product Name
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    // Stock Status
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
                    // Seller Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          businessLogo != 'null' && businessLogo.isNotEmpty
                              ? CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(businessLogo),
                                )
                              : CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFFF4D97).withValues(alpha: 0.2),
                                  child: const Icon(Icons.store, size: 20, color: Color(0xFFFF4D97)),
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Seller',
                                  style: TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                                Text(
                                  businessName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Visit shop coming soon')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFFF4D97)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Visit',
                              style: TextStyle(
                                color: Color(0xFFFF4D97),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    if (description.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (variations.isNotEmpty) ...[
                      const Text(
                        'Variants',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: variations.map((variation) {
                          final colorName = (variation['color_name'] ?? variation['name'] ?? 'Variant').toString();
                          final hexCode = (variation['hex_code'] ?? '').toString();
                          final priceValue = variation['price'];
                          final stockValue = variation['stock'];
                          final chipColor = _safeParseColor(hexCode) ?? const Color(0xFFFF4D97);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: chipColor.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  colorName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                if (hexCode.isNotEmpty)
                                  Text(
                                    hexCode,
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                  ),
                                if (priceValue != null || stockValue != null)
                                  Text(
                                    [
                                      if (priceValue != null) '₱${priceValue.toString()}',
                                      if (stockValue != null) 'Stock: ${stockValue.toString()}',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const Text(
                        'Variants not available for this product yet.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isOutOfStock ? null : () => _startCheckout(product),
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Add to Cart'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOutOfStock ? Colors.grey : const Color(0xFFFF4D97),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to wishlist')),
                            );
                          },
                          icon: const Icon(Icons.favorite_border),
                          label: const Text(''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFFF4D97)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ),
    );
  }

  Future<void> _startCheckout(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) {
      return;
    }

    setState(() {
      _loadingProductId = productId;
    });

    try {
      final response = await _supabaseService.createPaymongoCheckoutForOrder(
        items: [
          {
            'product_id': productId,
            'quantity': 1,
          },
        ],
      );

      final checkoutUrl = response['checkout_url']?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw 'Missing checkout URL';
      }

      await _openCheckoutUrl(checkoutUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingProductId = null;
        });
      }
    }
  }

  Future<void> _openCheckoutUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open checkout link.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color? _safeParseColor(String hexCode) {
    final value = hexCode.trim();
    if (value.isEmpty) return null;

    var normalized = value.replaceAll('#', '').trim();
    if (normalized.length == 6) {
      normalized = 'FF$normalized';
    }
    if (normalized.length != 8) {
      return null;
    }

    try {
      return Color(int.parse(normalized, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
