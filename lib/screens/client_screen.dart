// lib/screens/client_screen.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../utils/logout_util.dart';

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
  } catch (_) {
    // Ignore extraction errors
  }
  return '';
}

String? _guessCategory(String text) {
  final lowerText = text.toLowerCase();
  if (lowerText.contains('lipstick') || lowerText.contains('lip gloss') || lowerText.contains('lip tint') || lowerText.contains('lip balm')) return 'Lipstick';
  if (lowerText.contains('blush') || lowerText.contains('rouges')) return 'Blush';
  if (lowerText.contains('contour') || lowerText.contains('bronzer')) return 'Contour';
  if (lowerText.contains('setting spray') || lowerText.contains('fixer')) return 'Setting Spray';
  if (lowerText.contains('eyebrow') || lowerText.contains('brow')) return 'Eyebrow';
  if (lowerText.contains('eyeliner') || lowerText.contains('eye liner')) return 'Eyeliner';
  if (lowerText.contains('eyeshadow') || lowerText.contains('eye shadow') || lowerText.contains('palette')) return 'Eyeshadow';
  if (lowerText.contains('concealer')) return 'Concealer';
  if (lowerText.contains('brush') || lowerText.contains('sponge') || lowerText.contains('tool')) return 'Tools & Brushes';
  return null;
}

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  int _currentSection = 0; // 0: Dashboard, 1: Business Profile, 2: Analytics, 3: Settings
  late Future<Map<String, dynamic>> _clientDataFuture;
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
  final List<Map<String, String>> _shopCategoryOptions = const [
    {'value': 'makeup_brand', 'label': 'Makeup Brand'},
    {'value': 'salon', 'label': 'Salon'},
    {'value': 'artist', 'label': 'Artist'},
    {'value': 'distributor', 'label': 'Distributor'},
    {'value': 'retailer', 'label': 'Retailer'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _clientDataFuture = _fetchClientData();
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
    final logoUrl = (clientData['business_logo_url'] ?? clientData['avatar_url'] ?? '').toString().trim();
    _shopAvatarUrl = logoUrl.isEmpty ? null : logoUrl;
    _shopAvatarName = null;
    _shopAvatarBytes = null;
    _shopFormInitialized = true;
    _shopProfileId = profileId;
  }

  String _fileExtensionFromName(String fileName) {
    final match = RegExp(r'\.(\w+)$').firstMatch(fileName);
    final extension = match?.group(1)?.toLowerCase();
    return extension == null ? 'png' : extension;
  }

  Future<void> _uploadAvatar() async {
    if (_isUploadingAvatar) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to upload an avatar.'), backgroundColor: Colors.red),
      );
      return;
    }

    XFile? pickedFile;
    Uint8List? bytes;

    try {
      pickedFile = await _avatarPicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        return;
      }

      bytes = await pickedFile.readAsBytes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final safeName = pickedFile.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      final extension = _fileExtensionFromName(pickedFile.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${safeName.split('.').first}.$extension';
      final storagePath = '${user.id}/avatars/$fileName';

      await Supabase.instance.client.storage
          .from('scan-images')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage.from('scan-images').getPublicUrl(storagePath);

      await Supabase.instance.client.from('accounts').update({
        'avatar_url': publicUrl,
        'business_logo_url': publicUrl,
      }).eq('id', user.id);

      if (mounted) {
        setState(() {
          _shopAvatarBytes = bytes;
          _shopAvatarName = pickedFile!.name;
          _shopAvatarUrl = publicUrl;
          _shopFormInitialized = false;
          _clientDataFuture = _fetchClientData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _saveShopSettings() async {
    if (_isSavingShop) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to save settings.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_shopName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name is required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSavingShop = true;
    });

    try {
      await Supabase.instance.client.from('accounts').update({
        'business_name': _shopName.trim(),
        'business_type': _shopCategory.trim().isEmpty ? null : _shopCategory.trim(),
        'business_phone': _shopPhone.trim().isEmpty ? null : _shopPhone.trim(),
        'business_address': _shopAddress.trim().isEmpty ? null : _shopAddress.trim(),
      }).eq('id', user.id);

      if (mounted) {
        setState(() {
          _shopFormInitialized = false;
          _clientDataFuture = _fetchClientData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop settings updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save shop settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingShop = false;
        });
      }
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
              child: CircularProgressIndicator(color: Color(0xFFFF4D97)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _clientDataFuture = _fetchClientData();
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final clientData = snapshot.data ?? {};

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth > 800;

            if (isWeb) {
              return _buildWebLayout(clientData);
            }

            return _buildMobileLayout(clientData);
          },
        );
      },
    );
  }

  Widget _buildWebLayout(Map<String, dynamic> clientData) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Row(
        children: [
          // Seller Centre Sidebar
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D97),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Seller Centre',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF4D97),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildSidebarItem('Dashboard', Icons.dashboard_outlined, 0),
                      _buildSidebarItem('My Shop', Icons.storefront_outlined, 1),
                      _buildSidebarItem('My Products', Icons.inventory_2_outlined, 2),
                      _buildSidebarItem('Business Insights', Icons.analytics_outlined, 3),
                      _buildSidebarItem('Settings', Icons.settings_outlined, 4),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                    onTap: _logout,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    hoverColor: Colors.red.shade50,
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.notifications_none, color: Colors.grey),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFFF4D97).withOpacity(0.2),
                            child: Text(
                              (clientData['business_name'] ?? 'B').toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Color(0xFFFF4D97), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            clientData['business_name'] ?? 'Business Account',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _buildSectionContent(clientData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData icon, int index) {
    final isSelected = _currentSection == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF4D97).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFFFF4D97) : Colors.grey.shade600,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF4D97) : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          setState(() {
            _currentSection = index;
          });
        },
      ),
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> clientData) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Seller Centre',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFFFF4D97),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildSectionContent(clientData),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentSection,
          onTap: (index) {
            setState(() {
              _currentSection = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFF4D97),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront_rounded),
              label: 'My Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContent(Map<String, dynamic> clientData) {
    Widget content;
    switch (_currentSection) {
      case 0:
        content = _buildDashboard(clientData);
        break;
      case 1:
        content = _buildMyShopSettings(clientData); // Replaced BusinessProfile with MyShopSettings
        break;
      case 2:
        content = _buildProducts(clientData);
        break;
      case 3:
        content = _buildAnalytics(clientData);
        break;
      case 4:
        content = _buildSettings(clientData);
        break;
      default:
        content = const SizedBox();
    }
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: content,
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> clientData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'To Do List',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Things you need to deal with to keep your shop running smoothly',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _buildTodoItem('0', 'Pending Bookings'),
                _buildTodoItem('2', 'Unread Messages'),
                _buildTodoItem('1', 'Cancellation Requests'),
                _buildTodoItem('5', 'New Reviews'),
              ],
            );
          }
        ),
        const SizedBox(height: 32),
        const Text(
          'Business Performance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMiniStat('Revenue\n(Today)', '?6,600', Icons.attach_money, Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: _buildMiniStat('Visitors\n(Today)', '45', Icons.people_alt_outlined, Colors.blue)),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTodoItem(String count, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF4D97))),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildShopAvatar() {
    final avatarWidget = _shopAvatarBytes != null
        ? Image.memory(_shopAvatarBytes!, fit: BoxFit.cover)
        : (_shopAvatarUrl != null && _shopAvatarUrl!.isNotEmpty)
            ? Image.network(
                _shopAvatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 40, color: Colors.grey),
              )
            : const Icon(Icons.store, size: 40, color: Colors.grey);

    return Column(
      children: [
        // Circular Logo
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade100,
            child: ClipOval(
              child: SizedBox(
                width: 120,
                height: 120,
                child: avatarWidget,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Upload/Replace Button
        ElevatedButton.icon(
          onPressed: _isUploadingAvatar ? null : _uploadAvatar,
          icon: _isUploadingAvatar
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(_isUploadingAvatar ? 'Uploading...' : 'Upload Logo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Square PNG/JPG • Max 5MB',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        if (_shopAvatarName != null) ...[
          const SizedBox(height: 8),
          Text(
            'File: $_shopAvatarName',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ]
      ],
    );
  }

  Widget _buildMyShopSettings(Map<String, dynamic> clientData) {
    _initializeShopForm(clientData);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Shop Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'View and update your shop profile',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 500) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShopAvatar(),
                          const SizedBox(width: 32),
                          Expanded(child: _buildShopForm(true)),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildShopAvatar(),
                          const SizedBox(height: 32),
                          _buildShopForm(false),
                        ],
                      );
                    }
                  }
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShopForm(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileRow('Shop Name', _shopName, (value) => _shopName = value, 'Enter shop name', isDesktop),
        _buildCategoryRow(isDesktop),
        _buildProfileRow('Phone', _shopPhone, (value) => _shopPhone = value, '+1 (555) 000-0000', isDesktop),
        _buildProfileRow('Address', _shopAddress, (value) => _shopAddress = value, 'e.g. 123 Main St', isDesktop),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: isDesktop ? MainAxisAlignment.end : MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isSavingShop ? null : _saveShopSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D97),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: _isSavingShop
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Form', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCategoryRow(bool isDesktop) {
    final validCategoryValues = _shopCategoryOptions.map((option) => option['value']!).toList();
    final currentValue = validCategoryValues.contains(_shopCategory) ? _shopCategory : null;

    Widget dropdown = DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(
        hintText: 'Select category',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFF4D97)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      items: _shopCategoryOptions
          .map(
            (option) => DropdownMenuItem<String>(
              value: option['value'],
              child: Text(option['label']!),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _shopCategory = value ?? '';
        });
      },
    );

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: Text('Category', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            ),
            Expanded(child: dropdown),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          dropdown,
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, ValueChanged<String> onChanged, String hint, bool isDesktop) {
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: _buildTextFieldRaw(value, onChanged, hint),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildTextFieldRaw(value, onChanged, hint),
          ],
        ),
      );
    }
  }

  Widget _buildTextFieldRaw(String value, ValueChanged<String> onChanged, String hint) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFF4D97)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildAnalytics(Map<String, dynamic> clientData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics Overview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text('Track your business performance in real-time', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: [
            _buildStatCard('Total Customers', '1,284', Icons.people_alt, const Color(0xFF4F46E5)),
            _buildStatCard('Active Bookings', '32', Icons.calendar_month, const Color(0xFF10B981)),
            _buildStatCard('Services', '15', Icons.spa, const Color(0xFFF59E0B)),
            _buildStatCard('Revenue (MTD)', '?233,750', Icons.attach_money, const Color(0xFFFF4D97)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSettings(Map<String, dynamic> clientData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 24),
        _buildSettingsGroup(
          'Account',
          [
            _buildSettingsTile('Change Password', Icons.lock_outline, onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset functionality coming soon!')),
              );
            }),
          ],
        ),
        const SizedBox(height: 24),
        _buildSettingsGroup(
          'Preferences',
          [
            _buildSettingsTile('Push Notifications', Icons.notifications_none_outlined, trailing: Switch(
              value: true,
              activeThumbColor: const Color(0xFFFF4D97),
              onChanged: (val) {},
            )),
            _buildSettingsTile('Dark Mode', Icons.dark_mode_outlined, trailing: Switch(
              value: false,
              activeThumbColor: const Color(0xFFFF4D97),
              onChanged: (val) {},
            )),
          ],
        ),
const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildProducts(Map<String, dynamic> clientData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Products',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddProductDialog(clientData['id'] as String),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D97),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Manage the products you offer in the market.', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 24),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('products')
              .stream(primaryKey: ['id'])
              .eq('business_id', clientData['id'])
              .order('created_at'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D97)));
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No products yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Start adding products to sell to your clients.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _showAddProductDialog(clientData['id'] as String),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D97),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Your First Product'),
                    )
                  ],
                ),
              );
            }

            final lowStockCount = products.where((p) => (p['stock_quantity'] as int? ?? 0) <= 5).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lowStockCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Inventory Alert: $lowStockCount product(s) have low stock (5 or less left).',
                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image Placeholder or Network Image
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey.shade100,
                              child: product['image_url'] != null
                                  ? Image.network(product['image_url'], fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey))
                                  : const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showEditProductDialog(product);
                                    } else if (action == 'delete') {
                                      _confirmDeleteProduct(product['id'], product['name']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                  ],
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
                              product['name'] ?? 'Unnamed Product',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${product['price']}',
                              style: const TextStyle(color: Color(0xFFFF4D97), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final stock = product['stock_quantity'] as int? ?? 0;
                                    final isLow = stock <= 5;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isLow) const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                                        if (isLow) const SizedBox(width: 4),
                                        Text(
                                          isLow ? 'Low Stock: $stock' : 'Stock: $stock',
                                          style: TextStyle(
                                            color: isLow ? Colors.orange.shade800 : Colors.grey.shade600, 
                                            fontSize: 12,
                                            fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: product['is_active'] == true ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    product['is_active'] == true ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: product['is_active'] == true ? Colors.green : Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
      ],
    );
  }

  Future<void> _showAddProductDialog(String businessId) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _AddProductDialog(businessId: businessId);
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _clientDataFuture = _fetchClientData();
      });
    }
  }

  Future<void> _showEditProductDialog(Map<String, dynamic> product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _EditProductDialog(product: product);
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _clientDataFuture = _fetchClientData();
      });
    }
  }

  Future<void> _confirmDeleteProduct(dynamic productId, dynamic productName) async {
    final id = productId?.toString();
    final name = (productName ?? 'this product').toString();

    if (id == null || id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete: invalid product id.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final ownerId = Supabase.instance.client.auth.currentUser?.id;
        if (ownerId == null) {
          throw 'You need to be logged in to delete products.';
        }

        final deleted = await Supabase.instance.client
            .from('products')
            .delete()
            .eq('id', id)
            .eq('business_id', ownerId)
            .select('id');

        final deletedCount = deleted.length;

        if (mounted) {
          if (deletedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product deleted successfully'), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Delete failed: product not found or no permission.'), backgroundColor: Colors.orange),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

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
  final _categories = [
    'Lipstick',
    'Blush',
    'Contour',
    'Setting Spray',
    'Eyebrow',
    'Eyeliner',
    'Eyeshadow',
    'Concealer',
    'Tools & Brushes'
  ];

  final List<Map<String, dynamic>> _variations = [];

  void _addVariation() {
    setState(() {
      _variations.add({
        'color_name': '',
        'hex_code': '#FFFFFF',
        'hexController': TextEditingController(text: '#FFFFFF'),
        'price': _priceController.text, // Default to base price
        'stock': _stockController.text, // Default to base stock
        'imageUrl': null,
        'imageBytes': null,
        'imageName': null,
        'decodedImage': null,
      });
    });
  }

  void _removeVariation(int index) {
    setState(() {
      final controller = _variations[index]['hexController'];
      if (controller is TextEditingController) {
        controller.dispose();
      }
      _variations.removeAt(index);
    });
  }

  String _rgbToHex(int r, int g, int b) {
    String toHex(int c) => c.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${toHex(r)}${toHex(g)}${toHex(b)}';
  }

  void _sampleVariationColor(int index, TapDownDetails details, Size displaySize) {
    final variation = _variations[index];
    final bytes = variation['imageBytes'] as Uint8List?;
    if (bytes == null) return;

    img.Image? decoded = variation['decodedImage'] as img.Image?;
    decoded ??= img.decodeImage(bytes);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read the selected variation image.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final imageWidth = decoded.width.toDouble();
    final imageHeight = decoded.height.toDouble();
    final displayWidth = displaySize.width;
    final displayHeight = displaySize.height;

    if (imageWidth <= 0 || imageHeight <= 0 || displayWidth <= 0 || displayHeight <= 0) return;

    final scale = (displayWidth / imageWidth) > (displayHeight / imageHeight)
        ? (displayWidth / imageWidth)
        : (displayHeight / imageHeight);
    final renderedWidth = imageWidth * scale;
    final renderedHeight = imageHeight * scale;
    final offsetX = (displayWidth - renderedWidth) / 2;
    final offsetY = (displayHeight - renderedHeight) / 2;

    final local = details.localPosition;
    final srcX = (((local.dx - offsetX) / scale).floor()).clamp(0, decoded.width - 1);
    final srcY = (((local.dy - offsetY) / scale).floor()).clamp(0, decoded.height - 1);
    final pixel = decoded.getPixel(srcX, srcY);
    final hex = _rgbToHex(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

    setState(() {
      variation['decodedImage'] = decoded;
      variation['hex_code'] = hex;
      final controller = variation['hexController'];
      if (controller is TextEditingController) {
        controller.text = hex;
      }
    });
  }

  Future<void> _pickVariationImage(int index) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _variations[index]['imageBytes'] = bytes;
          _variations[index]['imageName'] = image.name;
          _variations[index]['imageUrl'] = null; // Clear network URL if local selected
          _variations[index]['decodedImage'] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isLoading = false;
  bool _isFetchingMetadata = false;

  Future<void> _fetchMetadata() async {
    final urlStr = _linkController.text.trim();
    if (urlStr.isEmpty) return;

    final uri = Uri.tryParse(urlStr);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL first.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isFetchingMetadata = true;
    });

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      });
      
      String? title;
      String? description;
      String? imageUrl;

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        
        title = document.querySelector('meta[property="og:title"]')?.attributes['content'] ?? document.querySelector('title')?.text;
        description = document.querySelector('meta[property="og:description"]')?.attributes['content'] ?? document.querySelector('meta[name="description"]')?.attributes['content'];
        imageUrl = document.querySelector('meta[property="og:image"]')?.attributes['content'];
      }

      // Check if it's a generic anti-bot title or missing, if so fallback to URL slug
      final lowerTitle = title?.toLowerCase() ?? '';
      if (title == null || title.isEmpty || lowerTitle.contains('shopee') || lowerTitle.contains('lazada') || lowerTitle.contains('attention required') || lowerTitle.contains('just a moment')) {
        String fallbackTitle = _extractNameFromEcommerceUrl(uri);
        if (fallbackTitle.isNotEmpty) {
          title = fallbackTitle;
        }
      }

      setState(() {
        if (title != null && title.isNotEmpty && lowerTitle != 'shopee philippines' && lowerTitle != 'lazada' && _nameController.text.isEmpty) {
          _nameController.text = title;
        }
        if (description != null && description.isNotEmpty && _descriptionController.text.isEmpty) {
          _descriptionController.text = description;
        }
        if (imageUrl != null && imageUrl.isNotEmpty && _imageUrlController.text.isEmpty) {
          _imageUrlController.text = imageUrl;
          _handleImageUrlChanged(imageUrl);
        }
        
        // Auto-guess category if none selected
        if (_selectedCategory == null) {
          String combinedText = '${title ?? ''} ${description ?? ''}';
          String? guessedCategory = _guessCategory(combinedText);
          if (guessedCategory != null) {
            _selectedCategory = guessedCategory;
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product info fetched from link!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch data from the link automatically.'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMetadata = false;
        });
      }
    }
  }

  void _handleImageUrlChanged(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    setState(() {
      _imagePreviewUrl = (trimmed.isNotEmpty && uri != null && (uri.hasScheme && uri.hasAuthority))
          ? trimmed
          : null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
          _imagePreviewUrl = null; // Clear URL preview if local image selected
          _imageUrlController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imagePreviewUrl == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image or provide a valid image URL.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String finalImageUrl = _imagePreviewUrl ?? '';
      String? saveWarning;
      final ownerId = Supabase.instance.client.auth.currentUser?.id ?? widget.businessId;

      // Upload local image to Supabase Storage if one is picked
      if (_selectedImageBytes != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImageName ?? 'image.jpg'}';
        final filePath = '$ownerId/$fileName';
        
        // Attempt to upload. (Assumes a 'products' bucket exists and is public)
        try {
          await Supabase.instance.client.storage
              .from('products')
              .uploadBinary(filePath, _selectedImageBytes!);
          finalImageUrl = Supabase.instance.client.storage.from('products').getPublicUrl(filePath);
        } catch (storageError) {
          debugPrint('Storage Error: $storageError');
          saveWarning = 'Image upload failed. Product will be saved without a local image.';
        }
      }

      // Process Variations Images
      final List<Map<String, dynamic>> processedVariations = [];
      for (int i = 0; i < _variations.length; i++) {
        var v = _variations[i];
        String varImageUrl = v['imageUrl'] ?? '';
        final hexController = v['hexController'];
        
        if (v['imageBytes'] != null) {
          final varFileName = '${DateTime.now().millisecondsSinceEpoch}_var_${v['imageName'] ?? 'image.jpg'}';
          final varFilePath = '$ownerId/$varFileName';
          try {
            await Supabase.instance.client.storage
                .from('products')
                .uploadBinary(varFilePath, v['imageBytes']);
            varImageUrl = Supabase.instance.client.storage.from('products').getPublicUrl(varFilePath);
          } catch (e) {
            debugPrint('Variation storage Error: $e');
            saveWarning = 'One or more variation images failed to upload. Product was still saved.';
          }
        }
        
        processedVariations.add({
          'color_name': v['color_name'],
          'hex_code': hexController is TextEditingController ? hexController.text.trim() : v['hex_code'],
          'price': double.tryParse((v['price'] ?? '').toString()) ?? double.tryParse(_priceController.text) ?? 0.0,
          'stock': int.tryParse((v['stock'] ?? '').toString()) ?? int.tryParse(_stockController.text) ?? 0,
          'image_url': varImageUrl.isEmpty ? null : varImageUrl,
        });
      }

      final fullPayload = {
        'business_id': ownerId,
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock_quantity': int.parse(_stockController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'image_url': finalImageUrl,
        'product_link': _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
        'variations': processedVariations,
      };

      try {
        await Supabase.instance.client.from('products').insert(fullPayload);
      } on PostgrestException catch (dbError) {
        final dbMessage = '${dbError.message} ${dbError.details ?? ''} ${dbError.hint ?? ''}'.toLowerCase();
        final missingNewColumns = dbMessage.contains('column') &&
            (dbMessage.contains('product_link') || dbMessage.contains('variations'));

        if (!missingNewColumns) {
          rethrow;
        }

        final legacyPayload = {
          'business_id': ownerId,
          'name': _nameController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'stock_quantity': int.parse(_stockController.text.trim()),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'image_url': finalImageUrl,
        };

        await Supabase.instance.client.from('products').insert(legacyPayload);
        saveWarning = 'Product saved using legacy table fields. Apply latest DB migration for link/variations support.';
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!'), backgroundColor: Colors.green),
        );
        if (saveWarning != null && saveWarning.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(saveWarning), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final variation in _variations) {
      final controller = variation['hexController'];
      if (controller is TextEditingController) {
        controller.dispose();
      }
    }
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Product'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        decoration: const InputDecoration(labelText: 'Price (₱)', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (int.tryParse(value) == null) return 'Invalid integer';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: 'Product Link (Optional)', 
                    border: const OutlineInputBorder(),
                    suffixIcon: _isFetchingMetadata 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.auto_awesome, color: Color(0xFFFF4D97)),
                            tooltip: 'Auto-fill from link',
                            onPressed: _fetchMetadata,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedImageBytes != null 
                      ? ClipRRect(
                          key: const ValueKey('memory_image'),
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : _imagePreviewUrl != null
                          ? ClipRRect(
                              key: const ValueKey('network_image'),
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 160,
                                width: double.infinity,
                                child: Image.network(
                                  _imagePreviewUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade200,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('placeholder'),
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_outlined, color: Colors.grey, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    'No image selected (required)',
                                    style: TextStyle(color: Colors.grey),
                                  ),
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
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose File / Photo'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFFF4D97)),
                          foregroundColor: const Color(0xFFFF4D97),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  onChanged: _handleImageUrlChanged,
                  decoration: const InputDecoration(
                    labelText: 'Or use Image URL',
                    helperText: 'Provide a valid image link if not uploading a file',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com/image.png',
                    suffixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Variations Section
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Variations (Colors/Shades)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addVariation,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Shade'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D97)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_variations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No variations added. Product has only one base version.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
                ..._variations.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var variation = entry.value;
                  final hexController = variation['hexController'] is TextEditingController
                      ? variation['hexController'] as TextEditingController
                      : TextEditingController(text: variation['hex_code'] ?? '#FFFFFF');
                  if (variation['hexController'] is! TextEditingController) {
                    variation['hexController'] = hexController;
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Variation ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                            InkWell(
                              onTap: () => _removeVariation(idx),
                              child: const Icon(Icons.close, color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: variation['color_name'],
                                decoration: const InputDecoration(labelText: 'Name/Shade', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                onChanged: (val) => variation['color_name'] = val,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: hexController,
                                decoration: const InputDecoration(labelText: 'Hex Code', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                onChanged: (val) => variation['hex_code'] = val.trim(),
                                validator: (val) => (val == null || val.isEmpty || !val.startsWith('#')) ? 'Wait: #...' : null,
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
                                decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                onChanged: (val) => variation['price'] = val,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: variation['stock']?.toString(),
                                decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (val) => variation['stock'] = val,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: variation['imageUrl'],
                                decoration: const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                onChanged: (val) => variation['imageUrl'] = val,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _pickVariationImage(idx),
                              icon: const Icon(Icons.upload, size: 16),
                              label: Text(variation['imageBytes'] != null ? 'Selected' : 'Pick Image'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                backgroundColor: variation['imageBytes'] != null ? Colors.green.shade50 : null,
                                foregroundColor: variation['imageBytes'] != null ? Colors.green : const Color(0xFFFF4D97),
                              ),
                            )
                          ],
                        ),
                        if (variation['imageBytes'] != null) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Tap the image to scan a color for this variant',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onTapDown: (details) => _sampleVariationColor(
                                    idx,
                                    details,
                                    Size(constraints.maxWidth, constraints.maxHeight),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          variation['imageBytes'] as Uint8List,
                                          fit: BoxFit.cover,
                                        ),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            margin: const EdgeInsets.all(6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              hexController.text,
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97), foregroundColor: Colors.white),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save Product'),
        ),
      ],
    );
  }
}

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
  final _imagePicker = ImagePicker();
  final List<Map<String, dynamic>> _variations = [];

  bool _isLoading = false;
  bool _isFetchingMetadata = false;
  late bool _isActive;
  String? _selectedCategory;
  String? _imagePreviewUrl;

  final _categories = [
    'Lipstick',
    'Blush',
    'Contour',
    'Setting Spray',
    'Eyebrow',
    'Eyeliner',
    'Eyeshadow',
    'Concealer',
    'Tools & Brushes'
  ];

  List<String> get _editCategories {
    final categories = List<String>.from(_categories);
    final currentCategory = _selectedCategory?.trim() ?? '';
    if (currentCategory.isNotEmpty && !categories.contains(currentCategory)) {
      categories.insert(0, currentCategory);
    }
    return categories;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['name']);
    _priceController = TextEditingController(text: widget.product['price'].toString());
    _stockController = TextEditingController(text: widget.product['stock_quantity'].toString());
    _descriptionController = TextEditingController(text: widget.product['description']);
    _linkController = TextEditingController(text: widget.product['product_link'] ?? '');
    _imageUrlController = TextEditingController(text: widget.product['image_url'] ?? '');
    _isActive = widget.product['is_active'] ?? true;
    _selectedCategory = widget.product['category'] as String?;
    _imagePreviewUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();

    final rawVariations = widget.product['variations'];
    if (rawVariations is List) {
      for (final rawVariation in rawVariations) {
        if (rawVariation is! Map) continue;

        final colorName = rawVariation['color_name']?.toString() ?? '';
        final hexCode = rawVariation['hex_code']?.toString() ?? '#FFFFFF';
        final price = rawVariation['price']?.toString() ?? _priceController.text;
        final stock = rawVariation['stock']?.toString() ?? _stockController.text;
        final imageUrl = rawVariation['image_url']?.toString();

        _variations.add({
          'color_name': colorName,
          'hex_code': hexCode,
          'hexController': TextEditingController(text: hexCode),
          'price': price,
          'stock': stock,
          'imageUrl': imageUrl == null || imageUrl.isEmpty ? null : imageUrl,
          'imageBytes': null,
          'imageName': null,
          'decodedImage': null,
        });
      }
    }
  }
  
  @override
  void dispose() {
    for (final variation in _variations) {
      final controller = variation['hexController'];
      if (controller is TextEditingController) {
        controller.dispose();
      }
    }
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetadata() async {
    final urlStr = _linkController.text.trim();
    if (urlStr.isEmpty) return;

    final uri = Uri.tryParse(urlStr);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL first.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isFetchingMetadata = true;
    });

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      });
      
      String? title;
      String? description;

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        
        title = document.querySelector('meta[property="og:title"]')?.attributes['content'] ?? document.querySelector('title')?.text;
        description = document.querySelector('meta[property="og:description"]')?.attributes['content'] ?? document.querySelector('meta[name="description"]')?.attributes['content'];
        // Image isn't updatable in the edit dialog right now, but we can set Name and Description
      }

      final lowerTitle = title?.toLowerCase() ?? '';
      if (title == null || title.isEmpty || lowerTitle.contains('shopee') || lowerTitle.contains('lazada') || lowerTitle.contains('attention required') || lowerTitle.contains('just a moment')) {
        String fallbackTitle = _extractNameFromEcommerceUrl(uri);
        if (fallbackTitle.isNotEmpty) {
          title = fallbackTitle;
        }
      }
        
      setState(() {
        if (title != null && title.isNotEmpty && lowerTitle != 'shopee philippines' && lowerTitle != 'lazada' && _nameController.text.isEmpty) {
          _nameController.text = title;
        }
        if (description != null && description.isNotEmpty && _descriptionController.text.isEmpty) {
          _descriptionController.text = description;
        }
        if (_selectedCategory == null) {
          final combinedText = '${title ?? ''} ${description ?? ''}';
          final guessedCategory = _guessCategory(combinedText);
          if (guessedCategory != null) {
            _selectedCategory = guessedCategory;
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product info fetched from link!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch data from the link automatically.'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMetadata = false;
        });
      }
    }
  }

  String _rgbToHex(int r, int g, int b) {
    String toHex(int c) => c.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${toHex(r)}${toHex(g)}${toHex(b)}';
  }

  void _addVariation() {
    setState(() {
      _variations.add({
        'color_name': '',
        'hex_code': '#FFFFFF',
        'hexController': TextEditingController(text: '#FFFFFF'),
        'price': _priceController.text,
        'stock': _stockController.text,
        'imageUrl': null,
        'imageBytes': null,
        'imageName': null,
        'decodedImage': null,
      });
    });
  }

  void _removeVariation(int index) {
    setState(() {
      final controller = _variations[index]['hexController'];
      if (controller is TextEditingController) {
        controller.dispose();
      }
      _variations.removeAt(index);
    });
  }

  void _sampleVariationColor(int index, TapDownDetails details, Size displaySize) {
    final variation = _variations[index];
    final bytes = variation['imageBytes'] as Uint8List?;
    if (bytes == null) return;

    img.Image? decoded = variation['decodedImage'] as img.Image?;
    decoded ??= img.decodeImage(bytes);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read the selected variation image.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final imageWidth = decoded.width.toDouble();
    final imageHeight = decoded.height.toDouble();
    final displayWidth = displaySize.width;
    final displayHeight = displaySize.height;

    if (imageWidth <= 0 || imageHeight <= 0 || displayWidth <= 0 || displayHeight <= 0) return;

    final scale = (displayWidth / imageWidth) > (displayHeight / imageHeight)
        ? (displayWidth / imageWidth)
        : (displayHeight / imageHeight);
    final renderedWidth = imageWidth * scale;
    final renderedHeight = imageHeight * scale;
    final offsetX = (displayWidth - renderedWidth) / 2;
    final offsetY = (displayHeight - renderedHeight) / 2;

    final local = details.localPosition;
    final srcX = (((local.dx - offsetX) / scale).floor()).clamp(0, decoded.width - 1);
    final srcY = (((local.dy - offsetY) / scale).floor()).clamp(0, decoded.height - 1);
    final pixel = decoded.getPixel(srcX, srcY);
    final hex = _rgbToHex(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

    setState(() {
      variation['decodedImage'] = decoded;
      variation['hex_code'] = hex;
      final controller = variation['hexController'];
      if (controller is TextEditingController) {
        controller.text = hex;
      }
    });
  }

  Future<void> _pickVariationImage(int index) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _variations[index]['imageBytes'] = bytes;
          _variations[index]['imageName'] = image.name;
          _variations[index]['imageUrl'] = null;
          _variations[index]['decodedImage'] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleImageUrlChanged(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    setState(() {
      _imagePreviewUrl = (trimmed.isNotEmpty && uri != null && uri.hasScheme && uri.hasAuthority) ? trimmed : null;
    });
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final ownerId = Supabase.instance.client.auth.currentUser?.id;
      final List<Map<String, dynamic>> processedVariations = [];

      if (ownerId != null) {
        for (int i = 0; i < _variations.length; i++) {
          final variation = _variations[i];
          String varImageUrl = variation['imageUrl'] ?? '';
          final hexController = variation['hexController'];

          if (variation['imageBytes'] != null) {
            final varFileName = '${DateTime.now().millisecondsSinceEpoch}_edit_var_${variation['imageName'] ?? 'image.jpg'}';
            final varFilePath = '$ownerId/$varFileName';
            try {
              await Supabase.instance.client.storage
                  .from('products')
                  .uploadBinary(varFilePath, variation['imageBytes']);
              varImageUrl = Supabase.instance.client.storage.from('products').getPublicUrl(varFilePath);
            } catch (e) {
              debugPrint('Edit variation storage Error: $e');
            }
          }

          processedVariations.add({
            'color_name': variation['color_name'],
            'hex_code': hexController is TextEditingController ? hexController.text.trim() : variation['hex_code'],
            'price': double.tryParse((variation['price'] ?? '').toString()) ?? double.tryParse(_priceController.text) ?? 0.0,
            'stock': int.tryParse((variation['stock'] ?? '').toString()) ?? int.tryParse(_stockController.text) ?? 0,
            'image_url': varImageUrl.isEmpty ? null : varImageUrl,
          });
        }
      }

      await Supabase.instance.client.from('products').update({
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock_quantity': int.parse(_stockController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'product_link': _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
        'image_url': _imagePreviewUrl,
        'variations': processedVariations,
        'is_active': _isActive,
      }).eq('id', widget.product['id']);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Product'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _editCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        decoration: const InputDecoration(labelText: 'Price'),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Stock'),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: 'Product Link (Optional)',
                    suffixIcon: _isFetchingMetadata 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.auto_awesome, color: Color(0xFFFF4D97)),
                            tooltip: 'Auto-fill from link',
                            onPressed: _fetchMetadata,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrlController,
                  onChanged: _handleImageUrlChanged,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    helperText: 'Paste a public image link if you want to change the image',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com/image.png',
                    suffixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 12),
                if (_imagePreviewUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Image.network(
                        _imagePreviewUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: const Text('No image URL set', style: TextStyle(color: Colors.grey)),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Variations (Colors/Shades)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addVariation,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Shade'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D97)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_variations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No variations added. Product has only one base version.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
                ..._variations.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final variation = entry.value;
                  final hexController = variation['hexController'] is TextEditingController
                      ? variation['hexController'] as TextEditingController
                      : TextEditingController(text: variation['hex_code'] ?? '#FFFFFF');
                  if (variation['hexController'] is! TextEditingController) {
                    variation['hexController'] = hexController;
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Variation ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                            InkWell(
                              onTap: () => _removeVariation(idx),
                              child: const Icon(Icons.close, color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: variation['color_name'],
                                decoration: const InputDecoration(labelText: 'Name/Shade', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                onChanged: (val) => variation['color_name'] = val,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: hexController,
                                decoration: const InputDecoration(labelText: 'Hex Code', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                onChanged: (val) => variation['hex_code'] = val.trim(),
                                validator: (val) => (val == null || val.isEmpty || !val.startsWith('#')) ? 'Wait: #...' : null,
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
                                decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                onChanged: (val) => variation['price'] = val,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: variation['stock']?.toString(),
                                decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (val) => variation['stock'] = val,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: variation['imageUrl'],
                                decoration: const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
                                onChanged: (val) => variation['imageUrl'] = val,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _pickVariationImage(idx),
                              icon: const Icon(Icons.upload, size: 16),
                              label: Text(variation['imageBytes'] != null ? 'Selected' : 'Pick Image'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                backgroundColor: variation['imageBytes'] != null ? Colors.green.shade50 : null,
                                foregroundColor: variation['imageBytes'] != null ? Colors.green : const Color(0xFFFF4D97),
                              ),
                            )
                          ],
                        ),
                        if (variation['imageBytes'] != null) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Tap the image to scan a color for this variant',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onTapDown: (details) => _sampleVariationColor(
                                    idx,
                                    details,
                                    Size(constraints.maxWidth, constraints.maxHeight),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          variation['imageBytes'] as Uint8List,
                                          fit: BoxFit.cover,
                                        ),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            margin: const EdgeInsets.all(6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              hexController.text,
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Is Active'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitEdit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D97), foregroundColor: Colors.white),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save Changes'),
        ),
      ],
    );
  }
}

