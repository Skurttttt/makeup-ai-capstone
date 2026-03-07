// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_supabase_page.dart';
import '../services/supabase_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _userEmail = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final fullName = meta['full_name'] as String? ?? '';
      final name = meta['name'] as String? ?? '';
      setState(() {
        _userEmail = user.email ?? '';
        _userName = fullName.trim().isNotEmpty
            ? fullName.trim()
            : name.trim().isNotEmpty
                ? name.trim()
                : 'Beauty Enthusiast';
      });
    }
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            centerTitle: true,
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
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: const Icon(Icons.person, size: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName.isEmpty ? 'Beauty Enthusiast' : _userName,
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
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Edit profile coming soon')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings Sections
                _buildSection('My Beauty', [
              _buildSettingItem(context, Icons.favorite_outline, 'Saved Looks', () {
                _showSavedLooksDialog(context);
                  }, iconColor: const Color(0xFFFF4D97)),
                  _buildSettingItem(context, Icons.palette, 'Current Products', () {
                    _showCurrentProductsDialog(context);
                  }, iconColor: const Color(0xFFFF8DC7)),
                ]),

                _buildSection('Account Settings', [
                  _buildSettingItem(context, Icons.person_outline, 'Edit Profile', () {}, iconColor: const Color(0xFF4568DC)),
                  _buildSettingItem(context, Icons.lock_outline, 'Change Password', () {}, iconColor: const Color(0xFF3B82F6)),
                  _buildSettingItem(context, Icons.notifications_outlined, 'Notifications', () {}, iconColor: const Color(0xFF6366F1)),
                  _buildSettingItem(context, Icons.privacy_tip_outlined, 'Privacy', () {}, iconColor: const Color(0xFF8B5CF6)),
                ]),

                _buildSection('Preferences', [
                  _buildSettingItem(context, Icons.language, 'Language', () {}, iconColor: const Color(0xFF06B6D4)),
                  _buildSettingItem(context, Icons.dark_mode_outlined, 'Dark Mode', () {}, iconColor: const Color(0xFF1E293B)),
                  _buildSettingItem(context, Icons.storage, 'Storage', () {}, iconColor: const Color(0xFF64748B)),
                ]),

                _buildSection('Support', [
                  _buildSettingItem(context, Icons.help_outline, 'Help Center', () {}, iconColor: const Color(0xFF10B981)),
                  _buildSettingItem(context, Icons.feedback_outlined, 'Send Feedback', () {}, iconColor: const Color(0xFF059669)),
                  _buildSettingItem(context, Icons.star_outline, 'Rate Us', () {}, iconColor: const Color(0xFFF59E0B)),
                  _buildSettingItem(context, Icons.info_outline, 'About', () {}, iconColor: const Color(0xFF0EA5E9)),
                ]),

                _buildSection('Legal', [
                  _buildSettingItem(context, Icons.description_outlined, 'Terms of Service', () {}, iconColor: const Color(0xFF94A3B8)),
                  _buildSettingItem(context, Icons.policy_outlined, 'Privacy Policy', () {}, iconColor: const Color(0xFF94A3B8)),
                ]),

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D97),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                        shadowColor: const Color(0xFFFF4D97).withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
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
                  fontSize: 11,
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

  Widget _buildSettingItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color iconColor = const Color(0xFFFF4D97)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
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
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context, rootNavigator: true);
              navigator.pop();
              
              // Log user logout before signing out
              try {
                final supabaseService = SupabaseService();
                await supabaseService.logAdminAction(
                  action: 'user_logout',
                  target: 'auth',
                  metadata: {
                    'email': Supabase.instance.client.auth.currentUser?.email,
                    'logout_time': DateTime.now().toIso8601String(),
                  },
                );
              } catch (e) {
                debugPrint('Failed to log logout audit: $e');
              }
              
              await Supabase.instance.client.auth.signOut();
              
              if (context.mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginSupabasePage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSavedLooksDialog(BuildContext context) {
    final savedLooks = [
      {'name': 'Soft Glam', 'date': 'Applied 2 hours ago', 'icon': Icons.face_retouching_natural, 'color': Colors.pink},
      {'name': 'Natural Look', 'date': 'Applied yesterday', 'icon': Icons.nature, 'color': Colors.green},
      {'name': 'Everyday Makeup', 'date': 'Applied 3 days ago', 'icon': Icons.wb_sunny, 'color': Colors.orange},
      {'name': 'Emo Style', 'date': 'Applied 1 week ago', 'icon': Icons.dark_mode, 'color': Colors.indigo},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFFF4D97)),
            const SizedBox(width: 8),
            const Text(
              'Saved Looks',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: savedLooks.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final look = savedLooks[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (look['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    look['icon'] as IconData,
                    color: look['color'] as Color,
                  ),
                ),
                title: Text(
                  look['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  look['date'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Viewing ${look['name']}'),
                            backgroundColor: const Color(0xFFFF4D97),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${look['name']} removed'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFF4D97)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCurrentProductsDialog(BuildContext context) {
    final currentProducts = [
      {
        'name': 'Ruby Red Lipstick',
        'category': 'Lips',
        'brand': 'Glamour Beauty',
        'icon': Icons.color_lens,
        'color': Colors.red,
      },
      {
        'name': 'Shimmer Eyeshadow Palette',
        'category': 'Eyes',
        'brand': 'Eye Couture',
        'icon': Icons.remove_red_eye,
        'color': Colors.purple,
      },
      {
        'name': 'Perfect Coverage Foundation',
        'category': 'Foundation',
        'brand': 'Pro Base',
        'icon': Icons.face,
        'color': Colors.amber,
      },
      {
        'name': 'Rose Blush',
        'category': 'Blush',
        'brand': 'Cheek Perfection',
        'icon': Icons.favorite,
        'color': Colors.pink,
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.palette, color: Color(0xFFFF4D97)),
            const SizedBox(width: 8),
            const Text(
              'Current Products',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: currentProducts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final product = currentProducts[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (product['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    product['icon'] as IconData,
                    color: product['color'] as Color,
                  ),
                ),
                title: Text(
                  product['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${product['category']} • ${product['brand']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Editing ${product['name']}'),
                            backgroundColor: const Color(0xFFFF4D97),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product['name']} removed'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Add Product',
              style: TextStyle(color: Color(0xFFFF4D97)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
