// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import '../auth/login_page.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D97).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFFF4D97),
                      child: const Icon(Icons.person, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Style Enthusiast',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'user@example.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFFFF4D97)),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Settings Sections
            _buildSection('My Beauty', [
              _buildSettingItem(context, Icons.favorite_outline, 'Saved Looks', () {
                _showSavedLooksDialog(context);
              }),
              _buildSettingItem(context, Icons.palette, 'Current Products', () {
                _showCurrentProductsDialog(context);
              }),
            ]),

            _buildSection('Account Settings', [
              _buildSettingItem(context, Icons.person_outline, 'Edit Profile', () {}),
              _buildSettingItem(context, Icons.lock_outline, 'Change Password', () {}),
              _buildSettingItem(context, Icons.notifications_outlined, 'Notifications', () {}),
              _buildSettingItem(context, Icons.privacy_tip_outlined, 'Privacy', () {}),
            ]),

            _buildSection('Preferences', [
              _buildSettingItem(context, Icons.language, 'Language', () {}),
              _buildSettingItem(context, Icons.dark_mode_outlined, 'Dark Mode', () {}),
              _buildSettingItem(context, Icons.storage, 'Storage', () {}),
            ]),

            _buildSection('Support', [
              _buildSettingItem(context, Icons.help_outline, 'Help Center', () {}),
              _buildSettingItem(context, Icons.feedback_outlined, 'Send Feedback', () {}),
              _buildSettingItem(context, Icons.star_outline, 'Rate Us', () {}),
              _buildSettingItem(context, Icons.info_outline, 'About', () {}),
            ]),

            _buildSection('Legal', [
              _buildSettingItem(context, Icons.description_outlined, 'Terms of Service', () {}),
              _buildSettingItem(context, Icons.policy_outlined, 'Privacy Policy', () {}),
            ]),

            const SizedBox(height: 20),
            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: () {
                  _showLogoutDialog(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.grey[700]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
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
