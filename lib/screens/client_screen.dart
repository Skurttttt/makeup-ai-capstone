// lib/screens/client_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import '../utils/logout_util.dart';

// ==================== THEME CONSTANTS ====================
class AppTheme {
  static const primaryColor = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4F46E5);
  static const secondaryColor = Color(0xFFEC4899);
  static const successColor = Color(0xFF10B981);
  static const warningColor = Color(0xFFF59E0B);
  static const errorColor = Color(0xFFEF4444);
  static const surfaceColor = Color(0xFFF8FAFC);
  static const cardColor = Colors.white;
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const dividerColor = Color(0xFFE2E8F0);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryDark],
  );

  static const secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, Color(0xFFF43F5E)],
  );

  static final boxShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

Color contrastTextForBackground(Color bg) {
  return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

// Format currency to Philippine Peso (PHP)
String formatPHP(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'fil_PH',
    symbol: '₱',
    decimalDigits: amount == amount.toInt() ? 0 : 2,
  );
  return formatter.format(amount);
}

String _extractNameFromEcommerceUrl(Uri uri) {
  try {
    if (uri.host.contains('shopee')) {
      if (uri.pathSegments.isNotEmpty) {
        String slug = uri.pathSegments.first;
        final parts = slug.split('-i.');
        if (parts.isNotEmpty) {
          String name = parts.first.replaceAll(RegExp(r'-+'), ' ');
          return Uri.decodeComponent(name);
        }
      }
    } else if (uri.host.contains('lazada')) {
      if (uri.pathSegments.length > 1 && uri.pathSegments.first == 'products') {
        String slug = uri.pathSegments[1];
        final parts = slug.split(RegExp(r'-i\d+'));
        if (parts.isNotEmpty) {
          String name = parts.first.replaceAll(RegExp(r'-+'), ' ');
          return Uri.decodeComponent(name);
        }
      }
    }
  } catch (_) {}
  return '';
}

String? _guessCategory(String text) {
  final lowerText = text.toLowerCase();
  if (lowerText.contains('lipstick') || lowerText.contains('lip gloss'))
    return 'Lipstick';
  if (lowerText.contains('blush')) return 'Blush';
  if (lowerText.contains('foundation')) return 'Foundation';
  if (lowerText.contains('concealer')) return 'Concealer';
  if (lowerText.contains('eyeshadow')) return 'Eyeshadow';
  if (lowerText.contains('eyeliner')) return 'Eyeliner';
  if (lowerText.contains('mascara')) return 'Mascara';
  if (lowerText.contains('brow')) return 'Eyebrow';
  if (lowerText.contains('brush')) return 'Tools & Brushes';
  return null;
}

// ==================== MAIN SCREEN ====================
class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen>
    with TickerProviderStateMixin {
  int _currentSection = 0;
  late Future<Map<String, dynamic>> _clientDataFuture;
  late TabController _tabController;

  // Shop data
  String _shopName = '';
  String _shopCategory = '';
  String _shopPhone = '';
  String _shopAddress = '';
  String? _shopAvatarUrl;
  Uint8List? _shopAvatarBytes;
  String? _shopAvatarName;
  bool _shopFormInitialized = false;
  bool _isSavingShop = false;
  bool _isUploadingAvatar = false;
  final ImagePicker _avatarPicker = ImagePicker();
  String? _shopProfileId;

  // Notification settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _soundEffects = true;

  final List<Map<String, String>> _shopCategoryOptions = const [
    {'value': 'makeup_brand', 'label': 'Makeup Brand'},
    {'value': 'salon', 'label': 'Salon'},
    {'value': 'artist', 'label': 'Artist'},
    {'value': 'distributor', 'label': 'Distributor'},
    {'value': 'retailer', 'label': 'Retailer'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _clientDataFuture = _fetchClientData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchClientData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await Supabase.instance.client
          .from('accounts')
          .select()
          .eq('id', user.id)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching client data: $e');
      rethrow;
    }
  }

  Future<void> _refreshClientData() async {
    final refreshed = _fetchClientData();
    setState(() => _clientDataFuture = refreshed);
    await refreshed;
  }

  void _setSection(int index) {
    if (_currentSection == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentSection = index);
  }

  void _logout() {
    showLogoutConfirmationDialog(context, role: 'client');
  }

  void _initializeShopForm(Map<String, dynamic> clientData) {
    final profileId = clientData['id']?.toString();
    if (_shopFormInitialized && _shopProfileId == profileId) return;

    _shopName = (clientData['business_name'] ?? '').toString();
    _shopCategory = (clientData['business_type'] ?? '').toString();
    _shopPhone = (clientData['business_phone'] ?? '').toString();
    _shopAddress = (clientData['business_address'] ?? '').toString();
    final logoUrl =
        (clientData['business_logo_url'] ?? clientData['avatar_url'] ?? '')
            .toString()
            .trim();
    _shopAvatarUrl = logoUrl.isEmpty ? null : logoUrl;
    _shopAvatarName = null;
    _shopAvatarBytes = null;
    _shopFormInitialized = true;
    _shopProfileId = profileId;
  }

  String _fileExtensionFromName(String fileName) {
    final match = RegExp(r'\.(\w+)$').firstMatch(fileName);
    return match?.group(1)?.toLowerCase() ?? 'png';
  }

  Future<void> _uploadAvatar() async {
    if (_isUploadingAvatar) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    XFile? pickedFile;
    try {
      pickedFile = await _avatarPicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
    } catch (e) {
      return;
    }

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await pickedFile!.readAsBytes();
      final safeName = pickedFile.name.replaceAll(
        RegExp(r'[^A-Za-z0-9_.-]'),
        '_',
      );
      final extension = _fileExtensionFromName(pickedFile.name);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$safeName.$extension';
      final storagePath = '${user.id}/avatars/$fileName';

      await Supabase.instance.client.storage
          .from('scan-images')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('scan-images')
          .getPublicUrl(storagePath);

      await Supabase.instance.client
          .from('accounts')
          .update({'avatar_url': publicUrl, 'business_logo_url': publicUrl})
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _shopAvatarBytes = bytes;
          _shopAvatarName = pickedFile?.name ?? 'Selected image';
          _shopAvatarUrl = publicUrl;
          _shopFormInitialized = false;
          _clientDataFuture = _fetchClientData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveShopSettings() async {
    if (_isSavingShop) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_shopName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop name is required'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSavingShop = true);

    try {
      await Supabase.instance.client
          .from('accounts')
          .update({
            'business_name': _shopName.trim(),
            'business_type': _shopCategory.trim().isEmpty
                ? null
                : _shopCategory.trim(),
            'business_phone': _shopPhone.trim().isEmpty
                ? null
                : _shopPhone.trim(),
            'business_address': _shopAddress.trim().isEmpty
                ? null
                : _shopAddress.trim(),
          })
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _shopFormInitialized = false;
          _clientDataFuture = _fetchClientData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingShop = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _clientDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => _clientDataFuture = _fetchClientData()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final clientData = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            return isDesktop
                ? _buildDesktopLayout(clientData)
                : _buildMobileLayout(clientData);
          },
        );
      },
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout(Map<String, dynamic> clientData) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              boxShadow: AppTheme.boxShadow,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: contrastTextForBackground(AppTheme.cardColor),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seller Centre',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Manage your store',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.dividerColor),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      children: [
                        _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0),
                        _buildNavItem(Icons.storefront_outlined, 'My Shop', 1),
                        _buildNavItem(
                          Icons.inventory_2_outlined,
                          'Products',
                          2,
                        ),
                        _buildNavItem(Icons.analytics_outlined, 'Analytics', 3),
                        _buildNavItem(Icons.settings_outlined, 'Settings', 4),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout,
                        color: AppTheme.errorColor,
                      ),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.errorColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(
                color: contrastTextForBackground(AppTheme.cardColor),
              ),
              child: Column(
                children: [
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      boxShadow: AppTheme.boxShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.06, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _getSectionTitle(),
                            key: ValueKey(_currentSection),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none),
                              onPressed: _showNotifications,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.store,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    clientData['business_name'] ?? 'My Store',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshClientData,
                      color: AppTheme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: _buildAnimatedSectionContent(clientData),
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
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentSection == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: isSelected ? AppTheme.primaryGradient : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ListTile(
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            icon,
            key: ValueKey('nav-$label-$isSelected'),
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _setSection(index),
      ),
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout(Map<String, dynamic> clientData) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Seller Centre'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: DefaultTextStyle(
        style: TextStyle(
          color: contrastTextForBackground(AppTheme.surfaceColor),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshClientData,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: _buildAnimatedSectionContent(clientData),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: AppTheme.boxShadow,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentSection,
          onTap: _setSection,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSectionContent(Map<String, dynamic> clientData) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentSection),
        child: _buildSectionContent(clientData),
      ),
    );
  }

  String _getSectionTitle() {
    const titles = [
      'Dashboard',
      'My Shop',
      'Products',
      'Analytics',
      'Settings',
    ];
    return titles[_currentSection];
  }

  Widget _buildSectionContent(Map<String, dynamic> clientData) {
    switch (_currentSection) {
      case 0:
        return _buildDashboard(clientData);
      case 1:
        return _buildMyShopSettings(clientData);
      case 2:
        return _buildProducts(clientData);
      case 3:
        return _buildAnalytics(clientData);
      case 4:
        return _buildSettings(clientData);
      default:
        return const SizedBox();
    }
  }

  // ==================== DASHBOARD ====================
  Widget _buildDashboard(Map<String, dynamic> clientData) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('order_items')
          .stream(primaryKey: ['id'])
          .eq('business_id', clientData['id']),
      builder: (context, salesSnapshot) {
        final salesItems = salesSnapshot.data ?? [];
        final totalRevenue = salesItems.fold(
          0.0,
          (sum, item) => sum + ((item['total_price'] as num?)?.toDouble() ?? 0),
        );
        final totalUnitsSold = salesItems.fold(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
        );
        final orderCount = salesItems
            .map((item) => item['order_id']?.toString())
            .whereType<String>()
            .toSet()
            .length;
        final averageOrderValue = orderCount == 0
            ? 0.0
            : totalRevenue / orderCount;

        final dailyRevenue = <String, double>{};
        for (final item in salesItems) {
          final createdAt = DateTime.tryParse(
            item['created_at']?.toString() ?? '',
          );
          if (createdAt != null) {
            final key = DateFormat('MM/dd').format(createdAt.toLocal());
            dailyRevenue[key] =
                (dailyRevenue[key] ?? 0) +
                ((item['total_price'] as num?)?.toDouble() ?? 0);
          }
        }

        final trendKeys = dailyRevenue.keys.toList();
        final revenueSpots = List.generate(
          trendKeys.length,
          (i) => FlSpot(i.toDouble(), dailyRevenue[trendKeys[i]] ?? 0),
        );

        final recentSales = [...salesItems]
          ..sort((a, b) {
            final aDate =
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                DateTime(0);
            final bDate =
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                DateTime(0);
            return bDate.compareTo(aDate);
          });

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('products')
              .stream(primaryKey: ['id'])
              .eq('business_id', clientData['id']),
          builder: (context, productsSnapshot) {
            final products = productsSnapshot.data ?? [];
            final lowStockCount = products
                .where((p) => (p['stock_quantity'] as int? ?? 0) <= 5)
                .length;
            final outOfStockCount = products
                .where((p) => (p['stock_quantity'] as int? ?? 0) == 0)
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${clientData['business_name'] ?? 'Seller'}!',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Here\'s what\'s happening with your business today.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.celebration,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Stats Grid
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900
                      ? 4
                      : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard(
                      'Total Revenue',
                      formatPHP(totalRevenue),
                      Icons.attach_money,
                      AppTheme.successColor,
                    ),
                    _buildStatCard(
                      'Total Orders',
                      orderCount.toString(),
                      Icons.receipt_long,
                      AppTheme.primaryColor,
                    ),
                    _buildStatCard(
                      'Units Sold',
                      totalUnitsSold.toString(),
                      Icons.shopping_bag,
                      AppTheme.warningColor,
                    ),
                    _buildStatCard(
                      'Avg Order',
                      formatPHP(averageOrderValue),
                      Icons.trending_up,
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Alerts Row
                if (lowStockCount > 0 || outOfStockCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Inventory Alert: $lowStockCount product(s) low stock, $outOfStockCount out of stock',
                            style: TextStyle(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _currentSection = 2),
                          child: const Text('View Products'),
                        ),
                      ],
                    ),
                  ),
                // Revenue Chart
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _buildCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.show_chart,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Revenue Trend',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 280,
                        child: revenueSpots.isEmpty
                            ? Center(
                                child: Text(
                                  'No sales data yet',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  minY: 0,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          return idx >= 0 &&
                                                  idx < trendKeys.length
                                              ? Text(
                                                  trendKeys[idx],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                )
                                              : const Text('');
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: revenueSpots,
                                      isCurved: true,
                                      color: AppTheme.primaryColor,
                                      barWidth: 3,
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Recent Sales and Quick Actions
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: _buildCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.history,
                                        color: AppTheme.warningColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Recent Sales',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (recentSales.isEmpty)
                                  Center(
                                    child: Text(
                                      'No recent sales',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                else
                                  ...recentSales
                                      .take(5)
                                      .map((sale) => _buildSaleTile(sale)),
                              ],
                            ),
                          ),
                        ),
                        if (isWide) const SizedBox(width: 16),
                        if (isWide) Expanded(child: _buildQuickActionsCard()),
                      ],
                    );
                  },
                ),
                if (MediaQuery.of(context).size.width <= 800)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildQuickActionsCard(),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flash_on, color: AppTheme.successColor),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
            'Add New Product',
            Icons.add_box,
            () => _showAddProductDialog(''),
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'View All Orders',
            Icons.receipt_long,
            () => _showOrders(),
            AppTheme.secondaryColor,
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'Export Reports',
            Icons.download,
            _exportReports,
            AppTheme.successColor,
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'Manage Inventory',
            Icons.inventory,
            () => setState(() => _currentSection = 2),
            AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w500, color: color),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  void _showOrders() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Orders feature coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _exportReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting reports...'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('New order received!'),
              subtitle: Text(
                'Order #ORD-001 - ₱1,299.00',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Low stock alert'),
              subtitle: const Text('3 products need restock'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, valueAnim, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - valueAnim)),
          child: Opacity(opacity: valueAnim, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _buildCardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleTile(Map<String, dynamic> sale) {
    final createdAt =
        DateTime.tryParse(sale['created_at']?.toString() ?? '') ??
        DateTime.now();
    final quantity = (sale['quantity'] as num?)?.toInt() ?? 0;
    final total = (sale['total_price'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$quantity item${quantity == 1 ? '' : 's'} sold',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatPHP(total),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d, h:mm a').format(createdAt.toLocal()),
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ==================== MY SHOP SETTINGS ====================
  Widget _buildMyShopSettings(Map<String, dynamic> clientData) {
    _initializeShopForm(clientData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Store Profile',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your store information and branding',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _buildCardDecoration(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              return isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatarSection(),
                        const SizedBox(width: 32),
                        Expanded(child: _buildShopForm()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildAvatarSection(),
                        const SizedBox(height: 32),
                        _buildShopForm(),
                      ],
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: CircleAvatar(
                radius: 58,
                backgroundColor: Colors.white,
                backgroundImage: _shopAvatarBytes != null
                    ? MemoryImage(_shopAvatarBytes!)
                    : (_shopAvatarUrl != null
                          ? NetworkImage(_shopAvatarUrl!)
                          : null),
                child: (_shopAvatarBytes == null && _shopAvatarUrl == null)
                    ? const Icon(
                        Icons.store,
                        size: 50,
                        color: AppTheme.primaryColor,
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: _uploadAvatar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _shopAvatarName ?? 'No logo uploaded',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildShopForm() {
    return Column(
      children: [
        _buildTextField('Shop Name', _shopName, (val) => _shopName = val),
        const SizedBox(height: 16),
        _buildCategoryDropdown(),
        const SizedBox(height: 16),
        _buildTextField(
          'Phone Number',
          _shopPhone,
          (val) => _shopPhone = val,
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Address',
          _shopAddress,
          (val) => _shopAddress = val,
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSavingShop ? null : _saveShopSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSavingShop
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String) onChanged, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _shopCategoryOptions.any((opt) => opt['value'] == _shopCategory)
          ? _shopCategory
          : null,
      decoration: InputDecoration(
        labelText: 'Business Category',
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _shopCategoryOptions
          .map(
            (opt) => DropdownMenuItem(
              value: opt['value'],
              child: Text(opt['label']!),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _shopCategory = val ?? ''),
    );
  }

  // ==================== PRODUCTS ====================
  Widget _buildProducts(Map<String, dynamic> clientData) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_id', clientData['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        final products = snapshot.data ?? [];
        final activeCount = products
            .where((p) => p['is_active'] == true)
            .length;
        final lowStockCount = products
            .where((p) => (p['stock_quantity'] as int? ?? 0) <= 5)
            .length;
        final totalValue = products.fold(
          0.0,
          (sum, p) =>
              sum +
              ((p['price'] as num?)?.toDouble() ?? 0) *
                  ((p['stock_quantity'] as num?)?.toDouble() ?? 0),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Product Catalog',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showAddProductDialog(clientData['id'] as String),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total: ${products.length}',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Active: $activeCount',
                    style: TextStyle(color: AppTheme.successColor),
                  ),
                ),
                const SizedBox(width: 8),
                if (lowStockCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Low Stock: $lowStockCount',
                      style: TextStyle(color: AppTheme.warningColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Inventory Value Card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Inventory Value',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          formatPHP(totalValue),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (products.isEmpty)
              _buildEmptyProductsState()
            else
              _buildProductGrid(products),
          ],
        );
      },
    );
  }

  Widget _buildEmptyProductsState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: _buildCardDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding products to sell to your customers',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddProductDialog(''),
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final stock = (product['stock_quantity'] as int?) ?? 0;
        final isLowStock = stock <= 5;
        final isOutOfStock = stock == 0;
        final price = (product['price'] as num?)?.toDouble() ?? 0;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 220 + ((index % 6) * 40)),
          curve: Curves.easeOutCubic,
          builder: (context, animationValue, child) {
            return Transform.translate(
              offset: Offset(0, 18 * (1 - animationValue)),
              child: Opacity(opacity: animationValue, child: child),
            );
          },
          child: Container(
            decoration: _buildCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: product['image_url'] != null
                            ? Image.network(
                                product['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppTheme.surfaceColor,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                              )
                            : Container(
                                color: AppTheme.surfaceColor,
                                child: const Icon(
                                  Icons.image,
                                  size: 50,
                                  color: AppTheme.textSecondary,
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
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else if (isLowStock)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Low Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: PopupMenuButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  product['is_active'] == true
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ),
                            ],
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showEditProductDialog(product);
                              } else if (action == 'toggle') {
                                _toggleProductStatus(product);
                              } else if (action == 'delete') {
                                _confirmDeleteProduct(
                                  product['id'],
                                  product['name'],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'Unnamed',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatPHP(price),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: product['is_active'] == true
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product['is_active'] == true
                                  ? 'Active'
                                  : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                color: product['is_active'] == true
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stock: $stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLowStock
                                  ? AppTheme.warningColor
                                  : AppTheme.textSecondary,
                              fontWeight: isLowStock
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
      },
    );
  }

  Future<void> _toggleProductStatus(Map<String, dynamic> product) async {
    try {
      await Supabase.instance.client
          .from('products')
          .update({'is_active': product['is_active'] != true})
          .eq('id', product['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product ${product['is_active'] == true ? 'deactivated' : 'activated'}',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() => _clientDataFuture = _fetchClientData());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ==================== ANALYTICS ====================
  Widget _buildAnalytics(Map<String, dynamic> clientData) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_id', clientData['id']),
      builder: (context, productsSnapshot) {
        final products = productsSnapshot.data ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('order_items')
              .stream(primaryKey: ['id'])
              .eq('business_id', clientData['id']),
          builder: (context, ordersSnapshot) {
            final orderItems = ordersSnapshot.data ?? [];

            final activeProducts = products
                .where((p) => p['is_active'] == true)
                .length;
            final lowStockProducts = products
                .where((p) => (p['stock_quantity'] as int? ?? 0) <= 5)
                .toList();
            final totalInventoryValue = products.fold(
              0.0,
              (sum, p) =>
                  sum +
                  ((p['price'] as num?)?.toDouble() ?? 0) *
                      ((p['stock_quantity'] as num?)?.toDouble() ?? 0),
            );
            final averagePrice = products.isEmpty
                ? 0.0
                : products.fold(
                        0.0,
                        (sum, p) =>
                            sum + ((p['price'] as num?)?.toDouble() ?? 0),
                      ) /
                      products.length;

            final totalRevenue = orderItems.fold(
              0.0,
              (sum, item) =>
                  sum + ((item['total_price'] as num?)?.toDouble() ?? 0),
            );
            final totalOrders = orderItems
                .map((item) => item['order_id']?.toString())
                .whereType<String>()
                .toSet()
                .length;
            final totalUnitsSold = orderItems.fold(
              0,
              (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
            );

            final categoryCount = <String, int>{};
            for (final product in products) {
              final category = product['category'] ?? 'Uncategorized';
              categoryCount[category] = (categoryCount[category] ?? 0) + 1;
            }

            final sortedProducts = [...products]
              ..sort(
                (a, b) => ((b['price'] as num?)?.toDouble() ?? 0).compareTo(
                  (a['price'] as num?)?.toDouble() ?? 0,
                ),
              );
            final topProducts = sortedProducts.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insights, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Business Insights',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'AI-powered analytics to grow your business',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900
                      ? 4
                      : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard(
                      'Total Products',
                      products.length.toString(),
                      Icons.inventory,
                      AppTheme.primaryColor,
                    ),
                    _buildStatCard(
                      'Active Products',
                      activeProducts.toString(),
                      Icons.check_circle,
                      AppTheme.successColor,
                    ),
                    _buildStatCard(
                      'Total Revenue',
                      formatPHP(totalRevenue),
                      Icons.attach_money,
                      AppTheme.secondaryColor,
                    ),
                    _buildStatCard(
                      'Total Orders',
                      totalOrders.toString(),
                      Icons.receipt_long,
                      AppTheme.warningColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: _buildCardDecoration(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.category,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Category Distribution',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ...categoryCount.entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                entry.key,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: LinearProgressIndicator(
                                                value:
                                                    entry.value /
                                                    products.length,
                                                backgroundColor:
                                                    AppTheme.dividerColor,
                                                color: AppTheme.primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              entry.value.toString(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: _buildCardDecoration(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.successColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.trending_up,
                                            color: AppTheme.successColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Performance Metrics',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildMetricRow(
                                      'Conversion Rate',
                                      '${totalOrders > 0 ? ((totalUnitsSold / totalOrders) * 100).toStringAsFixed(1) : '0'}%',
                                      AppTheme.secondaryColor,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMetricRow(
                                      'Avg Order Value',
                                      formatPHP(
                                        totalOrders > 0
                                            ? totalRevenue / totalOrders
                                            : 0,
                                      ),
                                      AppTheme.primaryColor,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMetricRow(
                                      'Units per Order',
                                      totalOrders > 0
                                          ? (totalUnitsSold / totalOrders)
                                                .toStringAsFixed(1)
                                          : '0',
                                      AppTheme.warningColor,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMetricRow(
                                      'Inventory Turnover',
                                      products.isEmpty
                                          ? '0'
                                          : (totalUnitsSold / products.length)
                                                .toStringAsFixed(1),
                                      AppTheme.successColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isWide) const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              if (lowStockProducts.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.warningColor.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            color: AppTheme.warningColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Low Stock Alert',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.warningColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...lowStockProducts
                                          .take(3)
                                          .map(
                                            (product) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      product['name'] ??
                                                          'Unknown',
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Stock: ${product['stock_quantity']}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.warningColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      if (lowStockProducts.length > 3)
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _currentSection = 2,
                                          ),
                                          child: Text(
                                            'View all (${lowStockProducts.length})',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: _buildCardDecoration(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondaryColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.star,
                                            color: AppTheme.secondaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Top Products by Price',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ...topProducts.asMap().entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${entry.key + 1}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.value['name'] ??
                                                        'Unknown',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                  Text(
                                                    formatPHP(
                                                      (entry.value['price']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    entry.value['is_active'] ==
                                                        true
                                                    ? AppTheme.successColor
                                                          .withOpacity(0.1)
                                                    : AppTheme.errorColor
                                                          .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                entry.value['is_active'] == true
                                                    ? 'Active'
                                                    : 'Inactive',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      entry.value['is_active'] ==
                                                          true
                                                      ? AppTheme.successColor
                                                      : AppTheme.errorColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.secondaryColor.withOpacity(0.1),
                                      AppTheme.primaryColor.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Recommended Actions',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (lowStockProducts.isNotEmpty)
                                      _buildActionSuggestion(
                                        'Restock ${lowStockProducts.length} low inventory items',
                                        Icons.inventory,
                                        AppTheme.warningColor,
                                      ),
                                    if (averagePrice < 500)
                                      _buildActionSuggestion(
                                        'Consider premium product bundle to increase AOV',
                                        Icons.inventory_2,
                                        AppTheme.secondaryColor,
                                      ),
                                    if (products.isEmpty)
                                      _buildActionSuggestion(
                                        'Add your first product to start selling',
                                        Icons.add_box,
                                        AppTheme.primaryColor,
                                      ),
                                    _buildActionSuggestion(
                                      'Run a promotion on top-performing items',
                                      Icons.local_offer,
                                      AppTheme.successColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildActionSuggestion(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13))),
          Icon(Icons.arrow_forward, color: color, size: 16),
        ],
      ),
    );
  }

  // ==================== SETTINGS ====================
  Widget _buildSettings(Map<String, dynamic> clientData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferences',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: _buildCardDecoration(),
          child: Column(
            children: [
              _buildSettingsTile(
                'Email Notifications',
                Icons.email_outlined,
                _emailNotifications,
                (val) => setState(() => _emailNotifications = val),
                onTap: () =>
                    _showSettingsMessage('Email Notifications toggled'),
              ),
              _buildSettingsTile(
                'Push Notifications',
                Icons.notifications_outlined,
                _pushNotifications,
                (val) => setState(() => _pushNotifications = val),
                onTap: () => _showSettingsMessage('Push Notifications toggled'),
              ),
              _buildSettingsTile(
                'Dark Mode',
                Icons.dark_mode_outlined,
                _darkMode,
                (val) {
                  setState(() => _darkMode = val);
                  _showSettingsMessage(
                    'Dark Mode ${val ? "enabled" : "disabled"}',
                  );
                },
              ),
              _buildSettingsTile(
                'Sound Effects',
                Icons.volume_up_outlined,
                _soundEffects,
                (val) => setState(() => _soundEffects = val),
                onTap: () => _showSettingsMessage('Sound Effects toggled'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Account',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: _buildCardDecoration(),
          child: Column(
            children: [
              _buildSettingsTile(
                'Change Password',
                Icons.lock_outline,
                null,
                null,
                isSwitch: false,
                onTap: _showChangePasswordDialog,
              ),
              _buildSettingsTile(
                'Language',
                Icons.language_outlined,
                null,
                null,
                isSwitch: false,
                value: 'English',
                onTap: _showLanguageDialog,
              ),
              _buildSettingsTile(
                'Export Data',
                Icons.download_outlined,
                null,
                null,
                isSwitch: false,
                onTap: _exportData,
              ),
              _buildSettingsTile(
                'About',
                Icons.info_outline,
                null,
                null,
                isSwitch: false,
                onTap: _showAboutDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Store ID', clientData['id']?.toString() ?? 'N/A'),
              _buildInfoRow(
                'Member Since',
                DateFormat('MMM d, yyyy').format(DateTime.now()),
              ),
              _buildInfoRow('Account Type', 'Business Account'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showSettingsMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showChangePasswordDialog() {
    _showSettingsMessage('Change Password feature coming soon');
  }

  void _showLanguageDialog() {
    _showSettingsMessage('Language selection coming soon');
  }

  void _exportData() {
    _showSettingsMessage('Exporting your data...');
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront,
              size: 48,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Seller Centre',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your complete solution for managing your beauty business online.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    IconData icon,
    bool? switchValue,
    Function(bool)? onSwitchChange, {
    bool isSwitch = true,
    String? value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(title),
      trailing: isSwitch
          ? Switch(
              value: switchValue!,
              onChanged: onSwitchChange,
              activeColor: AppTheme.primaryColor,
            )
          : (value != null
                ? Text(value, style: TextStyle(color: AppTheme.textSecondary))
                : const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  )),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onTap: onTap,
    );
  }

  // ==================== Helper Methods ====================
  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppTheme.cardShadow,
    );
  }

  void _showAddProductDialog(String businessId) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _AddProductDialog(businessId: businessId),
    );
    if (saved == true && mounted) {
      setState(() => _clientDataFuture = _fetchClientData());
    }
  }

  void _showEditProductDialog(Map<String, dynamic> product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditProductDialog(product: product),
    );
    if (saved == true && mounted) {
      setState(() => _clientDataFuture = _fetchClientData());
    }
  }

  void _confirmDeleteProduct(dynamic productId, dynamic productName) async {
    final id = productId?.toString();
    final name = (productName ?? 'this product').toString();
    if (id == null || id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('products').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          setState(() => _clientDataFuture = _fetchClientData());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
}

// ==================== ADD PRODUCT DIALOG ====================
class _AddProductDialog extends StatefulWidget {
  final String businessId;
  const _AddProductDialog({required this.businessId});

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _imagePreviewUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final _imagePicker = ImagePicker();
  String? _selectedCategory;
  bool _isLoading = false;
  bool _isFetchingMetadata = false;

  final _categories = [
    'Lipstick',
    'Blush',
    'Foundation',
    'Concealer',
    'Eyeshadow',
    'Eyeliner',
    'Mascara',
    'Eyebrow',
    'Tools & Brushes',
  ];
  final List<Map<String, dynamic>> _variations = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Product',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  _nameController,
                  'Product Name',
                  validator: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _priceController,
                        'Price (PHP)',
                        keyboard: TextInputType.number,
                        validator: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        _stockController,
                        'Stock',
                        keyboard: TextInputType.number,
                        validator: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                _buildTextField(
                  _descriptionController,
                  'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildLinkField(),
                const SizedBox(height: 16),
                _buildImageSection(),
                const SizedBox(height: 16),
                _buildVariationsSection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Product'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    bool validator = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator
          ? (v) => v == null || v.isEmpty ? 'Required' : null
          : null,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      items: _categories
          .map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => _selectedCategory = v),
      validator: (v) => v == null ? 'Select category' : null,
    );
  }

  Widget _buildLinkField() {
    return TextFormField(
      controller: _linkController,
      decoration: InputDecoration(
        labelText: 'Product Link (Optional)',
        hintText: 'Paste Shopee or Lazada link to auto-fill',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: _isFetchingMetadata
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                ),
                onPressed: _fetchMetadata,
                tooltip: 'Auto-fill from link',
              ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: _selectedImageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                )
              : _imagePreviewUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_imagePreviewUrl!, fit: BoxFit.cover),
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 40),
                      SizedBox(height: 8),
                      Text('No image selected'),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload),
                label: const Text('Upload Image'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _imageUrlController,
                onChanged: (v) => setState(() => _imagePreviewUrl = v),
                decoration: InputDecoration(
                  hintText: 'Image URL',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariationsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Variations (Colors/Shades)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _variations.add({
                  'name': '',
                  'hex': '#FFFFFF',
                  'price': _priceController.text.isNotEmpty
                      ? _priceController.text
                      : '0',
                  'stock': _stockController.text.isNotEmpty
                      ? _stockController.text
                      : '0',
                  'imageUrl': null,
                  'imageBytes': null,
                  'imageName': null,
                });
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Variation'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_variations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No variations added. Product will have only one base version.',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
        ..._variations.asMap().entries.map(
          (entry) => _buildVariationCard(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildVariationCard(int index, Map<String, dynamic> variation) {
    final hexController = TextEditingController(
      text: variation['hex'] ?? '#FFFFFF',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Variation ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                onPressed: () => setState(() => _variations.removeAt(index)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: variation['name'],
                  decoration: const InputDecoration(
                    labelText: 'Color/Shade Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  onChanged: (val) => variation['name'] = val,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: hexController,
                  decoration: const InputDecoration(
                    labelText: 'Hex Code',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  onChanged: (val) => variation['hex'] = val,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: variation['price']?.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Price (PHP)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => variation['price'] = val,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: variation['stock']?.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => variation['stock'] = val,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: variation['imageUrl'],
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  onChanged: (val) => variation['imageUrl'] = val,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickVariationImage(index),
                icon: const Icon(Icons.upload, size: 16),
                label: Text(
                  variation['imageBytes'] != null ? 'Change' : 'Upload',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  side: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          if (variation['imageBytes'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: MemoryImage(variation['imageBytes']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickVariationImage(int index) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _variations[index]['imageBytes'] = bytes;
        _variations[index]['imageName'] = picked.name;
      });
    }
  }

  Future<void> _fetchMetadata() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a product link'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isFetchingMetadata = true);

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) throw 'Invalid URL';

      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        String? productName =
            document
                .querySelector('meta[property="og:title"]')
                ?.attributes['content'] ??
            document.querySelector('title')?.text;

        if (productName != null && productName.contains('|')) {
          productName = productName.split('|')[0].trim();
        }

        String? priceStr = document
            .querySelector('meta[property="product:price:amount"]')
            ?.attributes['content'];
        double? price;
        if (priceStr != null) {
          final priceMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(priceStr);
          if (priceMatch != null) {
            price = double.tryParse(priceMatch.group(1)!);
          }
        }

        String? description = document
            .querySelector('meta[name="description"]')
            ?.attributes['content'];
        String? imageUrl = document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'];

        String? guessedCategory;
        if (productName != null) {
          guessedCategory = _guessCategory(productName);
        }

        setState(() {
          if (productName != null &&
              productName.isNotEmpty &&
              _nameController.text.isEmpty) {
            _nameController.text = productName;
          }
          if (price != null && price > 0 && _priceController.text.isEmpty) {
            _priceController.text = price.toStringAsFixed(2);
          }
          if (description != null &&
              description.isNotEmpty &&
              _descriptionController.text.isEmpty) {
            _descriptionController.text = description;
          }
          if (imageUrl != null &&
              imageUrl.isNotEmpty &&
              _imagePreviewUrl == null) {
            _imagePreviewUrl = imageUrl;
            _imageUrlController.text = imageUrl;
          }
          if (guessedCategory != null && _selectedCategory == null) {
            _selectedCategory = guessedCategory;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product details extracted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch product details'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() => _isFetchingMetadata = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = picked.name;
        _imagePreviewUrl = null;
        _imageUrlController.clear();
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedImageBytes == null && _imagePreviewUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add an image (upload or URL)'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _imagePreviewUrl;

      if (_selectedImageBytes != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedImageName ?? 'product.jpg'}';
        await Supabase.instance.client.storage
            .from('products')
            .uploadBinary(fileName, _selectedImageBytes!);
        imageUrl = Supabase.instance.client.storage
            .from('products')
            .getPublicUrl(fileName);
      }

      final processedVariations = <Map<String, dynamic>>[];
      for (final variation in _variations) {
        String? varImageUrl = variation['imageUrl'];

        if (variation['imageBytes'] != null) {
          final varFileName =
              '${DateTime.now().millisecondsSinceEpoch}_var_${variation['imageName'] ?? 'variant.jpg'}';
          await Supabase.instance.client.storage
              .from('products')
              .uploadBinary(varFileName, variation['imageBytes']);
          varImageUrl = Supabase.instance.client.storage
              .from('products')
              .getPublicUrl(varFileName);
        }

        processedVariations.add({
          'color_name': variation['name'] ?? '',
          'hex_code': variation['hex'] ?? '#FFFFFF',
          'price':
              double.tryParse(variation['price']?.toString() ?? '0') ??
              double.parse(_priceController.text),
          'stock':
              int.tryParse(variation['stock']?.toString() ?? '0') ??
              int.parse(_stockController.text),
          'image_url': varImageUrl,
        });
      }

      final productData = {
        'business_id': widget.businessId,
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock_quantity': int.parse(_stockController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'image_url': imageUrl,
        'product_link': _linkController.text.trim().isEmpty
            ? null
            : _linkController.text.trim(),
        'variations': processedVariations,
        'is_active': true,
      };

      await Supabase.instance.client.from('products').insert(productData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}

// ==================== EDIT PRODUCT DIALOG ====================
class _EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  const _EditProductDialog({required this.product});

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  late TextEditingController _linkController;
  late TextEditingController _imageUrlController;
  String? _selectedCategory;
  bool _isActive = true;
  bool _isLoading = false;

  final _categories = [
    'Lipstick',
    'Blush',
    'Foundation',
    'Concealer',
    'Eyeshadow',
    'Eyeliner',
    'Mascara',
    'Eyebrow',
    'Tools & Brushes',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['name']);
    _priceController = TextEditingController(
      text: widget.product['price'].toString(),
    );
    _stockController = TextEditingController(
      text: widget.product['stock_quantity'].toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.product['description'] ?? '',
    );
    _linkController = TextEditingController(
      text: widget.product['product_link'] ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.product['image_url'] ?? '',
    );
    _selectedCategory = widget.product['category'];
    _isActive = widget.product['is_active'] ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Product',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  _nameController,
                  'Product Name',
                  validator: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _priceController,
                        'Price',
                        keyboard: TextInputType.number,
                        validator: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        _stockController,
                        'Stock',
                        keyboard: TextInputType.number,
                        validator: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                _buildTextField(
                  _descriptionController,
                  'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildTextField(_linkController, 'Product Link'),
                const SizedBox(height: 16),
                _buildImageField(),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    bool validator = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator
          ? (v) => v == null || v.isEmpty ? 'Required' : null
          : null,
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = [..._categories];
    if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
      categories.add(_selectedCategory!);
    }
    categories.sort();

    return DropdownButtonFormField<String?>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      items: categories
          .map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => _selectedCategory = v),
    );
  }

  Widget _buildImageField() {
    return TextFormField(
      controller: _imageUrlController,
      decoration: InputDecoration(
        labelText: 'Image URL',
        hintText: 'https://example.com/image.jpg',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('products')
          .update({
            'name': _nameController.text.trim(),
            'price': double.parse(_priceController.text.trim()),
            'stock_quantity': int.parse(_stockController.text.trim()),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'product_link': _linkController.text.trim().isEmpty
                ? null
                : _linkController.text.trim(),
            'image_url': _imageUrlController.text.trim().isEmpty
                ? null
                : _imageUrlController.text.trim(),
            'is_active': _isActive,
          })
          .eq('id', widget.product['id']);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}
