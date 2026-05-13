// lib/screens/home_tab.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../scan_result_page.dart';
import 'market_tab.dart';
import 'scan_tab.dart';
import 'settings_tab.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  final Random _random = Random();
  final Map<String, int> _categorySignals = {};

  List<Map<String, dynamic>> _products = [];
  bool _productsLoading = true;
  String? _productsError;

  String _recommendationMode = 'for_you';

  bool _animateIn = false;
  bool _weatherLoading = true;
  String? _weatherError;
  String _weatherLocation = 'Loading weather';
  String _weatherSummary = 'Checking your weather';
  String _weatherTemperature = '--';
  // weather advice placeholder (currently unused)
  // String _weatherAdvice = '';
  IconData _weatherIcon = Icons.wb_sunny_outlined;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _animateIn = true);
    });
    _loadHomeData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    await Future.wait([_fetchWeather(), _fetchProducts()]);
  }

  Future<void> _fetchProducts() async {
    if (mounted) {
      setState(() {
        _productsLoading = true;
        _productsError = null;
      });
    }

    try {
      final sup = Supabase.instance.client;
      debugPrint('📦 Fetching products from Supabase...');

      final res = await sup
          .from('products')
          .select(
            'id, name, description, price, currency, image_url, product_link, stock_quantity, category, is_active, created_at, business_id, variations',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final data = (res as List).cast<Map<String, dynamic>>();
      debugPrint('✅ Loaded ${data.length} products');

      if (!mounted) return;
      setState(() {
        _products = data;
        _productsLoading = false;
      });
    } catch (e, st) {
      debugPrint('❌ Products error: $e');
      debugPrint('❌ Stack trace: $st');

      if (!mounted) return;
      setState(() {
        _products = [];
        _productsError = 'Unable to load products: ${e.toString()}';
        _productsLoading = false;
      });
    }
  }

  Future<void> _fetchWeather() async {
    if (mounted) {
      setState(() {
        _weatherLoading = true;
        _weatherError = null;
      });
    }

    try {
      final locationResponse = await http.get(
        Uri.parse('https://ipapi.co/json/'),
      );
      if (locationResponse.statusCode != 200) {
        throw Exception('Location lookup failed');
      }

      final locationData =
          jsonDecode(locationResponse.body) as Map<String, dynamic>;
      final latitude = (locationData['latitude'] ?? locationData['lat'])
          ?.toString();
      final longitude = (locationData['longitude'] ?? locationData['lon'])
          ?.toString();
      if (latitude == null || longitude == null) {
        throw Exception('Missing coordinates');
      }

      final locationLabel = [locationData['city'], locationData['region']]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(', ');

      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&timezone=auto',
        ),
      );
      if (weatherResponse.statusCode != 200) {
        throw Exception('Weather lookup failed');
      }

      final weatherData =
          jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final current = (weatherData['current_weather'] as Map?)
          ?.cast<String, dynamic>();
      if (current == null) {
        throw Exception('Weather data unavailable');
      }

      final temperature = (current['temperature'] as num?)?.toDouble();
      final weatherCode = (current['weathercode'] as num?)?.toInt();
      final isDay = (current['is_day'] as num?)?.toInt() == 1;

      if (!mounted) return;
      setState(() {
        _weatherLocation = locationLabel.isEmpty ? 'Your area' : locationLabel;
        _weatherSummary = _describeWeatherCode(weatherCode);
        _weatherTemperature = temperature == null
            ? '--'
            : '${temperature.round()}°C';
        // _weatherAdvice = _weatherAdviceFor(temperature, weatherCode);
        _weatherIcon = _weatherIconFor(weatherCode, isDay: isDay);
        _weatherLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherError = 'Live weather unavailable';
        _weatherLocation = 'Weather';
        _weatherSummary = 'Tap to retry';
        _weatherTemperature = '--';
        // _weatherAdvice = 'Weather could not be refreshed right now.';
        _weatherIcon = Icons.cloud_off_outlined;
      });
    }
  }

  List<Map<String, dynamic>> _recommendedProducts() {
    final items = List<Map<String, dynamic>>.from(_products);
    if (items.isEmpty) return items;

    switch (_recommendationMode) {
      case 'random':
        items.shuffle(Random(_random.nextInt(1 << 31)));
        return items.take(6).toList();
      case 'trending':
        items.sort((a, b) => _trendScore(b).compareTo(_trendScore(a)));
        return items.take(6).toList();
      case 'for_you':
      default:
        items.sort((a, b) => _personalScore(b).compareTo(_personalScore(a)));
        return items.take(6).toList();
    }
  }

  double _personalScore(Map<String, dynamic> product) {
    final category = (product['category'] ?? 'Other').toString().toLowerCase();
    final signalScore = (_categorySignals[category] ?? 0) * 5.0;
    final weatherScore = _weatherBiasForCategory(category);
    final stockQuantity = (product['stock_quantity'] as num?)?.toDouble() ?? 0;
    final stockScore = stockQuantity > 0 ? 1.0 : -1.0;
    final imageScore = (product['image_url'] as String?)?.isNotEmpty == true
        ? 0.8
        : 0.0;
    final freshnessScore = _freshnessScore(product['created_at']);
    return signalScore +
        weatherScore +
        stockScore +
        imageScore +
        freshnessScore;
  }

  double _trendScore(Map<String, dynamic> product) {
    final stockQuantity = (product['stock_quantity'] as num?)?.toDouble() ?? 0;
    final imageScore = (product['image_url'] as String?)?.isNotEmpty == true
        ? 0.7
        : 0.0;
    return (stockQuantity > 0 ? 2.0 : -1.0) +
        imageScore +
        _freshnessScore(product['created_at']);
  }

  double _freshnessScore(dynamic createdAt) {
    final parsed = createdAt == null
        ? null
        : DateTime.tryParse(createdAt.toString());
    if (parsed == null) return 0;
    final ageHours = DateTime.now()
        .difference(parsed)
        .inHours
        .clamp(0, 24 * 90)
        .toDouble();
    return (24 * 90 - ageHours) / (24 * 90);
  }

  double _weatherBiasForCategory(String category) {
    final temp = double.tryParse(_weatherTemperature.replaceAll('°C', ''));
    if (temp == null) return 0;

    if (temp >= 30) {
      const lighterCategories = {
        'foundation',
        'concealer',
        'powder',
        'setting spray',
        'primer',
      };
      return lighterCategories.contains(category) ? 2.0 : 0.0;
    }

    if (temp <= 24) {
      const warmerCategories = {'lipstick', 'blush', 'eyeshadow', 'palette'};
      return warmerCategories.contains(category) ? 1.5 : 0.0;
    }

    return 0.5;
  }

  void _registerProductInterest(Map<String, dynamic> product) {
    final category = (product['category'] ?? 'Other').toString().toLowerCase();
    setState(() {
      _categorySignals[category] = (_categorySignals[category] ?? 0) + 1;
      _recommendationMode = 'for_you';
    });
  }

  String _formatPrice(Map<String, dynamic> product) {
    final price = (product['price'] as num?)?.toDouble();
    final currency = (product['currency'] ?? 'PHP').toString();
    if (price == null) return currency;
    final symbol = currency.toUpperCase() == 'PHP' ? '₱' : '$currency ';
    return '$symbol${price.toStringAsFixed(2)}';
  }

  void _openScanTab() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScanTab()));
  }

  void _openMarketTab() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MarketTab()));
  }

  void _openSettingsTab() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsTab()));
  }

  void _openLookResult(String scannedItem) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanResultPage(scannedItem: scannedItem),
      ),
    );
  }

  void _showProductPreview(Map<String, dynamic> product) {
    _registerProductInterest(product);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final imageUrl = (product['image_url'] as String?)?.trim() ?? '';
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF4D97).withOpacity(0.1),
                                const Color(0xFFFF8DC7).withOpacity(0.05),
                              ],
                            ),
                            image: imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: imageUrl.isEmpty
                              ? const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Color(0xFFFF4D97),
                                  size: 48,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        (product['name'] ?? 'Product').toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D97).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (product['category'] ?? 'Beauty').toString(),
                          style: const TextStyle(
                            color: Color(0xFFFF4D97),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            _formatPrice(product),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF4D97),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.green,
                                  size: 8,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'In Stock',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (product['description'] ??
                                'A curated product from your beauty system.')
                            .toString(),
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openMarketTab();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4D97),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'View in Market',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _describeWeatherCode(int? code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Light drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rainy';
      case 71:
      case 73:
      case 75:
        return 'Snowy';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorms';
      default:
        return 'Mixed weather';
    }
  }

  IconData _weatherIconFor(int? code, {required bool isDay}) {
    switch (code) {
      case 0:
        return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round;
      case 1:
      case 2:
        return Icons.cloud_outlined;
      case 3:
        return Icons.cloud;
      case 45:
      case 48:
        return Icons.cloud_queue_outlined;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.umbrella_outlined;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit_outlined;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_outlined;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  String _weatherAdviceFor(double? temperature, int? code) {
    if (temperature == null) {
      return 'Check back for the latest styling weather.';
    }

    if (code != null && code >= 61 && code <= 99) {
      return 'Use waterproof formulas and a long-wear setting spray today.';
    }

    if (temperature >= 30) {
      return 'Hot weather today. Go for lightweight base, blotting powder, and setting spray.';
    }

    if (temperature <= 24) {
      return 'Cool weather today. Cream blush and richer shades will hold nicely.';
    }

    return 'Balanced weather. You can wear most looks comfortably today.';
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = (product['image_url'] as String?)?.trim() ?? '';
    final category = (product['category'] ?? 'Beauty').toString();
    final stockQuantity = (product['stock_quantity'] as num?)?.toDouble() ?? 0;

    return LongPressDraggable<Map<String, dynamic>>(
      data: product,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 0.95,
          child: _productCardContent(
            product,
            imageUrl: imageUrl,
            category: category,
            stockQuantity: stockQuantity,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _productCardContent(
          product,
          imageUrl: imageUrl,
          category: category,
          stockQuantity: stockQuantity,
        ),
      ),
      child: _productCardContent(
        product,
        imageUrl: imageUrl,
        category: category,
        stockQuantity: stockQuantity,
      ),
    );
  }

  Widget _productCardContent(
    Map<String, dynamic> product, {
    required String imageUrl,
    required String category,
    required double stockQuantity,
  }) {
    return GestureDetector(
      onTap: () => _showProductPreview(product),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D97).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF4D97).withOpacity(0.08),
                    const Color(0xFFFF8DC7).withOpacity(0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: const Color(0xFFFF4D97).withOpacity(0.5),
                        size: 48,
                      ),
                    )
                  : Stack(
                      children: [
                        if (stockQuantity <= 5 && stockQuantity > 0)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Low Stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product['name'] ?? 'Product').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D97).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFF4D97),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatPrice(product),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF4D97),
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

  Widget _buildRecommendationControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFF4D97), size: 16),
            const SizedBox(width: 6),
            Text(
              'Smart Picks',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChoiceChip('For You', 'for_you', Icons.person_outline),
              const SizedBox(width: 8),
              _buildChoiceChip('Trending', 'trending', Icons.trending_up),
              const SizedBox(width: 8),
              _buildChoiceChip('Surprise', 'random', Icons.casino_outlined),
              const SizedBox(width: 12),
              _buildRefreshButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, String mode, IconData icon) {
    final isSelected = _recommendationMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _recommendationMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF4D97).withOpacity(0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF4D97)
                : Colors.grey.withOpacity(0.3),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D97).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFFFF4D97) : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFF4D97) : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: _fetchProducts,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Icon(
          Icons.refresh_rounded,
          size: 20,
          color: Color(0xFFFF4D97),
        ),
      ),
    );
  }

  Widget _buildLatestLookCard(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) => _showProductPreview(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D97), Color(0xFFFF6B9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D97).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Stack(
            children: [
              // Decorative elements
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'AI Generated',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Your Perfect Look',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isActive ? 'Drop product here' : 'View Details',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isActive
                                ? Icons.add_circle_outline
                                : Icons.arrow_forward,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLookCard(String name, IconData icon, Gradient gradient) {
    return GestureDetector(
      onTap: () => _openLookResult(name),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try this look',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendedProducts = _recommendedProducts();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFFFF4D97),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF4D97), Color(0xFFFF6B9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Animated background circles
                    ...List.generate(3, (index) {
                      return Positioned(
                        right: -20.0 + (index * 40),
                        top: -20.0 + (index * 30),
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value + (index * 0.1),
                              child: Container(
                                width: 120.0 + (index * 40),
                                height: 120.0 + (index * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(
                                    0.05 + (index * 0.02),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedOpacity(
                                        opacity: _animateIn ? 1 : 0,
                                        duration: const Duration(
                                          milliseconds: 450,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            '✨ Welcome back',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Express Your Style',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _openSettingsTab,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.15,
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 28,
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
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Weather & Scan Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _buildTemperatureCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickScanCard(context)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Look Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(
                    '✨ Your Style Universe',
                    subtitle: 'AI-powered recommendations',
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLatestLookCard(context),
                ),
                const SizedBox(height: 24),

                // Quick Looks
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildLookCard(
                        'Natural',
                        Icons.face,
                        const LinearGradient(
                          colors: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
                        ),
                      ),
                      _buildLookCard(
                        'Glam',
                        Icons.auto_awesome,
                        const LinearGradient(
                          colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
                        ),
                      ),
                      _buildLookCard(
                        'Everyday',
                        Icons.wb_sunny,
                        const LinearGradient(
                          colors: [Color(0xFFFFD1FF), Color(0xFFFF9A9E)],
                        ),
                      ),
                      _buildLookCard(
                        'Bold',
                        Icons.favorite,
                        const LinearGradient(
                          colors: [Color(0xFFFF0844), Color(0xFFFFB199)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recommended Products
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(
                    '💄 Curated For You',
                    subtitle: 'Based on your preferences',
                    onTap: _openMarketTab,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildRecommendationControls(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: _productsLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF4D97),
                          ),
                        )
                      : _productsError != null
                      ? _buildErrorState()
                      : recommendedProducts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: recommendedProducts.length,
                          itemBuilder: (context, index) {
                            final product = recommendedProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
                ),

                const SizedBox(height: 24),

                // Beauty Tips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(
                    '🌟 Beauty Wisdom',
                    subtitle: 'Expert tips for you',
                  ),
                ),
                const SizedBox(height: 12),
                _buildBeautyTipsList(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D2E),
              ),
            ),
            if (onTap != null)
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D97).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: Color(0xFFFF4D97),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: Colors.red[400], size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            _productsError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchProducts,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D97).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFFFF4D97),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Exciting products coming soon',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickScanCard(BuildContext context) {
    return GestureDetector(
      onTap: _openScanTab,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4D97), Color(0xFFFF6B9D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D97).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try On',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Virtual try-on',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeautyTipsList() {
    final tips = [
      {
        'title': 'Skin Care First',
        'subtitle': 'Healthy skin is the best canvas for any makeup look',
        'icon': Icons.clean_hands_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Protect from Sun',
        'subtitle': 'Always use SPF 30+ sunscreen daily, rain or shine',
        'icon': Icons.wb_sunny_rounded,
        'color': Colors.orange,
      },
      {
        'title': 'Proper Hydration',
        'subtitle': 'Drink water and use moisturizer for glowing skin',
        'icon': Icons.water_drop_rounded,
        'color': Colors.purple,
      },
    ];

    return Column(
      children: tips.map((tip) {
        return _buildBeautyTipCard(
          tip['title'] as String,
          tip['subtitle'] as String,
          tip['icon'] as IconData,
          tip['color'] as Color,
        );
      }).toList(),
    );
  }

  Widget _buildBeautyTipCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureCard() {
    final accent = _weatherError == null ? Colors.orange : Colors.blueGrey;

    return GestureDetector(
      onTap: _fetchWeather,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_weatherIcon, color: accent, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _weatherLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _weatherLoading ? '--' : _weatherTemperature,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D2E),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _weatherLoading ? 'Refreshing...' : _weatherSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final temp = double.tryParse(
                  _weatherTemperature.replaceAll('°C', ''),
                );
                final advice = _weatherLoading
                    ? ''
                    : _weatherAdviceFor(temp, null);
                return Text(
                  advice,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
