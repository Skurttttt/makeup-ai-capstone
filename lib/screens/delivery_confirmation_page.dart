// lib/screens/delivery_confirmation_page.dart
//
// Full delivery confirmation page.
// Supports: photo proof, GPS capture, OTP from packing slip, one-tap confirm.
// Auto-scores confidence and syncs order status via Postgres triggers.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

// ─── colours ─────────────────────────────────────────────────────────────────
const _kPink      = Color(0xFFFF4D8C);
const _kPinkDark  = Color(0xFFD6336C);
const _kPinkSoft  = Color(0xFFFFF0F5);
const _kSuccess   = Color(0xFF10B981);
const _kWarning   = Color(0xFFF59E0B);
const _kCard      = Color(0xFFFFFFFF);

class DeliveryConfirmationPage extends StatefulWidget {
  final String orderId;
  final String? trackingNumber;
  final String? courierName;
  final String? buyerName;
  final String? shippingAddress;

  const DeliveryConfirmationPage({
    super.key,
    required this.orderId,
    this.trackingNumber,
    this.courierName,
    this.buyerName,
    this.shippingAddress,
  });

  @override
  State<DeliveryConfirmationPage> createState() =>
      _DeliveryConfirmationPageState();
}

class _DeliveryConfirmationPageState
    extends State<DeliveryConfirmationPage> {
  final _svc    = SupabaseService();
  final _otpCtrl = TextEditingController();
  final _picker  = ImagePicker();

  // State
  XFile?    _pickedFile;
  Position? _gpsPosition;
  bool      _uploading     = false;
  bool      _confirming    = false;
  bool      _verifyingOtp  = false;
  bool      _gettingGps    = false;
  String?   _errorMsg;
  Map<String, dynamic>? _proof; // live proof from DB

  // Confidence components (mirrors DB)
  double _scoreCarrier = 0;
  double _scorePhoto   = 0;
  double _scoreGps     = 0;
  double _scoreOtp     = 0;
  double _scoreConfirm = 0;

  double get _totalConfidence =>
      (_scoreCarrier + _scorePhoto + _scoreGps + _scoreOtp + _scoreConfirm)
          .clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _loadExistingProof();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProof() async {
    try {
      final p = await _svc.getDeliveryProofForOrder(widget.orderId);
      if (p != null && mounted) {
        setState(() {
          _proof        = p;
          _scoreCarrier = (p['score_carrier'] as num? ?? 0).toDouble();
          _scorePhoto   = (p['score_photo']   as num? ?? 0).toDouble();
          _scoreGps     = (p['score_gps']     as num? ?? 0).toDouble();
          _scoreOtp     = (p['score_otp']     as num? ?? 0).toDouble();
          _scoreConfirm = (p['score_confirm'] as num? ?? 0).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() { _pickedFile = file; _errorMsg = null; });
  }

  Future<void> _getGps() async {
    setState(() => _gettingGps = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showError('Location permission is permanently denied. Enable it in Settings.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _gpsPosition = pos);
    } catch (e) {
      _showError('Could not get GPS: $e');
    } finally {
      if (mounted) setState(() => _gettingGps = false);
    }
  }

  Future<void> _uploadPhoto() async {
    if (_pickedFile == null) {
      _showError('Please take a photo first.');
      return;
    }
    setState(() { _uploading = true; _errorMsg = null; });
    try {
      final userId = _svc.client.auth.currentUser?.id ?? '';
      final bytes  = await _pickedFile!.readAsBytes();

      final result = await _svc.uploadDeliveryProof(
        userId:         userId,
        fileName:       _pickedFile!.name,
        fileBytes:      bytes,
        orderId:        widget.orderId,
        trackingNumber: widget.trackingNumber,
        exifLat:        _gpsPosition?.latitude,
        exifLng:        _gpsPosition?.longitude,
        exifTimestamp:  DateTime.now().toUtc().toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _proof        = result;
          _scorePhoto   = (result['score_photo'] as num? ?? 0.25).toDouble();
          _scoreGps     = (result['score_gps']   as num? ?? 0).toDouble();
        });
        _showSuccess('Photo uploaded! Confidence updated.');
      }
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _oneTapConfirm() async {
    setState(() { _confirming = true; _errorMsg = null; });
    try {
      final userId = _svc.client.auth.currentUser?.id ?? '';
      await _svc.confirmDelivery(orderId: widget.orderId, userId: userId);
      if (mounted) {
        setState(() => _scoreConfirm = 0.20);
        _showSuccess('Delivery confirmed!');
      }
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 4) {
      _showError('Enter the OTP from your packing slip.');
      return;
    }
    setState(() { _verifyingOtp = true; _errorMsg = null; });
    try {
      final ok = await _svc.verifyDeliveryOtp(
          orderId: widget.orderId, code: code);
      if (mounted) {
        if (ok) {
          setState(() => _scoreOtp = 0.40);
          _showSuccess('OTP verified! +0.40 confidence.');
        } else {
          _showError('Invalid or expired OTP. Check the code on your packing slip.');
        }
      }
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _errorMsg = msg);
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: _kSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDelivered = _proof?['status'] == 'verified' ||
        _proof?['status'] == 'auto_verified';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kPinkDark,
        elevation: 0,
        title: const Text(
          'Delivery Confirmation',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status banner ─────────────────────────────────────────────
            if (isDelivered)
              _banner(
                icon: Icons.verified_rounded,
                color: _kSuccess,
                title: 'Delivery Verified',
                subtitle: 'This order has been confirmed as delivered.',
              )
            else
              _banner(
                icon: Icons.local_shipping_rounded,
                color: _kPink,
                title: 'Confirm Your Delivery',
                subtitle: 'Use any method below to confirm you received your package.',
              ),

            const SizedBox(height: 20),

            // ── Order info card ───────────────────────────────────────────
            _infoCard(),

            const SizedBox(height: 16),

            // ── Confidence meter ──────────────────────────────────────────
            _confidenceMeter(),

            const SizedBox(height: 20),

            // ── Method 1: Photo proof ─────────────────────────────────────
            _sectionTitle('1. Photo of Delivered Package', Icons.camera_alt_rounded),
            const SizedBox(height: 10),
            _photoCard(),

            const SizedBox(height: 20),

            // ── Method 2: GPS ─────────────────────────────────────────────
            _sectionTitle('2. Confirm Your Location', Icons.location_on_rounded),
            const SizedBox(height: 10),
            _gpsCard(),

            const SizedBox(height: 20),

            // ── Method 3: OTP ─────────────────────────────────────────────
            _sectionTitle('3. Packing Slip OTP Code', Icons.pin_rounded),
            const SizedBox(height: 10),
            _otpCard(),

            const SizedBox(height: 20),

            // ── Method 4: One-tap confirm ─────────────────────────────────
            _sectionTitle('4. Quick One-Tap Confirm', Icons.touch_app_rounded),
            const SizedBox(height: 10),
            _oneTapCard(),

            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMsg!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── sub-widgets ─────────────────────────────────────────────────────────

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: color.withOpacity(0.75))),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _infoCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.receipt_long_rounded, 'Order ID',
                widget.orderId.replaceAll('-', '').substring(0, 8).toUpperCase()),
            if (widget.trackingNumber?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.pin_outlined, 'Tracking',
                  widget.trackingNumber!),
            ],
            if (widget.courierName?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.local_shipping_rounded, 'Courier',
                  widget.courierName!),
            ],
            if (widget.buyerName?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.person_outline_rounded, 'Buyer',
                  widget.buyerName!),
            ],
            if (widget.shippingAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.location_on_outlined, 'Address',
                  widget.shippingAddress!),
            ],
          ],
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _kPink),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      );

  Widget _confidenceMeter() {
    final pct = (_totalConfidence * 100).round();
    Color barColor;
    String label;
    if (_totalConfidence >= 0.75) {
      barColor = _kSuccess;
      label = 'Auto-Verified ✓';
    } else if (_totalConfidence >= 0.40) {
      barColor = _kWarning;
      label = 'Pending Review';
    } else {
      barColor = _kPink;
      label = 'Needs More Proof';
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Confidence Score',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: barColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _totalConfidence,
              minHeight: 14,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: barColor)),
              Text('Target: 75%+ for auto-verify',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Breakdown chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _scorePill('Carrier', _scoreCarrier, 0.50),
              _scorePill('Photo', _scorePhoto, 0.25),
              _scorePill('GPS', _scoreGps, 0.25),
              _scorePill('OTP', _scoreOtp, 0.40),
              _scorePill('Confirm', _scoreConfirm, 0.20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scorePill(String label, double current, double max) {
    final done = current > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? _kSuccess.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: done ? _kSuccess.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: done ? _kSuccess : Colors.grey.shade400,
          ),
          const SizedBox(width: 5),
          Text(
            '$label +${(max * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: done ? _kSuccess : Colors.grey.shade500,
              decoration: done ? TextDecoration.none : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kPinkSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _kPink, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      );

  Widget _photoCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pickedFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_pickedFile!.path),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade200, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No photo taken yet',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(_pickedFile != null ? 'Retake' : 'Take Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPink,
                      side: const BorderSide(color: _kPink),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_pickedFile != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _uploadPhoto,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(_uploading ? 'Uploading…' : 'Upload Proof'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_scorePhoto > 0) ...[
              const SizedBox(height: 10),
              _checkRow('Photo uploaded (+25%)'),
            ],
          ],
        ),
      );

  Widget _gpsCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_gpsPosition != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kSuccess.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kSuccess.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed_rounded,
                        color: _kSuccess, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Location captured',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _kSuccess,
                                  fontSize: 13)),
                          Text(
                            '${_gpsPosition!.latitude.toStringAsFixed(5)}, '
                            '${_gpsPosition!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Text(
                'Tap below to capture your current GPS location. '
                'This verifies you are at the delivery address.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _gettingGps ? null : _getGps,
              icon: _gettingGps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(_gettingGps
                  ? 'Getting location…'
                  : _gpsPosition != null
                      ? 'Refresh Location'
                      : 'Capture Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _gpsPosition != null ? _kSuccess : _kPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );

  Widget _otpCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Find the 6-digit OTP code printed on your packing slip and enter it below.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 22,
                    letterSpacing: 8),
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPink, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _verifyingOtp || _scoreOtp > 0 ? null : _verifyOtp,
              icon: _verifyingOtp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _scoreOtp > 0
                          ? Icons.check_circle_rounded
                          : Icons.verified_user_rounded,
                      size: 18),
              label: Text(
                _verifyingOtp
                    ? 'Verifying…'
                    : _scoreOtp > 0
                        ? 'OTP Verified ✓'
                        : 'Verify OTP Code',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _scoreOtp > 0 ? _kSuccess : _kPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );

  Widget _oneTapCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Already received your package? Tap below to confirm without a photo.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed:
                  _confirming || _scoreConfirm > 0 ? null : _oneTapConfirm,
              icon: _confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _scoreConfirm > 0
                          ? Icons.check_circle_rounded
                          : Icons.touch_app_rounded,
                      size: 18),
              label: Text(
                _confirming
                    ? 'Confirming…'
                    : _scoreConfirm > 0
                        ? 'Confirmed ✓'
                        : 'I received my package',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _scoreConfirm > 0 ? _kSuccess : _kPinkDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _checkRow(String label) => Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _kSuccess, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: _kSuccess,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

