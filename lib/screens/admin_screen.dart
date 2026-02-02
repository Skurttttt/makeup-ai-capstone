// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _currentIndex = 0;

  final List<Widget> _adminTabs = [
    const AdminDashboardTab(),
    const AdminUsersTab(),
    const AdminAnalyticsTab(),
    const AdminSettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: _adminTabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF4D97),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: Implement logout
              // context.read<AuthService>().logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome, Admin',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(
                title: 'Total Users',
                value: '1,245',
                icon: Icons.people,
                color: Colors.blue,
              ),
              _StatCard(
                title: 'Active Scans',
                value: '342',
                icon: Icons.face_retouching_natural,
                color: const Color(0xFFFF4D97),
              ),
              _StatCard(
                title: 'Revenue',
                value: '\$5,230',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              _StatCard(
                title: 'Support Tickets',
                value: '18',
                icon: Icons.help,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _ActivityItem(
            title: 'New user registered',
            subtitle: 'sarah.m@example.com',
            time: '2 hours ago',
            icon: Icons.person_add,
          ),
          _ActivityItem(
            title: 'Premium subscription',
            subtitle: 'john.doe@example.com',
            time: '5 hours ago',
            icon: Icons.card_membership,
          ),
          _ActivityItem(
            title: 'Support ticket opened',
            subtitle: 'Issue with camera access',
            time: '1 day ago',
            icon: Icons.list_alt,
          ),
        ],
      ),
    );
  }
}

class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [
      {'name': 'Sarah M.', 'email': 'sarah.m@example.com', 'status': 'Active', 'role': 'User'},
      {'name': 'John Doe', 'email': 'john.doe@example.com', 'status': 'Premium', 'role': 'User'},
      {'name': 'Emma Wilson', 'email': 'emma.w@example.com', 'status': 'Active', 'role': 'User'},
      {'name': 'Mike Johnson', 'email': 'mike.j@example.com', 'status': 'Inactive', 'role': 'User'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage Users',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...List.generate(users.length, (index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFF4D97),
                  child: Text(
                    user['name']!.substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user['name']!),
                subtitle: Text(user['email']!),
                trailing: Chip(
                  label: Text(user['status']!),
                  backgroundColor: user['status'] == 'Active'
                      ? Colors.green[100]
                      : user['status'] == 'Premium'
                          ? const Color(0xFFFF4D97).withOpacity(0.2)
                          : Colors.grey[200],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics & Reports',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Active Users',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BarChart(label: 'Mon', value: 120),
                    _BarChart(label: 'Tue', value: 150),
                    _BarChart(label: 'Wed', value: 180),
                    _BarChart(label: 'Thu', value: 140),
                    _BarChart(label: 'Fri', value: 200),
                    _BarChart(label: 'Sat', value: 170),
                    _BarChart(label: 'Sun', value: 190),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Features Used',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _FeatureStat(label: 'Face Scan', percentage: 85),
                const SizedBox(height: 8),
                _FeatureStat(label: 'Makeup Tutorial', percentage: 72),
                const SizedBox(height: 8),
                _FeatureStat(label: 'Product Marketplace', percentage: 58),
                const SizedBox(height: 8),
                _FeatureStat(label: 'Premium Subscription', percentage: 45),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.notifications, color: Color(0xFFFF4D97)),
            title: const Text('Push Notifications'),
            subtitle: const Text('Manage notification settings'),
            trailing: Switch(
              value: true,
              onChanged: (value) {},
              activeColor: const Color(0xFFFF4D97),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security, color: Color(0xFFFF4D97)),
            title: const Text('Two-Factor Auth'),
            subtitle: const Text('Enhance account security'),
            trailing: Switch(
              value: false,
              onChanged: (value) {},
              activeColor: const Color(0xFFFF4D97),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup, color: Color(0xFFFF4D97)),
            title: const Text('Backup Data'),
            subtitle: const Text('Last backup: Today'),
            trailing: const Icon(Icons.arrow_forward),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4D97)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final String label;
  final int value;

  const _BarChart({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 24,
          height: (value / 2).toDouble(),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D97),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _FeatureStat extends StatelessWidget {
  final String label;
  final int percentage;

  const _FeatureStat({required this.label, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('$percentage%', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4D97)),
          ),
        ),
      ],
    );
  }
}
