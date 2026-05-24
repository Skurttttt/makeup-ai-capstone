// lib/screens/checkout_screen.dart
//
// Modern multi-step checkout flow:
//   Step 1: Shipping details (with auto-fill from current user)
//   Step 2: Payment method
//   Step 3: Review & place order
// On success an animated success screen is shown.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

const Color _kPrimaryPink = Color(0xFFFF4D97);
const Color _kSurface = Color(0xFFF7F7FB);

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
  final _shippingFormKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0: Shipping, 1: Payment, 2: Review
  bool _isProcessing = false;
  bool _isLocating = false;
  String _selectedPaymentMethod = 'xendit';

  // Saved addresses
  List<Map<String, dynamic>> _savedAddresses = [];
  String? _selectedAddressId;

  bool get _supportsGps => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _notesController = TextEditingController();

  static const double _freeShippingThreshold = 1500.0;

  // Philippine couriers used for automatic pickup-rider assignment.
  // The system auto-picks one when an order is placed (similar to Shopee/Lazada),
  // so the seller doesn't need to choose manually before shipping.
  static const List<String> _autoCouriers = [
    'J&T Express',
    'LBC Express',
    'Ninja Van',
    'Grab Express',
    'Lalamove',
    'SPX Express (Shopee)',
    'Flash Express',
  ];

  /// Picks a courier automatically. Uses Grab/Lalamove for small/light orders
  /// (single item) and a deterministic round-robin from a buyer hash otherwise,
  /// so the same buyer doesn't always land on the same courier.
  String _autoAssignCourier() {
    final itemCount = widget.cartItems.fold<int>(
        0, (sum, it) => sum + ((it['quantity'] as num?)?.toInt() ?? 1));
    if (itemCount <= 1) {
      // Quick same-day pickup riders for tiny orders
      const quick = ['Grab Express', 'Lalamove'];
      return quick[DateTime.now().millisecondsSinceEpoch % quick.length];
    }
    final idx = DateTime.now().millisecondsSinceEpoch % _autoCouriers.length;
    return _autoCouriers[idx];
  }

  /// Generates tracking number: PREFIX-YYYYMMDD-XXXXXX
  String _generateTrackingNumber(String courier) {
    final letters = courier.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final prefix =
        letters.length >= 3 ? letters.substring(0, 3) : letters.padRight(3, 'X');
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand =
        (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    return '$prefix-$date-$rand';
  }
  static const double _baseShippingFee = 99.0;
  static const double _taxRate = 0.12;

  double get _subtotal => widget.cartItems.fold(
        0.0,
        (sum, item) =>
            sum + ((item['price'] as num).toDouble() * (item['quantity'] as int)),
      );
  double get _shippingFee =>
      _subtotal >= _freeShippingThreshold ? 0.0 : _baseShippingFee;
  double get _tax => _subtotal * _taxRate;
  double get _total => _subtotal + _shippingFee + _tax;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  Future<void> _prefillFromProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      _emailController.text = user.email ?? '';

      // 1. Pull profile basics (name + phone) from accounts
      final profile = await Supabase.instance.client
          .from('accounts')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = (profile['full_name'] ?? '').toString();
          }
          if (_phoneController.text.isEmpty) {
            _phoneController.text = (profile['phone'] ?? '').toString();
          }
        });
      }

      // Fallback to user metadata if accounts row is empty
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        final meta = user.userMetadata ?? {};
        if (mounted) {
          setState(() {
            if (_nameController.text.isEmpty) {
              _nameController.text =
                  (meta['full_name'] ?? meta['name'] ?? '').toString();
            }
            if (_phoneController.text.isEmpty) {
              _phoneController.text =
                  (meta['phone_number'] ?? meta['phone'] ?? '').toString();
            }
          });
        }
      }

      // 2. Load saved addresses
      await _loadSavedAddresses(autoSelectDefault: true);

      // 3. Fallback: if no saved addresses, prefill from user metadata
      if (_savedAddresses.isEmpty) {
        final meta = user.userMetadata ?? {};
        final metaAddress = (meta['address'] ?? '').toString().trim();
        final metaCity = (meta['city'] ?? '').toString().trim();
        final metaPostal = (meta['postal_code'] ?? '').toString().trim();
        if (mounted) {
          setState(() {
            if (_addressController.text.isEmpty && metaAddress.isNotEmpty) {
              _addressController.text = metaAddress;
            }
            if (_cityController.text.isEmpty && metaCity.isNotEmpty) {
              _cityController.text = metaCity;
            }
            if (_postalCodeController.text.isEmpty && metaPostal.isNotEmpty) {
              _postalCodeController.text = metaPostal;
            }
          });
        }
      }
    } catch (_) {
      // Silent fail — user can fill in manually.
    }
  }

  Future<void> _loadSavedAddresses({bool autoSelectDefault = false}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final rows = await Supabase.instance.client
          .from('addresses')
          .select('*')
          .eq('user_id', user.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows);
      if (!mounted) return;
      setState(() {
        _savedAddresses = list;
        if (autoSelectDefault && list.isNotEmpty && _selectedAddressId == null) {
          _applyAddress(list.first);
        }
      });
    } catch (_) {
      // Ignore — addresses are optional.
    }
  }

  void _applyAddress(Map<String, dynamic> addr) {
    setState(() {
      _selectedAddressId = addr['id']?.toString();
      _addressController.text = (addr['street'] ?? '').toString();
      _cityController.text = (addr['city'] ?? '').toString();
      _postalCodeController.text = (addr['postal_code'] ?? '').toString();
      final rName = (addr['recipient_name'] ?? '').toString();
      final rPhone = (addr['recipient_phone'] ?? '').toString();
      if (rName.isNotEmpty) _nameController.text = rName;
      if (rPhone.isNotEmpty) _phoneController.text = rPhone;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (!_supportsGps) {
      _showSnack(
        'Location detection is only available on Android and iOS.',
      );
      return;
    }
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled. Please enable them.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack(
            'Location permission permanently denied. Enable it in settings.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isEmpty || !mounted) return;

      final place = placemarks.first;
      final street = [
        place.subThoroughfare ?? '',
        place.thoroughfare ?? '',
        place.subLocality ?? '',
      ].where((s) => s.isNotEmpty).join(' ');

      setState(() {
        if (street.isNotEmpty) _addressController.text = street;
        if ((place.locality ?? '').isNotEmpty) {
          _cityController.text = place.locality!;
        }
        if ((place.postalCode ?? '').isNotEmpty) {
          _postalCodeController.text = place.postalCode!;
        }
      });
      _showSnack('Location filled in!', success: true);
    } catch (e) {
      _showSnack('Could not detect location: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _saveLocationToProfile() async {
    final street = _addressController.text.trim();
    final city = _cityController.text.trim();
    if (street.isEmpty || city.isEmpty) {
      _showSnack('Please enter at least street and city before saving.');
      return;
    }
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final payload = {
        'user_id': user.id,
        'label': 'Saved address',
        'recipient_name': _nameController.text.trim(),
        'recipient_phone': _phoneController.text.trim(),
        'street': street,
        'city': city,
        'postal_code': _postalCodeController.text.trim(),
        'is_default': _savedAddresses.isEmpty,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_selectedAddressId != null) {
        await Supabase.instance.client
            .from('addresses')
            .update(payload)
            .eq('id', _selectedAddressId!);
        _showSnack('Address updated!', success: true);
      } else {
        final inserted = await Supabase.instance.client
            .from('addresses')
            .insert(payload)
            .select()
            .single();
        _selectedAddressId = inserted['id']?.toString();
        _showSnack('Address saved to your profile!', success: true);
      }
      await _loadSavedAddresses();
    } catch (e) {
      _showSnack('Could not save address: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentStep == 0) {
      if (!(_shippingFormKey.currentState?.validate() ?? false)) return;
    }
    setState(() => _currentStep += 1);
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _placeOrder() async {
    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Please sign in to place an order.';

      // Auto-assign a pickup rider/courier so the seller can ship immediately
      // without having to pick one manually (standard ecommerce behavior).
      final autoCourier = _autoAssignCourier();
      final autoTracking = _generateTrackingNumber(autoCourier);

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
        'courier': autoCourier,
        'tracking_number': autoTracking,
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
          'product_name': item['name'],
          'product_image_url': item['image_url'],
          'quantity': item['quantity'],
          'unit_price': item['price'],
          'total_price':
              (item['price'] as num).toDouble() * (item['quantity'] as int),
          'variation_name': item['variation']?['color_name'],
          'variation_hex':
              item['variation']?['hex_code'] ?? item['variation']?['hex'],
        };

        await Supabase.instance.client.from('order_items').insert(orderItemData);
        await Supabase.instance.client.rpc(
          'decrement_stock',
          params: {'product_id': item['id'], 'quantity': item['quantity']},
        );
      }

      if (_selectedPaymentMethod == 'xendit' ||
          _selectedPaymentMethod == 'gcash' ||
          _selectedPaymentMethod == 'maya' ||
          _selectedPaymentMethod == 'bank_transfer' ||
          _selectedPaymentMethod == 'qr_ph') {
        final paymentResponse =
            await _supabaseService.createXenditCheckoutForOrder(
          items: widget.cartItems
              .map((item) => {
                    'product_id': item['id']?.toString() ?? '',
                    'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
                  })
              .toList(),
          paymentMethod: _selectedPaymentMethod,
        );
        final checkoutUrl = paymentResponse['checkout_url']?.toString();
        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          await launchUrl(
            Uri.parse(checkoutUrl),
            mode: LaunchMode.externalApplication,
          );
          widget.onCheckoutComplete();
          if (mounted) await _showSuccessScreen(orderId.toString());
        } else {
          throw 'Failed to create payment link';
        }
      } else {
        // COD / other — mark as paid so seller can process it
        await Supabase.instance.client
            .from('orders')
            .update({'status': 'paid'}).eq('id', orderId);
        widget.onCheckoutComplete();
        if (mounted) await _showSuccessScreen(orderId.toString());
      }
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _showSuccessScreen(String orderId) async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _OrderSuccessScreen(
          orderId: orderId,
          total: _total,
          paymentMethod: _selectedPaymentMethod,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: _buildStepContent(),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildShippingStep();
      case 1:
        return _buildPaymentStep();
      case 2:
      default:
        return _buildReviewStep();
    }
  }

  // ---------------------------------------------------------------------------
  // Step indicator
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicator() {
    const steps = ['Shipping', 'Payment', 'Review'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i <= _currentStep;
          final done = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? _kPrimaryPink : Colors.grey.shade200,
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: active ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? _kPrimaryPink : Colors.grey,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
                      color: i < _currentStep
                          ? _kPrimaryPink
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Shipping
  // ---------------------------------------------------------------------------

  Widget _buildShippingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _shippingFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            if (_savedAddresses.isNotEmpty) _buildSavedAddressesCard(),
            _sectionCard(
              title: 'Where should we deliver?',
              subtitle: 'We auto-filled what we already know about you.',
              child: Column(
                children: [
                  _textField(
                    _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline,
                    validator: _required('Please enter your name'),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _emailController,
                    label: 'Email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(v.trim());
                      return ok ? null : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _phoneController,
                    label: 'Phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a phone number';
                      }
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      return digits.length >= 7
                          ? null
                          : 'Phone number is too short';
                    },
                  ),
                  const SizedBox(height: 16),
                  // Location row
                  Row(
                    children: [
                      if (_supportsGps) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLocating ? null : _useCurrentLocation,
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _kPrimaryPink),
                                  )
                                : const Icon(Icons.my_location,
                                    size: 18, color: _kPrimaryPink),
                            label: Text(
                              _isLocating
                                  ? 'Detecting…'
                                  : 'Use current location',
                              style: const TextStyle(
                                  color: _kPrimaryPink, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _kPrimaryPink),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveLocationToProfile,
                          icon: const Icon(Icons.bookmark_outline,
                              size: 18, color: _kPrimaryPink),
                          label: Text(
                            _selectedAddressId == null
                                ? 'Save address'
                                : 'Update address',
                            style: const TextStyle(
                                color: _kPrimaryPink, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _kPrimaryPink),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _addressController,
                    label: 'Street address',
                    icon: Icons.home_outlined,
                    maxLines: 2,
                    validator: _required('Please enter your address'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _textField(
                          _cityController,
                          label: 'City',
                          icon: Icons.location_city_outlined,
                          validator: _required('Required'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _textField(
                          _postalCodeController,
                          label: 'Postal code',
                          icon: Icons.markunread_mailbox_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _notesController,
                    label: 'Delivery notes (optional)',
                    icon: Icons.sticky_note_2_outlined,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Payment
  // ---------------------------------------------------------------------------

  Widget _buildPaymentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: 'Choose how to pay',
            subtitle: 'All transactions are encrypted and secure.',
            child: Column(
              children: [
                _PaymentTile(
                  selected: _selectedPaymentMethod == 'xendit',
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'xendit'),
                  icon: Icons.credit_card,
                  iconColor: const Color(0xFF0052CC),
                  title: 'Credit / Debit card',
                  subtitle: 'Visa, Mastercard via Xendit',
                  trailing: 'Recommended',
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  selected: _selectedPaymentMethod == 'gcash',
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'gcash'),
                  icon: Icons.mobile_screen_share,
                  iconColor: const Color(0xFF00A4EF),
                  title: 'GCash',
                  subtitle: 'Pay with your GCash wallet',
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  selected: _selectedPaymentMethod == 'maya',
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'maya'),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF00B14F),
                  title: 'Maya',
                  subtitle: 'Pay with your Maya wallet',
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  selected: _selectedPaymentMethod == 'bank_transfer',
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'bank_transfer'),
                  icon: Icons.account_balance_outlined,
                  iconColor: const Color(0xFF5C6BC0),
                  title: 'Bank Transfer',
                  subtitle: 'Pay via online banking',
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  selected: _selectedPaymentMethod == 'qr_ph',
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'qr_ph'),
                  icon: Icons.qr_code_2,
                  iconColor: const Color(0xFFE53935),
                  title: 'QR Ph',
                  subtitle: 'Scan with any PH bank app',
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  selected: _selectedPaymentMethod == 'cod',
                  onTap: () => setState(() => _selectedPaymentMethod = 'cod'),
                  icon: Icons.local_shipping_outlined,
                  iconColor: Colors.green.shade700,
                  title: 'Cash on Delivery',
                  subtitle: 'Pay when the order arrives',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Order summary',
            child: _buildPriceBreakdown(compact: true),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Review
  // ---------------------------------------------------------------------------

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: 'Items (${widget.cartItems.length})',
            child: Column(
              children: [
                for (final item in widget.cartItems) _buildItemRow(item),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Deliver to',
            trailing: TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Edit',
                  style: TextStyle(color: _kPrimaryPink)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.trim(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  _phoneController.text.trim(),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_addressController.text.trim()}, '
                  '${_cityController.text.trim()}'
                  '${_postalCodeController.text.trim().isNotEmpty ? ' ${_postalCodeController.text.trim()}' : ''}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                if (_notesController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 16, color: _kPrimaryPink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _notesController.text.trim(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Payment',
            trailing: TextButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Edit',
                  style: TextStyle(color: _kPrimaryPink)),
            ),
            child: Row(
              children: [
                Icon(_paymentIcon(_selectedPaymentMethod),
                    color: _paymentColor(_selectedPaymentMethod)),
                const SizedBox(width: 12),
                Text(
                  _paymentLabel(_selectedPaymentMethod),
                  style: const TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Total',
            child: _buildPriceBreakdown(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 2;
    final label = isLastStep
        ? 'Place Order  •  ₱${_total.toStringAsFixed(2)}'
        : (_currentStep == 0 ? 'Continue to payment' : 'Review order');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLastStep)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                    Text(
                      '₱${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _kPrimaryPink,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : (isLastStep ? _placeOrder : _goNext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimaryPink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimaryPink.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildSavedAddressesCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_rounded,
                  size: 18, color: _kPrimaryPink),
              const SizedBox(width: 8),
              Text(
                'Saved addresses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Text(
                '${_savedAddresses.length} saved',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _savedAddresses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final addr = _savedAddresses[index];
                final id = addr['id']?.toString();
                final selected = _selectedAddressId == id;
                final isDefault = addr['is_default'] == true;
                return GestureDetector(
                  onTap: () => _applyAddress(addr),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kPrimaryPink.withOpacity(0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? _kPrimaryPink
                            : Colors.grey.shade200,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: selected
                                  ? _kPrimaryPink
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                (addr['label'] ?? 'Address').toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kPrimaryPink,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (addr['street'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                        Text(
                          [
                            (addr['city'] ?? '').toString(),
                            (addr['postal_code'] ?? '').toString(),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black87),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        prefixIcon:
            icon != null ? Icon(icon, size: 20, color: Colors.grey.shade600) : null,
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimaryPink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
    );
  }

  String? Function(String?) _required(String message) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final qty = item['quantity'] as int;
    final price = (item['price'] as num).toDouble();
    final lineTotal = price * qty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: Colors.grey.shade100,
              child: item['image_url'] != null &&
                      item['image_url'].toString().isNotEmpty
                  ? Image.network(
                      item['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image, color: Colors.grey),
                    )
                  : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? 'Product',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 13,
                  ),
                ),
                if (item['variation'] != null &&
                    item['variation']['color_name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item['variation']['color_name'].toString(),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Qty $qty  •  ₱${price.toStringAsFixed(2)} each',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '₱${lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _kPrimaryPink,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown({bool compact = false}) {
    final freeShipping = _shippingFee == 0;
    return Column(
      children: [
        _row('Subtotal', '₱${_subtotal.toStringAsFixed(2)}'),
        const SizedBox(height: 6),
        _row(
          'Shipping',
          freeShipping ? 'FREE' : '₱${_shippingFee.toStringAsFixed(2)}',
          highlightValue: freeShipping,
        ),
        if (!freeShipping && !compact) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Spend ₱${(_freeShippingThreshold - _subtotal).toStringAsFixed(0)} more for free shipping',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        _row('Tax (12% VAT)', '₱${_tax.toStringAsFixed(2)}'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        _row('Total', '₱${_total.toStringAsFixed(2)}', isTotal: true),
      ],
    );
  }

  Widget _row(String label, String value,
      {bool isTotal = false, bool highlightValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            color: Colors.black87,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 17 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal
                ? _kPrimaryPink
                : (highlightValue ? Colors.green.shade700 : Colors.black87),
          ),
        ),
      ],
    );
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'gcash':
        return Icons.mobile_screen_share;
      case 'cod':
        return Icons.local_shipping_outlined;
      case 'xendit':
      default:
        return Icons.credit_card;
    }
  }

  Color _paymentColor(String method) {
    switch (method) {
      case 'gcash':
        return const Color(0xFF00A4EF);
      case 'cod':
        return Colors.green.shade700;
      case 'xendit':
      default:
        return const Color(0xFF0052CC);
    }
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'gcash':
        return 'GCash';
      case 'cod':
        return 'Cash on Delivery';
      case 'xendit':
      default:
        return 'Credit / Debit Card';
    }
  }
}

// =============================================================================
// Payment tile
// =============================================================================

class _PaymentTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailing;

  const _PaymentTile({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected ? _kPrimaryPink.withOpacity(0.06) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kPrimaryPink : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (trailing != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kPrimaryPink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trailing!,
                            style: const TextStyle(
                              color: _kPrimaryPink,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _kPrimaryPink : Colors.transparent,
                border: Border.all(
                  color: selected ? _kPrimaryPink : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Success screen
// =============================================================================

class _OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final double total;
  final String paymentMethod;

  const _OrderSuccessScreen({
    required this.orderId,
    required this.total,
    required this.paymentMethod,
  });

  @override
  State<_OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<_OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.paymentMethod == 'xendit' ||
        widget.paymentMethod == 'gcash';
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade50,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade400,
                    ),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Order placed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOnline
                    ? 'We opened your payment page in the browser. Your order is reserved while payment is processed.'
                    : 'We sent your order to the seller. They will contact you to arrange delivery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _row('Order #', widget.orderId.length > 8
                        ? '${widget.orderId.substring(0, 8)}…'
                        : widget.orderId),
                    const SizedBox(height: 8),
                    _row('Total paid', '₱${widget.total.toStringAsFixed(2)}',
                        bold: true),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(
                      context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue shopping',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade700, fontSize: bold ? 14 : 13)),
        Text(
          value,
          style: TextStyle(
            color: bold ? _kPrimaryPink : Colors.black87,
            fontSize: bold ? 17 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
