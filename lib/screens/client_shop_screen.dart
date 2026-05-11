import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientShopScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientShopScreen({super.key, required this.clientData});

  @override
  State<ClientShopScreen> createState() => _ClientShopScreenState();
}

class _ClientShopScreenState extends State<ClientShopScreen>
    with SingleTickerProviderStateMixin {
  String _shopName = '';
  String _shopCategory = '';
  String _shopPhone = '';
  String _shopAddress = '';
  String? _shopAvatarUrl;
  Uint8List? _shopAvatarBytes;
  String? _shopAvatarName;
  bool _isSavingShop = false;
  bool _isUploadingAvatar = false;
  Map<String, String> _initialSnapshot = const {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Pink theme colors
  static const Color pinkPrimary = Color(0xFFFF4D8C);
  static const Color pinkDark = Color(0xFFD6336C);
  static const Color pinkLight = Color(0xFFFFB8D4);
  static const Color pinkSoft = Color(0xFFFFF0F5);
  static const Color pinkAccent = Color(0xFFFF6B9D);
  static const Color pinkDeep = Color(0xFFC71563);

  final ImagePicker _avatarPicker = ImagePicker();

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
    _initializeShopForm(widget.clientData);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ClientShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientData['id'] != widget.clientData['id']) {
      _initializeShopForm(widget.clientData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          color: pinkSoft.withOpacity(0.5),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(isDesktop),
                const SizedBox(height: 32),

                // Main Content
                if (isDesktop)
                  _buildDesktopLayout(isDesktop)
                else
                  _buildMobileLayout(isTablet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pinkDark, pinkPrimary, pinkAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Profile ✨',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your store information and branding',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_isDirty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text(
                    'Unsaved',
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
    );
  }

  Widget _buildDesktopLayout(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _buildAvatarCard(),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildFormCard(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isTablet) {
    return Column(
      children: [
        _buildAvatarCard(),
        const SizedBox(height: 24),
        _buildFormCard(),
      ],
    );
  }

  Widget _buildAvatarCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Store Logo 🏪',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: pinkDeep,
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      pinkPrimary.withOpacity(0.2),
                      pinkAccent.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pinkPrimary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 78,
                  backgroundColor: Colors.white,
                  backgroundImage: _shopAvatarBytes != null
                      ? MemoryImage(_shopAvatarBytes!)
                      : (_shopAvatarUrl != null
                          ? NetworkImage(_shopAvatarUrl!)
                          : null),
                  child: (_shopAvatarBytes == null && _shopAvatarUrl == null)
                      ? Icon(
                          Icons.store_rounded,
                          size: 60,
                          color: pinkPrimary.withOpacity(0.5),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [pinkPrimary, pinkAccent],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: pinkPrimary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isUploadingAvatar ? null : _uploadAvatar,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: _isUploadingAvatar
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pinkSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _shopAvatarName ?? 'Tap to upload logo',
              style: TextStyle(
                fontSize: 13,
                color: _shopAvatarName != null ? pinkDark : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Recommended: 500x500px\nPNG or JPG format',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (_shopAvatarUrl != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _shopAvatarBytes = null;
                  _shopAvatarUrl = null;
                  _shopAvatarName = null;
                });
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove Logo'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinkLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: pinkPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Store Information 📋',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: pinkDeep,
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Shop Name',
            hint: 'Enter your store name',
            icon: Icons.store_rounded,
            value: _shopName,
            onChanged: (val) => setState(() => _shopName = val),
          ),
          const SizedBox(height: 20),
          _buildCategoryDropdown(),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Phone Number',
            hint: 'Enter contact number',
            icon: Icons.phone_rounded,
            value: _shopPhone,
            onChanged: (val) => setState(() => _shopPhone = val),
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Address',
            hint: 'Enter store address',
            icon: Icons.location_on_rounded,
            value: _shopAddress,
            onChanged: (val) => setState(() => _shopAddress = val),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          
          // Unsaved changes indicator
          if (_isDirty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You have unsaved changes',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Action Buttons
          Row(
            children: [
              if (_isDirty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetChanges,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (_isDirty) const SizedBox(width: 12),
              Expanded(
                flex: _isDirty ? 2 : 1,
                child: ElevatedButton.icon(
                  onPressed: _isSavingShop || !_isDirty ? null : _saveShopSettings,
                  icon: _isSavingShop
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    _isSavingShop ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: _isDirty ? 4 : 0,
                    shadowColor: pinkPrimary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required String value,
    required Function(String) onChanged,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: pinkPrimary, size: 20),
            filled: true,
            fillColor: pinkSoft.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: pinkLight.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: pinkLight.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: pinkPrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Category',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _shopCategoryOptions.any((opt) => opt['value'] == _shopCategory)
              ? _shopCategory
              : null,
          decoration: InputDecoration(
            hintText: 'Select category',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.category_rounded, color: pinkPrimary, size: 20),
            filled: true,
            fillColor: pinkSoft.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: pinkLight.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: pinkLight.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: pinkPrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: pinkPrimary),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _shopCategoryOptions
              .map(
                (opt) => DropdownMenuItem(
                  value: opt['value'],
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(opt['value']!),
                        size: 18,
                        color: pinkPrimary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        opt['label']!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _shopCategory = val ?? ''),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'makeup_brand':
        return Icons.brush_rounded;
      case 'salon':
        return Icons.content_cut_rounded;
      case 'artist':
        return Icons.palette_rounded;
      case 'distributor':
        return Icons.local_shipping_rounded;
      case 'retailer':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.store_rounded;
    }
  }

  void _initializeShopForm(Map<String, dynamic> clientData) {
    _shopName = (clientData['business_name'] ?? '').toString();
    _shopCategory = (clientData['business_type'] ?? '').toString();
    _shopPhone = (clientData['business_phone'] ?? '').toString();
    _shopAddress = (clientData['business_address'] ?? '').toString();

    _initialSnapshot = {
      'name': _shopName,
      'category': _shopCategory,
      'phone': _shopPhone,
      'address': _shopAddress,
    };

    final logoUrl =
        (clientData['business_logo_url'] ?? clientData['avatar_url'] ?? '')
            .toString()
            .trim();
    _shopAvatarUrl = logoUrl.isEmpty ? null : logoUrl;
    _shopAvatarName = null;
    _shopAvatarBytes = null;
  }

  bool get _isDirty {
    return _shopName != _initialSnapshot['name'] ||
        _shopCategory != _initialSnapshot['category'] ||
        _shopPhone != _initialSnapshot['phone'] ||
        _shopAddress != _initialSnapshot['address'];
  }

  void _resetChanges() {
    setState(() {
      _shopName = _initialSnapshot['name'] ?? '';
      _shopCategory = _initialSnapshot['category'] ?? '';
      _shopPhone = _initialSnapshot['phone'] ?? '';
      _shopAddress = _initialSnapshot['address'] ?? '';
    });
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
      pickedFile = await _avatarPicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
    } catch (_) {
      return;
    }

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final safeName = pickedFile.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      final extension = _fileExtensionFromName(pickedFile.name);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$safeName.$extension';
      final storagePath = '${user.id}/avatars/$fileName';

      await Supabase.instance.client.storage.from('scan-images').uploadBinary(
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

      if (!mounted) return;
      setState(() {
        _shopAvatarBytes = bytes;
        _shopAvatarName = pickedFile?.name ?? 'Selected image';
        _shopAvatarUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Logo uploaded successfully! ✨'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Upload failed: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Shop name is required'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
            'business_phone':
                _shopPhone.trim().isEmpty ? null : _shopPhone.trim(),
            'business_address':
                _shopAddress.trim().isEmpty ? null : _shopAddress.trim(),
          })
          .eq('id', user.id);

      if (!mounted) return;
      _initialSnapshot = {
        'name': _shopName,
        'category': _shopCategory,
        'phone': _shopPhone,
        'address': _shopAddress,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Settings saved successfully! 💖'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingShop = false);
    }
  }
}