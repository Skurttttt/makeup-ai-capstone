// lib/screens/client_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'client_analytics_screen.dart';
import 'client_dashboard_screen.dart';
import 'client_product_screen.dart';
import 'product_form_page.dart';
import 'client_settings_screen.dart';
import 'client_shop_screen.dart';
import '../utils/logout_util.dart';
import 'chat_list_screen.dart';
import 'client_orders_screen.dart';
import '../services/notification_service.dart';
import '../widgets/notification_bell.dart';

// Minimal app theme fallback used by this screen when the shared theme
// import is missing — keeps the file self-contained for analyzer.
class AppTheme {
  static const primaryColor = Color(0xFFFF4D97);
  static const primaryDark = Color(0xFFCC3A7A);
  static const successColor = Colors.green;
  static const errorColor = Colors.red;
  static const warningColor = Colors.orange;
  static const secondaryColor = Colors.blueGrey;
  static const cardColor = Color(0xFFF8F8F8);
  static const surfaceColor = Colors.white;
  static const textPrimary = Colors.black87;
  static const textSecondary = Colors.black54;
  static const dividerColor = Colors.grey;
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFFF4D97), Color(0xFFFF8FB3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const boxShadow = [
    BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static List<BoxShadow> get cardShadow => boxShadow;
}

Color contrastTextForBackground(Color bg) {
  return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

class NumericSpinnerField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool isDecimal;
  final num step;
  final String? suffix;
  final bool enabled;
  final ValueChanged<num>? onChanged;

  const NumericSpinnerField({
    super.key,
    required this.controller,
    required this.label,
    this.isDecimal = false,
    this.step = 1,
    this.suffix,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<NumericSpinnerField> createState() => _NumericSpinnerFieldState();
}

class _NumericSpinnerFieldState extends State<NumericSpinnerField> {
  num _parseValue() {
    final text = widget.controller.text;
    if (text.isEmpty) return 0;
    return num.tryParse(text) ?? 0;
  }

  void _updateValue(num value) {
    final isDecimal = widget.isDecimal;
    final asDouble = value.toDouble();
    final out = isDecimal
        ? (asDouble % 1 == 0
              ? asDouble.toStringAsFixed(0)
              : asDouble.toString())
        : value.round().toString();
    widget.controller.text = out;
    widget.controller.selection = TextSelection.collapsed(offset: out.length);
    setState(() {});
    try {
      widget.onChanged?.call(value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: widget.enabled
              ? () => _updateValue(_parseValue() - widget.step)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppTheme.primaryColor,
          splashRadius: 20,
        ),
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            keyboardType: widget.isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffix,
            ),
            onChanged: (s) {
              final parsed = num.tryParse(s) ?? 0;
              widget.onChanged?.call(parsed);
            },
          ),
        ),
        IconButton(
          onPressed: widget.enabled
              ? () => _updateValue(_parseValue() + widget.step)
              : null,
          icon: const Icon(Icons.add_circle_outline),
          color: AppTheme.primaryColor,
          splashRadius: 20,
        ),
      ],
    );
  }
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
  if (lowerText.contains('lipstick') || lowerText.contains('lip gloss')) {
    return 'Lipstick';
  }
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

bool _isPlaceholderShopeeDescription(String? description) {
  final text = description?.trim().toLowerCase();
  if (text == null || text.isEmpty) return true;
  return text.contains('shopee blocked structured scraping') ||
      text.contains('only the title could be recovered') ||
      text.contains('fill remaining details manually') ||
      text.contains('title-only') ||
      text.contains('could not load structured product data') ||
      text.contains('could not recover structured product data');
}

// ==================== MAIN SCREEN ====================
class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  int _currentSection = 0;
  late Future<Map<String, dynamic>> _clientDataFuture;
  StreamSubscription<AppNotification>? _notifSub;
  int _productsRefreshTick = 0;

  @override
  void initState() {
    super.initState();
    _clientDataFuture = _fetchClientData().then((data) {
      _initNotifications(data);
      return data;
    });
  }

  void _initNotifications(Map<String, dynamic> data) {
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) return;
    NotificationService.instance.start(id);
    _notifSub?.cancel();
    _notifSub =
        NotificationService.instance.onNewNotification.listen(_pingUser);
  }

  void _pingUser(AppNotification n) {
    // CRITICAL: defer ALL work past the current frame.
    // The notification arrives via a Supabase realtime stream listener which
    // may fire during a mouse-tracker device update or layout pass. Calling
    // showSnackBar / playing sounds / haptics synchronously from inside that
    // phase triggers `_debugDuringDeviceUpdate` and `_debugDoingThisLayout`
    // assertion cascades that look like layout corruption.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final color = switch (n.type) {
        AppNotificationType.order => const Color(0xFF22C55E),
        AppNotificationType.lowStock => const Color(0xFFFF9800),
        AppNotificationType.message => AppTheme.primaryColor,
      };
      final icon = switch (n.type) {
        AppNotificationType.order => Icons.shopping_bag_rounded,
        AppNotificationType.lowStock => Icons.inventory_2_rounded,
        AppNotificationType.message => Icons.chat_bubble_rounded,
      };
      // Audio + haptic feedback. New orders get a stronger "ding-ding"
      // double alert so sellers notice even when not looking at the screen.
      if (n.type == AppNotificationType.order) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        Future.delayed(const Duration(milliseconds: 220), () {
          SystemSound.play(SystemSoundType.alert);
        });
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => showNotificationSheet(context),
        ),
      ),
    );
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
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

  void _setSection(int index) {
    if (_currentSection == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentSection = index);
  }

  void _logout() {
    showLogoutConfirmationDialog(context, role: 'client');
  }

  Future<void> _refreshClientData() async {
    final refreshed = _fetchClientData();
    setState(() => _clientDataFuture = refreshed);
    await refreshed;
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
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final clientData = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Use 600px (Material 3 compact breakpoint) so phones in landscape
            // and small tablets in portrait still get the mobile bottom-nav
            // layout, while real tablets/desktops get the sidebar.
            final isDesktop = constraints.maxWidth >= 900;
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
                        _buildNavItem(Icons.receipt_long_outlined, 'Orders', 4),
                        _buildNavItem(Icons.settings_outlined, 'Settings', 5),
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            const NotificationBell(
                              iconColor: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.store,
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        clientData['business_name'] ?? 'My Store',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
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
          overflow: TextOverflow.ellipsis,
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
          const NotificationBell(),
          IconButton(
            tooltip: 'Customer Messages',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChatListScreen(sellerMode: true),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      kBottomNavigationBarHeight -
                      MediaQuery.of(context).padding.vertical,
                ),
                child: _buildAnimatedSectionContent(clientData),
              ),
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
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Orders',
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
      'Orders',
      'Settings',
    ];
    return titles[_currentSection];
  }

  Widget _buildSectionContent(Map<String, dynamic> clientData) {
    switch (_currentSection) {
      case 0:
        return ClientDashboardScreen(clientData: clientData);
      case 1:
        return ClientShopScreen(clientData: clientData);
      case 2:
        return ClientProductsSection(
          clientData: clientData,
          onAddProduct: _showAddProductDialog,
          onEditProduct: _showEditProductDialog,
          onDeleteProduct: _confirmDeleteProduct,
          onToggleProductStatus: _toggleProductStatus,
          refreshTick: _productsRefreshTick,
        );
      case 3:
        return ClientAnalyticsScreen(clientData: clientData);
      case 4:
        return ClientOrdersScreen(clientData: clientData);
      case 5:
        return ClientSettingsScreen(clientData: clientData);
      default:
        return const SizedBox();
    }
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
        // Force the products stream to re-subscribe so the new is_active
        // value is reflected immediately even if realtime hasn't pushed yet.
        setState(() => _productsRefreshTick++);
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


  void _showAddProductDialog(String businessId) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProductFormPage(businessId: businessId),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _currentSection = 2;
        _clientDataFuture = _fetchClientData();
      });
    }
  }

  void _showEditProductDialog(Map<String, dynamic> product) async {
    final businessId = product['business_id']?.toString() ?? '';
    if (businessId.isEmpty) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProductFormPage(
          businessId: businessId,
          existingProduct: product,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _clientDataFuture = _fetchClientData();
      });
    }
  }

  void _confirmDeleteProduct(dynamic productId, dynamic productName) async {
    final id = productId?.toString();
    final name = (productName ?? 'this product').toString();
    if (id == null || id.isEmpty) return;

    // Check whether this product is referenced by any orders
    bool hasOrders = false;
    try {
      final rows = await Supabase.instance.client
          .from('order_items')
          .select('id')
          .eq('product_id', id)
          .limit(1);
      hasOrders = (rows as List).isNotEmpty;
    } catch (_) {
      hasOrders = true; // safer to assume it has orders on error
    }

    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Remove Product',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(name,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: hasOrders
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: hasOrders
                          ? Colors.red.shade200
                          : Colors.orange.shade200)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 16,
                    color: hasOrders
                        ? Colors.red.shade700
                        : Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasOrders
                        ? 'This product has order history and cannot be permanently deleted. Use Archive to hide it from the marketplace.'
                        : 'Archiving hides the product but keeps order history intact.',
                    style: TextStyle(
                        fontSize: 12,
                        color: hasOrders
                            ? Colors.red.shade800
                            : Colors.orange.shade800),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'archive'),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Archive (Recommended)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasOrders ? null : () => Navigator.pop(ctx, 'delete'),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Delete Permanently'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasOrders ? Colors.grey.shade300 : Colors.red.shade500,
                  foregroundColor:
                      hasOrders ? Colors.grey.shade500 : Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel') return;

    try {
      if (action == 'archive') {
        await Supabase.instance.client
            .from('products')
            .update({'is_active': false}).eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Product archived'),
            backgroundColor: Colors.orange,
          ));
          setState(() => _productsRefreshTick++);
        }
        return;
      }

      // Delete permanently — only reachable when hasOrders == false
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Product deleted permanently'),
          backgroundColor: Colors.green,
        ));
        setState(() => _productsRefreshTick++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
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
    'Contour',
    'Setting Spray',
    'Eyebrow',
    'Eyeliner',
    'Concealer',
    'Eyeshadow',
    'Tools & Brushes',
  ];
  final List<Map<String, dynamic>> _variations = [];

  static const List<Map<String, String>> _defaultColorPalette = [
    {'name': 'Black', 'hex': '#000000'},
    {'name': 'White', 'hex': '#FFFFFF'},
    {'name': 'Red', 'hex': '#E53935'},
    {'name': 'Pink', 'hex': '#EC4899'},
    {'name': 'Rose', 'hex': '#F43F5E'},
    {'name': 'Coral', 'hex': '#FF6F61'},
    {'name': 'Peach', 'hex': '#FFB085'},
    {'name': 'Nude', 'hex': '#D2A48C'},
    {'name': 'Beige', 'hex': '#E8DCCB'},
    {'name': 'Sand', 'hex': '#D8C3A5'},
    {'name': 'Almond', 'hex': '#C8A27A'},
    {'name': 'Caramel', 'hex': '#B87333'},
    {'name': 'Taupe', 'hex': '#8B7D6B'},
    {'name': 'Brown', 'hex': '#8D6E63'},
    {'name': 'Cocoa', 'hex': '#7B4B2A'},
    {'name': 'Chestnut', 'hex': '#6B3F2A'},
    {'name': 'Mocha', 'hex': '#6D4C41'},
    {'name': 'Burgundy', 'hex': '#7B1E3A'},
    {'name': 'Wine', 'hex': '#722F37'},
    {'name': 'Plum', 'hex': '#7C3AED'},
    {'name': 'Mauve', 'hex': '#C08497'},
    {'name': 'Lavender', 'hex': '#B57EDC'},
    {'name': 'Lilac', 'hex': '#C8A2C8'},
    {'name': 'Purple', 'hex': '#8E24AA'},
    {'name': 'Blue', 'hex': '#1E88E5'},
    {'name': 'Matcha', 'hex': '#9FCB7C'},
    {'name': 'Green', 'hex': '#10B981'},
    {'name': 'Yellow', 'hex': '#F59E0B'},
    {'name': 'Orange', 'hex': '#F97316'},
    {'name': 'Terracotta', 'hex': '#E2725B'},
    {'name': 'Bronze', 'hex': '#CD7F32'},
    {'name': 'Copper', 'hex': '#B87333'},
    {'name': 'Gold', 'hex': '#D4AF37'},
    {'name': 'Silver', 'hex': '#C0C0C0'},
    {'name': 'Gray', 'hex': '#94A3B8'},
  ];
  List<Map<String, String>> _colorPalette = [];

  String _normalizeHexColor(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '#FFFFFF';
    var hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!RegExp(r'^[0-9A-Fa-f]{3}$|^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return '#FFFFFF';
    }
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    return '#${hex.toUpperCase()}';
  }

  String _hexFromColor(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  Color _colorFromHex(String hex) {
    final normalized = _normalizeHexColor(hex).substring(1);
    final value = int.parse(normalized, radix: 16);
    return Color(0xFF000000 | value);
  }

  int _colorDistance(Color a, Color b) {
    final dr = a.red - b.red;
    final dg = a.green - b.green;
    final db = a.blue - b.blue;
    return dr * dr + dg * dg + db * db;
  }

  String _normalizeColorName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _hexForColorName(String name) {
    final normalized = _normalizeColorName(name);
    if (normalized.isEmpty) return null;
    for (final entry in _colorPalette) {
      final paletteName = _normalizeColorName(entry['name'] ?? '');
      if (normalized == paletteName || normalized.contains(paletteName)) {
        return entry['hex'];
      }
    }
    return null;
  }

  String? _closestColorName(Color color) {
    String? bestName;
    var bestDistance = 1 << 30;
    for (final entry in _colorPalette) {
      final hex = entry['hex'];
      final name = entry['name'];
      if (hex == null || name == null) continue;
      final candidate = _colorFromHex(hex);
      final distance = _colorDistance(color, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestName = name;
      }
    }
    return bestName;
  }

  Future<void> _persistColorPaletteEntry(String name, String hex) async {
    final normalizedName = name.trim();
    final normalizedHex = _normalizeHexColor(hex);
    if (normalizedName.isEmpty ||
        normalizedHex == '#FFFFFF' && hex.trim().isEmpty) {
      return;
    }

    try {
      await Supabase.instance.client.from('product_colors').insert({
        'name': normalizedName,
        'hex': normalizedHex,
        'is_active': true,
      });
    } catch (e) {
      debugPrint('Failed to persist product color "$normalizedName": $e');
    }
  }

  String _variationHex(Map<String, dynamic> variation) {
    return _normalizeHexColor(variation['hex'] ?? variation['hex_code']);
  }

  int _variationStockValue(Map<String, dynamic> variation) {
    final raw = variation['stock'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _totalVariationStock() {
    return _variations.fold<int>(
      0,
      (sum, variation) => sum + _variationStockValue(variation),
    );
  }

  void _syncProductStockFromVariations() {
    if (_variations.isEmpty) return;
    _stockController.text = _totalVariationStock().toString();
    _stockController.selection = TextSelection.collapsed(
      offset: _stockController.text.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _colorPalette = List<Map<String, String>>.from(_defaultColorPalette);
    _loadColorPalette();
  }

  Future<void> _loadColorPalette() async {
    try {
      final response = await Supabase.instance.client
          .from('product_colors')
          .select('name, hex')
          .eq('is_active', true)
          .order('name');
      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _colorPalette = rows
              .map(
                (row) => {
                  'name': row['name']?.toString() ?? '',
                  'hex': _normalizeHexColor(row['hex']),
                },
              )
              .where((entry) => entry['name']!.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load product colors: $e');
    }
  }

  Future<img.Image?> _loadVariationImage(Map<String, dynamic> variation) async {
    final cached = variation['decodedImage'];
    if (cached is img.Image) return cached;

    Uint8List? bytes = variation['imageBytes'];
    if (bytes == null) {
      final url = variation['imageUrl']?.toString().trim();
      if (url != null && url.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
            variation['imageBytes'] = bytes;
          }
        } catch (_) {}
      }
    }

    if (bytes == null) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      variation['decodedImage'] = decoded;
    }
    return decoded;
  }

  Future<void> _pickColorFromVariationImage(
    int index,
    TapDownDetails details,
    BuildContext imageContext,
  ) async {
    if (!mounted) return;
    final variation = _variations[index];
    final decoded = await _loadVariationImage(variation);
    if (decoded == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image available to pick a color from.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final box = imageContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;

    final dx = details.localPosition.dx.clamp(0.0, size.width - 1);
    final dy = details.localPosition.dy.clamp(0.0, size.height - 1);
    final x = (dx / size.width * decoded.width).floor().clamp(
      0,
      decoded.width - 1,
    );
    final y = (dy / size.height * decoded.height).floor().clamp(
      0,
      decoded.height - 1,
    );

    final pixel = decoded.getPixel(x, y);
    final color = Color.fromARGB(
      255,
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    );
    final hex = _hexFromColor(color);
    final name = _closestColorName(color);

    setState(() {
      variation['hex'] = hex;
      variation['hex_code'] = hex;
      if (name != null) variation['name'] = name;
    });

    final persistedName = (name ?? variation['name'] ?? '').toString();
    await _persistColorPaletteEntry(persistedName, hex);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap dialog width to screen so it never overflows on mobile.
    final dialogWidth = screenWidth < 532 ? screenWidth - 32 : 500.0;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text(
        'Add Product',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QUICK IMPORT SECTION (Top Priority)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D97).withOpacity(0.1),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Quick Import',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildLinkField(),
                      const SizedBox(height: 8),
                      _buildLinkImportActions(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // MANUAL ENTRY SECTION
                _buildTextField(
                  _nameController,
                  'Product Name',
                  validator: true,
                ),
                const SizedBox(height: 16),
                NumericSpinnerField(
                  controller: _priceController,
                  label: 'Price (PHP)',
                  isDecimal: true,
                  step: 1,
                  suffix: 'PHP',
                ),
                const SizedBox(height: 16),
                NumericSpinnerField(
                  controller: _stockController,
                  label: 'Stock',
                  step: 1,
                  enabled: _variations.isEmpty,
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
              : const Text(
                  'Save Product',
                  style: TextStyle(color: Colors.white),
                ),
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
      initialValue: _selectedCategory,
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
      onChanged: (val) => setState(() {}), // Trigger rebuild to show button
      decoration: InputDecoration(
        labelText: 'Product Link',
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        hintText: 'Paste Shopee or product URL',
        prefixIcon: const Icon(Icons.link, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        suffixIcon: _isFetchingMetadata
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildLinkImportActions() {
    final hasLink = _linkController.text.trim().isNotEmpty;
    final parsedUri = Uri.tryParse(_linkController.text.trim());
    final canBulkImport = parsedUri != null && _isShopeeSearchLink(parsedUri);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canBulkImport
                ? '🔍 Shopee search detected - Click below to import matching products'
                : hasLink
                ? '✓ Link ready - Click below to extract product details'
                : '💡 Paste a Shopee product link or search URL to auto-fill details',
            style: TextStyle(
              fontSize: 12,
              color: hasLink ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontWeight: hasLink ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (hasLink) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isFetchingMetadata ? null : _handleLinkAction,
                icon: _isFetchingMetadata
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        canBulkImport
                            ? Icons.file_download_outlined
                            : Icons.auto_awesome,
                      ),
                label: Text(
                  canBulkImport ? 'Import Shopee Search' : 'Extract Details',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
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
                final initialStock = _variations.isEmpty
                    ? (_stockController.text.isNotEmpty
                          ? _stockController.text
                          : '0')
                    : '0';
                _variations.add({
                  'name': '',
                  'hex': '#FFFFFF',
                  'hex_code': '#FFFFFF',
                  'price': _priceController.text.isNotEmpty
                      ? _priceController.text
                      : '0',
                  'stock': initialStock,
                  'imageUrl': null,
                  'imageBytes': null,
                  'imageName': null,
                });
                _syncProductStockFromVariations();
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
    final nameController = TextEditingController(
      text: variation['name']?.toString() ?? '',
    );
    final hexController = TextEditingController(text: _variationHex(variation));

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
                onPressed: () => setState(() {
                  _variations.removeAt(index);
                  _syncProductStockFromVariations();
                }),
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
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Color/Shade Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  onChanged: (val) {
                    variation['name'] = val;
                    final mappedHex = _hexForColorName(val);
                    if (mappedHex != null) {
                      setState(() {
                        variation['hex'] = mappedHex;
                        variation['hex_code'] = mappedHex;
                      });
                    }
                  },
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
                  onChanged: (val) {
                    final normalized = _normalizeHexColor(val);
                    variation['hex'] = normalized;
                    variation['hex_code'] = normalized;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NumericSpinnerField(
                  controller: TextEditingController(
                    text: variation['price']?.toString() ?? '0',
                  ),
                  label: 'Price (PHP)',
                  isDecimal: true,
                  step: 1,
                  suffix: 'PHP',
                  onChanged: (val) => variation['price'] = val,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumericSpinnerField(
                  controller: TextEditingController(
                    text: variation['stock']?.toString() ?? '0',
                  ),
                  label: 'Stock',
                  step: 1,
                  onChanged: (val) {
                    setState(() {
                      variation['stock'] = val;
                      _syncProductStockFromVariations();
                    });
                  },
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
                  onChanged: (val) {
                    setState(() {
                      variation['imageUrl'] = val;
                      variation['imageBytes'] = null;
                      variation['decodedImage'] = null;
                    });
                  },
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
          if (variation['imageBytes'] == null &&
              (variation['imageUrl']?.toString().trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Builder(
                builder: (imageContext) {
                  return GestureDetector(
                    onTapDown: (details) => _pickColorFromVariationImage(
                      index,
                      details,
                      imageContext,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(
                                variation['imageUrl'].toString(),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tap to pick',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (variation['imageBytes'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Builder(
                builder: (imageContext) {
                  return GestureDetector(
                    onTapDown: (details) => _pickColorFromVariationImage(
                      index,
                      details,
                      imageContext,
                    ),
                    child: Stack(
                      children: [
                        Container(
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
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tap to pick',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
        _variations[index]['decodedImage'] = null;
      });
    }
  }

  bool _isShopeeSearchLink(Uri uri) {
    if (!uri.host.contains('shopee')) return false;
    return uri.path.contains('/search') ||
        uri.queryParameters.containsKey('keyword');
  }

  String _normalizeShopeeKeyword(String keyword) {
    return Uri.decodeComponent(keyword.replaceAll('+', ' ')).trim();
  }

  double? _parseShopeePrice(dynamic rawPrice) {
    if (rawPrice == null) return null;
    final numVal = rawPrice is num
        ? rawPrice
        : num.tryParse(rawPrice.toString());
    if (numVal == null) return null;
    final value = numVal.toDouble();
    if (value > 1000000) return value / 100000;
    if (value > 10000) return value / 100;
    return value;
  }

  String? _buildShopeeImageUrl(Map<String, dynamic> item) {
    final candidates = [
      item['image'],
      item['images'],
      item['image_url'],
      item['thumbnail'],
      item['shop_item']?['image'],
      item['shop_item']?['images'],
      item['item_basic']?['image'],
      item['item_basic']?['images'],
      item['item_basic']?['thumbnail'],
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first.toString();
        if (first.isNotEmpty) {
          if (first.startsWith('http')) return first;
          return 'https://cf.shopee.ph/file/$first';
        }
      } else if (raw is String && raw.isNotEmpty) {
        if (raw.startsWith('http')) return raw;
        return 'https://cf.shopee.ph/file/$raw';
      }
    }
    return null;
  }

  String? _extractShopeeDescription(Map<String, dynamic> item) {
    final candidates = [
      item['description'],
      item['item_basic']?['description'],
      item['shop_item']?['description'],
      item['desc'],
      item['item_basic']?['desc'],
    ];
    for (final raw in candidates) {
      final str = raw?.toString().trim();
      if (str != null &&
          str.isNotEmpty &&
          !_isPlaceholderShopeeDescription(str)) {
        return str;
      }
    }
    return null;
  }

  Map<String, String?> _extractShopeeMetadataFromHtml(String html) {
    final document = html_parser.parse(html);

    String? cleanMeta(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty) return null;
      return text.contains('|') ? text.split('|').first.trim() : text;
    }

    return {
      'description': cleanMeta(
        document
            .querySelector('meta[name="description"]')
            ?.attributes['content'],
      ),
      'image': cleanMeta(
        document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'],
      ),
    };
  }

  List<Map<String, dynamic>> _extractShopeeVariations(
    Map<String, dynamic> item,
  ) {
    final variations = <Map<String, dynamic>>[];
    final models = item['models'];
    if (models is! List || models.isEmpty) return variations;

    final tierVariations = item['tier_variations'];
    final optionNames = <String, List<String>>{};
    if (tierVariations is List) {
      for (final tier in tierVariations) {
        if (tier is Map && tier['name'] != null && tier['options'] is List) {
          optionNames[tier['name'].toString()] = (tier['options'] as List)
              .map((option) => option.toString())
              .toList();
        }
      }
    }

    String? imageUrlForModel(Map<String, dynamic> model) {
      final imageKey = model['image'] ?? model['image_url'] ?? model['images'];
      if (imageKey is String && imageKey.isNotEmpty) {
        return imageKey.startsWith('http')
            ? imageKey
            : 'https://cf.shopee.ph/file/$imageKey';
      }
      if (imageKey is List && imageKey.isNotEmpty) {
        final first = imageKey.first.toString();
        return first.startsWith('http')
            ? first
            : 'https://cf.shopee.ph/file/$first';
      }
      return null;
    }

    for (final model in models) {
      if (model is! Map) continue;
      final map = Map<String, dynamic>.from(model);
      final rawName = (map['name'] ?? map['tier_index'] ?? map['model_name'])
          ?.toString()
          .trim();
      final options = map['options'];
      String? displayName = rawName;

      if ((displayName == null || displayName.isEmpty) && options is List) {
        final values = <String>[];
        for (var i = 0; i < options.length; i++) {
          final optionValue = options[i]?.toString();
          if (optionValue == null || optionValue.isEmpty) continue;
          final tierName = optionNames.keys.elementAt(
            i < optionNames.length ? i : 0,
          );
          if (tierName.isNotEmpty) {
            values.add('$tierName: $optionValue');
          } else {
            values.add(optionValue);
          }
        }
        if (values.isNotEmpty) displayName = values.join(' / ');
      }

      if (displayName == null || displayName.isEmpty) {
        displayName = 'Variant';
      }

      final price =
          _parseShopeePrice(
            map['price'] ?? map['price_value'] ?? map['price_min'],
          ) ??
          0.0;
      final stockRaw =
          map['stock'] ?? map['normal_stock'] ?? map['stock_quantity'];
      final stock = stockRaw is int
          ? stockRaw
          : int.tryParse(stockRaw?.toString() ?? '') ?? 0;

      variations.add({
        'color_name': displayName,
        'hex_code': '#FFFFFF',
        'price': price,
        'stock': stock,
        'image_url': imageUrlForModel(map),
      });
    }

    return variations;
  }

  String _buildShopeeProductLink(Map<String, dynamic> item, Uri sourceUri) {
    final shopId = item['shopid']?.toString() ?? item['shop_id']?.toString();
    final itemId = item['itemid']?.toString() ?? item['item_id']?.toString();
    final name = (item['name'] ?? item['item_basic']?['name'] ?? 'product')
        .toString()
        .trim();
    if (shopId != null &&
        shopId.isNotEmpty &&
        itemId != null &&
        itemId.isNotEmpty) {
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '-');
      return '${sourceUri.scheme}://${sourceUri.host}/$slug-i.$shopId.$itemId';
    }
    return sourceUri.toString();
  }

  List<Map<String, dynamic>> _extractShopeeSearchItems(dynamic payload) {
    final items = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    void visit(dynamic node) {
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);

        if (map['item_basic'] is Map) {
          final base = Map<String, dynamic>.from(map['item_basic'] as Map);
          final combined = <String, dynamic>{...map, ...base};
          final key =
              '${combined['shopid'] ?? combined['shop_id'] ?? ''}-${combined['itemid'] ?? combined['item_id'] ?? ''}-${combined['name'] ?? ''}';
          if (seenKeys.add(key)) items.add(combined);
        } else if (map.containsKey('itemid') ||
            map.containsKey('shopid') ||
            map.containsKey('name')) {
          final key =
              '${map['shopid'] ?? map['shop_id'] ?? ''}-${map['itemid'] ?? map['item_id'] ?? ''}-${map['name'] ?? ''}';
          if (seenKeys.add(key)) items.add(map);
        }

        for (final key in [
          'items',
          'item',
          'data',
          'results',
          'search_items',
        ]) {
          final child = map[key];
          if (child != null) visit(child);
        }
      } else if (node is List) {
        for (final child in node) {
          visit(child);
        }
      }
    }

    visit(payload);
    return items;
  }

  Future<void> _handleLinkAction() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a product or Shopee search link'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid link'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isShopeeSearchLink(uri)) {
      await _importShopeeSearchProducts(uri);
    } else {
      await _fetchMetadata();
    }
  }

  Future<void> _importShopeeSearchProducts(Uri uri) async {
    final keyword = _normalizeShopeeKeyword(
      uri.queryParameters['keyword'] ?? '',
    );
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shopee search link is missing a keyword'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final ownerId = widget.businessId.isNotEmpty
        ? widget.businessId
        : Supabase.instance.client.auth.currentUser?.id;
    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No business account found for import'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isFetchingMetadata = true);

    try {
      final apiUri = Uri.https(uri.host, '/api/v4/search/search_items', {
        'by': 'relevancy',
        'keyword': keyword,
        'limit': '20',
        'newest': '0',
        'order': 'desc',
        'page_type': 'search',
        'scenario': 'PAGE_GLOBAL_SEARCH',
        'version': '2',
      });

      final apiRes = await http.get(
        apiUri,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json',
          'Referer': 'https://shopee.ph/',
        },
      );

      if (apiRes.statusCode != 200) {
        throw 'Shopee search request failed (${apiRes.statusCode})';
      }

      final decoded = jsonDecode(apiRes.body);
      final foundItems = _extractShopeeSearchItems(decoded).take(12).toList();
      if (foundItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No products found in that Shopee search link'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final existing = await Supabase.instance.client
          .from('products')
          .select('name,product_link')
          .eq('business_id', ownerId);

      final existingLinks = <String>{};
      final existingNames = <String>{};
      for (final row in existing as List) {
        if (row is Map<String, dynamic>) {
          final link = row['product_link']?.toString().trim();
          final name = row['name']?.toString().trim().toLowerCase();
          if (link != null && link.isNotEmpty) existingLinks.add(link);
          if (name != null && name.isNotEmpty) existingNames.add(name);
        }
      }

      int inserted = 0;
      int skipped = 0;
      final bulkCategory = keyword;

      for (final rawItem in foundItems) {
        final item = rawItem;
        final name = (item['name'] ?? item['title'] ?? '').toString().trim();
        if (name.isEmpty) {
          skipped++;
          continue;
        }

        final productLink = _buildShopeeProductLink(item, uri);
        final normalizedName = name.toLowerCase();
        if (existingLinks.contains(productLink) ||
            existingNames.contains(normalizedName)) {
          skipped++;
          continue;
        }

        final imageUrl = _buildShopeeImageUrl(item);
        final price =
            _parseShopeePrice(
              item['price_min'] ?? item['price'] ?? item['price_max'],
            ) ??
            0.0;
        final description = _extractShopeeDescription(item) ?? '';
        final stock =
            (item['stock'] ?? item['item_basic']?['stock'] ?? 0) is int
            ? (item['stock'] ?? item['item_basic']?['stock'] ?? 0) as int
            : int.tryParse(
                    (item['stock'] ?? item['item_basic']?['stock'] ?? 0)
                        .toString(),
                  ) ??
                  0;
        final variations = _extractShopeeVariations(item);

        final productData = <String, dynamic>{
          'business_id': ownerId,
          'name': name,
          'description': description.isEmpty ? null : description,
          'price': price,
          'currency': 'PHP',
          'image_url': imageUrl,
          'product_link': productLink,
          'stock_quantity': stock,
          'variations': variations,
          'category': _guessCategory(name) ?? bulkCategory,
          'is_active': true,
        };

        try {
          await Supabase.instance.client.from('products').insert(productData);
          existingLinks.add(productLink);
          existingNames.add(normalizedName);
          inserted++;
        } catch (_) {
          skipped++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported $inserted product(s) from Shopee search${skipped > 0 ? ' ($skipped skipped)' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not import Shopee products: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingMetadata = false);
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

      // Special handling for Shopee product pages
      if (uri.host.contains('shopee')) {
        try {
          final full = uri.toString();
          final candidateIds = <Map<String, String>>[];

          void addCandidate(String? shopId, String? itemId) {
            final normalizedShopId = shopId?.trim();
            final normalizedItemId = itemId?.trim();
            if (normalizedShopId == null || normalizedShopId.isEmpty) return;
            if (normalizedItemId == null || normalizedItemId.isEmpty) return;
            final key = '$normalizedShopId:$normalizedItemId';
            if (candidateIds.any((candidate) => candidate['key'] == key)) {
              return;
            }
            candidateIds.add({
              'shopId': normalizedShopId,
              'itemId': normalizedItemId,
              'key': key,
            });
          }

          final pathMatch =
              RegExp(r'/product/(\d+)/(\d+)').firstMatch(full) ??
              RegExp(r'/item/(\d+)/(\d+)').firstMatch(full) ??
              RegExp(r'-i\.(\d+)\.(\d+)').firstMatch(full);
          if (pathMatch != null) {
            addCandidate(pathMatch.group(1), pathMatch.group(2));
          }

          addCandidate(
            uri.queryParameters['vShopId'],
            uri.queryParameters['vItemId'],
          );
          addCandidate(
            uri.queryParameters['shopid'],
            uri.queryParameters['itemid'],
          );
          addCandidate(
            uri.queryParameters['shopId'],
            uri.queryParameters['itemId'],
          );

          Map<String, dynamic>? extractShopeeItem(dynamic payload) {
            if (payload is Map) {
              final map = Map<String, dynamic>.from(payload);
              final item = map['item'];
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }

              final data = map['data'];
              if (data is Map) {
                final nestedItem = data['item'];
                if (nestedItem is Map) {
                  return Map<String, dynamic>.from(nestedItem);
                }
                final nestedMap = Map<String, dynamic>.from(data);
                if (nestedMap.containsKey('name') ||
                    nestedMap.containsKey('price') ||
                    nestedMap.containsKey('images')) {
                  return nestedMap;
                }
              }

              if (map.containsKey('name') ||
                  map.containsKey('price') ||
                  map.containsKey('images')) {
                return map;
              }

              for (final value in map.values) {
                final found = extractShopeeItem(value);
                if (found != null) return found;
              }
            } else if (payload is List) {
              for (final value in payload) {
                final found = extractShopeeItem(value);
                if (found != null) return found;
              }
            }
            return null;
          }

          Map<String, dynamic>? item;
          String? matchedSource;

          final proxyResult = await _fetchShopeeItemViaProxy(uri, candidateIds);
          if (proxyResult != null && proxyResult['item'] is Map) {
            item = Map<String, dynamic>.from(proxyResult['item'] as Map);
            matchedSource = 'proxy:${proxyResult['source'] ?? 'supabase'}';
          }

          if (item == null) {
            for (final candidate in candidateIds) {
              final shopId = candidate['shopId']!;
              final itemId = candidate['itemId']!;
              final apiUri = Uri.parse(
                '${uri.scheme}://${uri.host}/api/v4/item/get?itemid=$itemId&shopid=$shopId',
              );
              final apiRes = await http.get(
                apiUri,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                  'Accept': 'application/json',
                  'Referer': 'https://shopee.ph/',
                },
              );

              if (apiRes.statusCode != 200) {
                continue;
              }

              final decoded = jsonDecode(apiRes.body);
              final foundItem = extractShopeeItem(decoded);
              if (foundItem != null) {
                item = foundItem;
                matchedSource = '$shopId/$itemId';
                break;
              }
            }
          }

          if (item != null) {
            final productName = (item['name'] ?? item['item_basic']?['name'])
                ?.toString()
                .trim();
            final description = _extractShopeeDescription(item);
            final stockRaw =
                item['stock'] ??
                item['item_basic']?['stock'] ??
                item['models']?['stock'];
            final imageUrl = _buildShopeeImageUrl(item);

            String? enrichedDescription = description;
            String? enrichedImageUrl = imageUrl;
            if ((enrichedDescription == null || enrichedDescription.isEmpty) ||
                (enrichedImageUrl == null || enrichedImageUrl.isEmpty)) {
              try {
                final pageResponse = await http
                    .get(
                      uri,
                      headers: {
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                      },
                    )
                    .timeout(const Duration(seconds: 8));

                if (pageResponse.statusCode == 200) {
                  final htmlMeta = _extractShopeeMetadataFromHtml(
                    pageResponse.body,
                  );
                  enrichedDescription ??= htmlMeta['description'];
                  enrichedImageUrl ??= htmlMeta['image'];
                }
              } catch (_) {
                // Keep the already extracted values if the page fetch fails.
              }
            }

            double? price;
            final priceCandidates = [
              item['price_min'],
              item['price'],
              item['price_max'],
              item['item_basic']?['price_min'],
              item['item_basic']?['price'],
              item['item_basic']?['price_max'],
            ];
            for (final rawPrice in priceCandidates) {
              final parsed = _parseShopeePrice(rawPrice);
              if (parsed != null && parsed > 0) {
                price = parsed;
                break;
              }
            }

            final guessedCategory = productName != null
                ? _guessCategory(productName)
                : null;
            final stock = stockRaw is int
                ? stockRaw
                : int.tryParse(stockRaw?.toString() ?? '') ?? 0;
            final variations = _extractShopeeVariations(item);

            setState(() {
              if (productName != null && productName.isNotEmpty) {
                _nameController.text = productName;
              }
              if (price != null && price > 0) {
                _priceController.text = price.toStringAsFixed(2);
              }
              if (enrichedDescription != null &&
                  enrichedDescription.isNotEmpty) {
                _descriptionController.text = enrichedDescription;
              }
              if (enrichedImageUrl != null && enrichedImageUrl.isNotEmpty) {
                _imagePreviewUrl = enrichedImageUrl;
                _imageUrlController.text = enrichedImageUrl;
              }
              if (guessedCategory != null) {
                _selectedCategory = guessedCategory;
              }
              if (_stockController.text.isEmpty && stock > 0) {
                _stockController.text = stock.toString();
              }
              if (variations.isNotEmpty) {
                _variations
                  ..clear()
                  ..addAll(variations);
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✓ Shopee product loaded from ${matchedSource ?? 'link'}!',
                ),
                backgroundColor: Colors.green,
              ),
            );
            return;
          }

          // Local URL-based fallback: extract title from the URL slug when
          // both proxy and API attempts failed. This prevents a hard failure
          // and prefills at least the product name for manual completion.
          final localTitle = _extractNameFromEcommerceUrl(uri);
          if ((item == null || item.isEmpty) && localTitle.isNotEmpty) {
            setState(() {
              _nameController.text = localTitle;
              _selectedCategory =
                  _guessCategory(localTitle) ?? _selectedCategory;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '✓ Title extracted from link — fill remaining details manually.',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return;
          }

          // Inform the user and allow the generic HTML extractor to run as a fallback.
          final idList = candidateIds
              .map((c) => '${c['shopId']}:${c['itemId']}')
              .join(', ');
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Shopee import failed'),
                content: Text(
                  'Could not load structured product data from Shopee API.\n\nDetected candidate IDs: $idList\n\nThe app will attempt a generic page extraction next. If this keeps failing, you can copy the IDs or try the API again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: idList));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Candidate IDs copied to clipboard'),
                        ),
                      );
                    },
                    child: const Text('Copy IDs'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _attemptShopeeApiByCandidates(candidateIds);
                    },
                    child: const Text('Try API'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          print('Shopee API extraction failed: $e');
        }
      }

      // Generic HTML metadata extraction fallback
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 8));

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

        // If meta tags didn't provide enough, try extracting JSON blobs from scripts
        Map<String, dynamic>? scriptFoundItem;

        String? extractFirstJson(String text) {
          final start = text.indexOf('{');
          if (start == -1) return null;
          int depth = 0;
          for (int i = start; i < text.length; i++) {
            if (text[i] == '{') depth++;
            if (text[i] == '}') depth--;
            if (depth == 0) {
              return text.substring(start, i + 1);
            }
          }
          return null;
        }

        dynamic findItemInJson(dynamic payload) {
          if (payload is Map) {
            final map = Map<String, dynamic>.from(payload);
            if (map.containsKey('item') && map['item'] is Map) {
              return Map<String, dynamic>.from(map['item']);
            }
            if (map.containsKey('item_basic') && map['item_basic'] is Map) {
              return Map<String, dynamic>.from(map['item_basic']);
            }
            if (map.containsKey('name') ||
                map.containsKey('price') ||
                map.containsKey('images')) {
              return map;
            }
            for (final v in map.values) {
              final found = findItemInJson(v);
              if (found != null) return found;
            }
          } else if (payload is List) {
            for (final v in payload) {
              final found = findItemInJson(v);
              if (found != null) return found;
            }
          }
          return null;
        }

        if (productName == null ||
            (price == null && description == null && imageUrl == null)) {
          final scripts = document.getElementsByTagName('script');
          for (final script in scripts) {
            final text = script.text;
            if (text.isEmpty) continue;
            if (!(text.contains('window.__INITIAL_STATE__') ||
                text.contains('g_page_config') ||
                text.contains('item_basic') ||
                text.contains('itemid') ||
                text.contains('itemid'))) {
              continue;
            }

            final jsonStr = extractFirstJson(text);
            if (jsonStr == null) continue;

            try {
              final decoded = jsonDecode(jsonStr);
              final found = findItemInJson(decoded);
              if (found is Map<String, dynamic>) {
                scriptFoundItem = found;
                break;
              }
            } catch (_) {
              // ignore parse errors and continue
            }
          }

          if (scriptFoundItem != null) {
            // prefer script-found values when meta tags were missing
            final sf = scriptFoundItem;
            if (productName == null || productName.isEmpty) {
              productName = (sf['name'] ?? sf['item_basic']?['name'])
                  ?.toString();
            }
            if ((price == null || price == 0) && sf.isNotEmpty) {
              final cand =
                  sf['price_min'] ??
                  sf['price'] ??
                  sf['price_max'] ??
                  sf['item_basic']?['price_min'];
              final parsed = _parseShopeePrice(cand);
              if (parsed != null && parsed > 0) price = parsed;
            }
            String? description = _extractShopeeDescription(sf);
            if (description == null || description.isEmpty) {
              final extracted = _extractShopeeDescription(sf);
              if (extracted != null && extracted.isNotEmpty) {
                description = extracted;
              }
            }
            if (_isPlaceholderShopeeDescription(description)) {
              description = null;
            }
            if (imageUrl == null || imageUrl.isEmpty) {
              imageUrl = _buildShopeeImageUrl(sf);
            }

            final guessed = productName != null
                ? _guessCategory(productName)
                : null;
            final variationsFromScript = <Map<String, dynamic>>[];
            try {
              final extractedVar = _extractShopeeVariations(scriptFoundItem);
              if (extractedVar.isNotEmpty) {
                variationsFromScript.addAll(extractedVar);
              }
            } catch (_) {}

            setState(() {
              if (productName != null && productName.isNotEmpty) {
                _nameController.text = productName.trim();
              }
              if (price != null && price > 0) {
                _priceController.text = price.toStringAsFixed(2);
              }
              if (description != null && description.isNotEmpty) {
                _descriptionController.text = description;
              }
              if (imageUrl != null && imageUrl.isNotEmpty) {
                _imagePreviewUrl = imageUrl;
                _imageUrlController.text = imageUrl;
              }
              if (guessed != null) _selectedCategory = guessed;
              if (variationsFromScript.isNotEmpty) {
                _variations
                  ..clear()
                  ..addAll(variationsFromScript);
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Product details extracted from page script!'),
                backgroundColor: Colors.green,
              ),
            );
            return;
          }
        }

        // Check if we actually extracted anything
        final extracted =
            productName != null ||
            price != null ||
            description != null ||
            imageUrl != null;

        setState(() {
          if (productName != null && productName.isNotEmpty) {
            _nameController.text = productName;
          }
          if (price != null && price > 0) {
            _priceController.text = price.toStringAsFixed(2);
          }
          if (description != null && description.isNotEmpty) {
            _descriptionController.text = description;
          }
          if (imageUrl != null && imageUrl.isNotEmpty) {
            _imagePreviewUrl = imageUrl;
            _imageUrlController.text = imageUrl;
          }
          if (guessedCategory != null) {
            _selectedCategory = guessedCategory;
          }
        });

        if (extracted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Product details extracted!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠ No product data found on this page. Enter details manually.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access this URL'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Metadata fetch error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error fetching details: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() => _isFetchingMetadata = false);
    }
  }

  Future<void> _attemptShopeeApiByCandidates(
    List<Map<String, String>> candidateIds,
  ) async {
    if (candidateIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Shopee candidate IDs available')),
      );
      return;
    }
    try {
      final firstCandidate = candidateIds.first;
      final proxyResult = await _fetchShopeeItemViaProxy(
        Uri.parse(_linkController.text.trim()),
        candidateIds,
      );

      if (proxyResult != null && proxyResult['item'] is Map) {
        final item = Map<String, dynamic>.from(proxyResult['item'] as Map);
        final pretty = const JsonEncoder.withIndent('  ').convert(item);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Shopee proxy response (${proxyResult['source'] ?? 'proxy'})',
            ),
            content: SingleChildScrollView(child: SelectableText(pretty)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      final shopId = firstCandidate['shopId'] ?? '';
      final itemId = firstCandidate['itemId'] ?? '';
      final apiUri = Uri.parse(
        'https://shopee.ph/api/v4/item/get?itemid=$itemId&shopid=$shopId',
      );
      final apiRes = await http.get(
        apiUri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json',
          'Referer': 'https://shopee.ph/',
        },
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shopee API Error'),
          content: Text(
            'Status ${apiRes.statusCode}: ${apiRes.reasonPhrase ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error calling Shopee API: $e')));
    }
  }

  Future<Map<String, dynamic>?> _fetchShopeeItemViaProxy(
    Uri sourceUri,
    List<Map<String, String>> candidateIds,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'shopee-import',
        body: {
          'url': sourceUri.toString(),
          'shopId': candidateIds.isNotEmpty
              ? candidateIds.first['shopId']
              : null,
          'itemId': candidateIds.isNotEmpty
              ? candidateIds.first['itemId']
              : null,
          'displayModelId': sourceUri.queryParameters['display_model_id'],
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['ok'] == true && data['item'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
        if (data['item'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
      } else if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['ok'] == true && map['item'] is Map) {
          return map;
        }
        if (map['item'] is Map) {
          return map;
        }
      }
    } catch (e) {
      debugPrint('Shopee proxy fetch failed: $e');
    }

    return null;
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
      final ownerId = widget.businessId.isNotEmpty
          ? widget.businessId
          : Supabase.instance.client.auth.currentUser?.id;
      if (ownerId == null || ownerId.isEmpty) {
        throw 'No business account available';
      }

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
          'hex_code': _variationHex(variation),
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
        'business_id': ownerId,
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

      for (final variation in _variations) {
        final variationName =
            (variation['name'] ?? variation['color_name'] ?? '')
                .toString()
                .trim();
        final variationHex = _variationHex(variation);
        await _persistColorPaletteEntry(variationName, variationHex);
      }

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
