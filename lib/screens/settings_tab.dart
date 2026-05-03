// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/logout_util.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _userEmail = '';
  String _userName = '';
  String _userId = '';
  String _userPhone = '';
  String _userAddress = '';

  // Settings state
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedLanguage = 'English';
  bool _faceRecognitionEnabled = true;
  bool _autoSaveLooks = true;

  final List<Map<String, dynamic>> _savedLooks = [
    {
      'id': '1',
      'name': 'Soft Glam',
      'date': DateTime.now().subtract(const Duration(hours: 2)),
      'icon': Icons.face_retouching_natural,
      'color': 0xFFFF4D97,
    },
    {
      'id': '2',
      'name': 'Natural Look',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'icon': Icons.nature,
      'color': 0xFF10B981,
    },
    {
      'id': '3',
      'name': 'Everyday Makeup',
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'icon': Icons.wb_sunny,
      'color': 0xFFF59E0B,
    },
    {
      'id': '4',
      'name': 'Emo Style',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'icon': Icons.dark_mode,
      'color': 0xFF6366F1,
    },
  ];

  final List<Map<String, dynamic>> _currentProducts = [
    {
      'id': '1',
      'name': 'Ruby Red Lipstick',
      'category': 'Lips',
      'brand': 'Glamour Beauty',
      'icon': Icons.color_lens,
      'color': 0xFFEF4444,
    },
    {
      'id': '2',
      'name': 'Shimmer Eyeshadow Palette',
      'category': 'Eyes',
      'brand': 'Eye Couture',
      'icon': Icons.remove_red_eye,
      'color': 0xFF8B5CF6,
    },
    {
      'id': '3',
      'name': 'Perfect Coverage Foundation',
      'category': 'Foundation',
      'brand': 'Pro Base',
      'icon': Icons.face,
      'color': 0xFFF59E0B,
    },
    {
      'id': '4',
      'name': 'Rose Blush',
      'category': 'Blush',
      'brand': 'Cheek Perfection',
      'icon': Icons.favorite,
      'color': 0xFFEC4899,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final fullName = meta['full_name'] as String? ?? '';
      final name = meta['name'] as String? ?? '';
      setState(() {
        _userEmail = user.email ?? '';
        _userId = user.id;
        _userPhone =
            (meta['phone_number'] as String? ?? meta['phone'] as String? ?? '')
                .trim();
        _userAddress = (meta['address'] as String? ?? '').trim();
        _userName = fullName.trim().isNotEmpty
            ? fullName.trim()
            : name.trim().isNotEmpty
            ? name.trim()
            : 'Beauty Enthusiast';
      });
    }
  }

  void _loadSettings() {
    // Load settings from shared preferences or local storage
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFFF4D97),
            elevation: 0,
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.save_outlined),
                onPressed: _saveSettings,
                tooltip: 'Save Settings',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile Hero Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D97), Color(0xFFFF8DC7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D97).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName.isEmpty
                                  ? 'Beauty Enthusiast'
                                  : _userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail.isEmpty ? 'Loading...' : _userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_userPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _userPhone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (_userAddress.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _userAddress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.78),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings Sections
                _buildSection('My Beauty', [
                  _buildSettingItem(
                    Icons.favorite_outline,
                    'Saved Looks',
                    '${_savedLooks.length} items',
                    () => _showSavedLooksDialog(),
                    const Color(0xFFFF4D97),
                  ),
                  _buildSettingItem(
                    Icons.palette,
                    'Current Products',
                    '${_currentProducts.length} products',
                    () => _showCurrentProductsDialog(),
                    const Color(0xFFFF8DC7),
                  ),
                  _buildSwitchItem(
                    Icons.face_retouching_natural,
                    'Face Recognition',
                    _faceRecognitionEnabled,
                    (value) => setState(() => _faceRecognitionEnabled = value),
                    const Color(0xFF8B5CF6),
                  ),
                  _buildSwitchItem(
                    Icons.auto_awesome,
                    'Auto-Save Looks',
                    _autoSaveLooks,
                    (value) => setState(() => _autoSaveLooks = value),
                    const Color(0xFF10B981),
                  ),
                ]),

                _buildSection('Account Settings', [
                  _buildSettingItem(
                    Icons.person_outline,
                    'Edit Profile',
                    null,
                    () => _showEditProfileDialog(),
                    const Color(0xFF4568DC),
                  ),
                  _buildSettingItem(
                    Icons.lock_outline,
                    'Change Password',
                    null,
                    () => _showChangePasswordDialog(),
                    const Color(0xFF3B82F6),
                  ),
                  _buildSwitchItem(
                    Icons.notifications_outlined,
                    'Notifications',
                    _notificationsEnabled,
                    (value) => setState(() => _notificationsEnabled = value),
                    const Color(0xFF6366F1),
                  ),
                  _buildSettingItem(
                    Icons.privacy_tip_outlined,
                    'Privacy Settings',
                    null,
                    () => _showPrivacyDialog(),
                    const Color(0xFF8B5CF6),
                  ),
                ]),

                _buildSection('Preferences', [
                  _buildSettingItem(
                    Icons.language,
                    'Language',
                    _selectedLanguage,
                    () => _showLanguageDialog(),
                    const Color(0xFF06B6D4),
                  ),
                  _buildSwitchItem(
                    Icons.dark_mode_outlined,
                    'Dark Mode',
                    _darkMode,
                    (value) {
                      setState(() => _darkMode = value);
                      _showSettingsMessage(
                        'Dark Mode ${value ? "enabled" : "disabled"}',
                      );
                    },
                    const Color(0xFF1E293B),
                  ),
                  _buildSettingItem(
                    Icons.storage,
                    'Storage & Cache',
                    null,
                    () => _showStorageDialog(),
                    const Color(0xFF64748B),
                  ),
                ]),

                _buildSection('Support', [
                  _buildSettingItem(
                    Icons.help_outline,
                    'Help Center',
                    null,
                    () => _showHelpDialog(),
                    const Color(0xFF10B981),
                  ),
                  _buildSettingItem(
                    Icons.feedback_outlined,
                    'Send Feedback',
                    null,
                    () => _showFeedbackDialog(),
                    const Color(0xFF059669),
                  ),
                  _buildSettingItem(
                    Icons.star_outline,
                    'Rate Us',
                    null,
                    () => _rateUs(),
                    const Color(0xFFF59E0B),
                  ),
                  _buildSettingItem(
                    Icons.info_outline,
                    'About',
                    null,
                    () => _showAboutDialog(),
                    const Color(0xFF0EA5E9),
                  ),
                ]),

                _buildSection('Legal', [
                  _buildSettingItem(
                    Icons.description_outlined,
                    'Terms of Service',
                    null,
                    () => _showTermsDialog(),
                    const Color(0xFF94A3B8),
                  ),
                  _buildSettingItem(
                    Icons.policy_outlined,
                    'Privacy Policy',
                    null,
                    () => _showPrivacyPolicyDialog(),
                    const Color(0xFF94A3B8),
                  ),
                ]),

                const SizedBox(height: 16),
                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        'LOG OUT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D97),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFFFF4D97).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D97),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap,
    Color iconColor,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A1D2E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(
    IconData icon,
    String title,
    bool value,
    Function(bool) onChanged,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF4D97),
            activeTrackColor: const Color(0xFFFF4D97).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  void _showSettingsMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);
    final phoneController = TextEditingController(text: _userPhone);
    final addressController = TextEditingController(text: _userAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();
              final newAddress = addressController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(
                      data: {
                        'full_name': newName,
                        'phone_number': newPhone,
                        'phone': newPhone,
                        'address': newAddress,
                      },
                    ),
                  );
                  setState(() {
                    _userName = newName;
                    _userPhone = newPhone;
                    _userAddress = newAddress;
                  });
                  _showSettingsMessage('Profile updated');
                } catch (e) {
                  _showSettingsMessage('Error: $e');
                }
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    _showVerifyCurrentPasswordDialog();
  }

  void _showVerifyCurrentPasswordDialog() {
    final currentPasswordController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Verify Current Password',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        final currentPass = currentPasswordController.text
                            .trim();

                        if (currentPass.isEmpty) {
                          _showSettingsMessage(
                            'Please enter your current password',
                          );
                          return;
                        }

                        setDialogState(() => isVerifying = true);

                        try {
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          if (user?.email == null) {
                            _showSettingsMessage('Unable to verify password');
                            setDialogState(() => isVerifying = false);
                            return;
                          }

                          await Supabase.instance.client.auth
                              .signInWithPassword(
                                email: user!.email!,
                                password: currentPass,
                              );

                          if (mounted) {
                            Navigator.pop(context);
                            _showSetNewPasswordDialog();
                          }
                        } catch (e) {
                          setDialogState(() => isVerifying = false);
                          _showSettingsMessage(
                            'Incorrect password. Please try again.',
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D97),
                ),
                child: isVerifying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCurrentProductsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: Color(0xFFFF4D97)),
            const SizedBox(width: 8),
            const Text(
              'Current Products',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _currentProducts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No current products available')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _currentProducts.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final product = _currentProducts[index];
                    final Color accentColor = Color(product['color'] as int);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: accentColor.withOpacity(0.15),
                        child: Icon(
                          product['icon'] as IconData,
                          color: accentColor,
                        ),
                      ),
                      title: Text(
                        product['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${product['category']} • ${product['brand']}',
                      ),
                    );
                  },
                ),
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

  void _showSetNewPasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool _isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Set New Password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : () async {
                      final newPass = newPasswordController.text.trim();
                      final confirmPass = confirmPasswordController.text.trim();

                      if (newPass != confirmPass) {
                        _showSettingsMessage('Passwords do not match');
                        return;
                      }

                      if (newPass.length < 6) {
                        _showSettingsMessage(
                          'Password must be at least 6 characters',
                        );
                        return;
                      }

                      setDialogState(() => _isUpdating = true);

                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPass),
                        );
                        _showSettingsMessage('Password changed successfully');
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _showSettingsMessage('Error: $e');
                      } finally {
                        if (mounted) setDialogState(() => _isUpdating = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D97),
              ),
              child: _isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = [
      'English',
      'Filipino',
      'Spanish',
      'French',
      'Japanese',
      'Korean',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Select Language',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: languages.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final language = languages[index];
              return ListTile(
                title: Text(language),
                trailing: _selectedLanguage == language
                    ? const Icon(Icons.check, color: Color(0xFFFF4D97))
                    : null,
                onTap: () {
                  setState(() => _selectedLanguage = language);
                  Navigator.pop(context);
                  _showSettingsMessage('Language changed to $language');
                },
              );
            },
          ),
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

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Privacy Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Share Usage Data'),
              subtitle: const Text('Help us improve the app'),
              value: true,
              onChanged: (value) {},
              activeColor: const Color(0xFFFF4D97),
            ),
            SwitchListTile(
              title: const Text('Personalized Recommendations'),
              subtitle: const Text('Get better product suggestions'),
              value: true,
              onChanged: (value) {},
              activeColor: const Color(0xFFFF4D97),
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

  void _showStorageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Storage',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFFF4D97),
              ),
              title: const Text('Cached Images'),
              trailing: Text(
                '24.5 MB',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Clear Cache'),
              trailing: ElevatedButton(
                onPressed: () {
                  _showSettingsMessage('Cache cleared');
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(70, 32),
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.question_answer,
                color: Color(0xFFFF4D97),
              ),
              title: const Text('FAQ'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showSettingsMessage('FAQ coming soon');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.contact_support,
                color: Color(0xFFFF4D97),
              ),
              title: const Text('Contact Support'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showSettingsMessage('support@beautyshop.com');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school, color: Color(0xFFFF4D97)),
              title: const Text('Tutorials'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(context);
                _showSettingsMessage('Tutorials coming soon');
              },
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

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Send Feedback',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: feedbackController,
          decoration: const InputDecoration(
            hintText: 'Share your thoughts...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final feedback = feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                _showSettingsMessage('Thank you for your feedback!');
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _rateUs() {
    _showSettingsMessage('Rate us on the App Store');
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
            const Icon(Icons.storefront, size: 64, color: Color(0xFFFF4D97)),
            const SizedBox(height: 12),
            const Text(
              'Beauty Shop',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Version 1.0.0', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            const Text(
              'Your one-stop beauty destination for makeup and skincare products.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.web, color: Color(0xFFFF4D97)),
              title: const Text('Website'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _showSettingsMessage('www.beautyshop.com'),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFFFF4D97)),
              title: const Text('Email'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _showSettingsMessage('info@beautyshop.com'),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Terms of Service',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'Terms of Service\n\n'
              'Last updated: January 1, 2024\n\n'
              'Please read these Terms of Service carefully before using the Beauty Shop mobile application.\n\n'
              'Your access to and use of the Service is conditioned on your acceptance of and compliance with these Terms.\n\n'
              'By accessing or using the Service you agree to be bound by these Terms.\n\n'
              'If you have any questions about these Terms, please contact us at info@beautyshop.com.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
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

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'Privacy Policy\n\n'
              'Last updated: January 1, 2024\n\n'
              'This Privacy Policy describes our policies on the collection, use and disclosure of your information.\n\n'
              'We value your privacy and are committed to protecting your personal data.\n\n'
              'If you have any questions about this Privacy Policy, please contact us at info@beautyshop.com.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
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

  void _showLogoutDialog() {
    showLogoutConfirmationDialog(context, role: 'user');
  }

  void _showSavedLooksDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFF4D97)),
                const SizedBox(width: 8),
                const Text(
                  'Saved Looks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _savedLooks.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No saved looks yet')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _savedLooks.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final look = _savedLooks[index];
                        final DateTime savedDate = look['date'] as DateTime;
                        final Color accentColor = Color(look['color'] as int);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.15),
                            child: Icon(
                              look['icon'] as IconData,
                              color: accentColor,
                            ),
                          ),
                          title: Text(
                            look['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            DateFormat(
                              'MMM d, yyyy • h:mm a',
                            ).format(savedDate),
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                _savedLooks.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Delete look',
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}
