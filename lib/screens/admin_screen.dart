// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
    if (kIsWeb) {
      return const _AdminWebShell();
    }

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

class _AdminWebShell extends StatelessWidget {
  const _AdminWebShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Row(
          children: [
            const _WebSidebar(),
            Expanded(
              child: Column(
                children: [
                  const _WebTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _WebKpiGrid(),
                          SizedBox(height: 24),
                          _WebAccountsAndSubscriptions(),
                          SizedBox(height: 24),
                          _WebGainsAndAuditLogs(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebSidebar extends StatelessWidget {
  const _WebSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'FaceTune Beauty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Admin Console',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 24),
          _WebNavItem(icon: Icons.dashboard_outlined, label: 'Overview', isActive: true),
          _WebNavItem(icon: Icons.people_outline, label: 'Accounts'),
          _WebNavItem(icon: Icons.card_membership_outlined, label: 'Subscriptions'),
           _WebNavItem(icon: Icons.attach_money_outlined, label: 'Profit'),
          _WebNavItem(icon: Icons.receipt_long_outlined, label: 'Audit Logs'),
          _WebNavItem(icon: Icons.settings_outlined, label: 'Settings'),
        ],
      ),
    );
  }
}

class _WebNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _WebNavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFF4D97).withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isActive ? const Color(0xFFFF4D97) : Colors.grey[700]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? const Color(0xFFFF4D97) : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebTopBar extends StatelessWidget {
  const _WebTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6E8F0))),
      ),
      child: Row(
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Search users, subscriptions, audits…',
                filled: true,
                fillColor: const Color(0xFFF3F4F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFF4D97),
            child: const Text('A', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _WebKpiGrid extends StatelessWidget {
  const _WebKpiGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: const [
        _WebKpiCard(title: 'Total Accounts', value: '12,482', delta: '+4.2%'),
        _WebKpiCard(title: 'Active Subscriptions', value: '3,128', delta: '+2.1%'),
        _WebKpiCard(title: 'Monthly Profit', value: '£24,560', delta: '+6.8%'),
        _WebKpiCard(title: 'Churn Rate', value: '1.8%', delta: '-0.3%'),
      ],
    );
  }
}

class _WebKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String delta;

  const _WebKpiCard({
    required this.title,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(delta, style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
        ],
      ),
    );
  }
}

class _WebAccountsAndSubscriptions extends StatelessWidget {
  const _WebAccountsAndSubscriptions();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(child: _WebAccountsTable()),
        SizedBox(width: 16),
        Expanded(child: _WebSubscriptionsCard()),
      ],
    );
  }
}

class _WebAccountsTable extends StatelessWidget {
  const _WebAccountsTable();

  @override
  Widget build(BuildContext context) {
    return _WebSection(
      title: 'Accounts',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Plan')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Last Active')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('Sarah M.')),
              DataCell(Text('sarah.m@example.com')),
              DataCell(Text('Premium')),
              DataCell(Text('Active')),
              DataCell(Text('2m ago')),
            ]),
            DataRow(cells: [
              DataCell(Text('John Doe')),
              DataCell(Text('john.doe@example.com')),
              DataCell(Text('Pro')),
              DataCell(Text('Active')),
              DataCell(Text('12m ago')),
            ]),
            DataRow(cells: [
              DataCell(Text('Emma W.')),
              DataCell(Text('emma.w@example.com')),
              DataCell(Text('Free')),
              DataCell(Text('Trial')),
              DataCell(Text('1h ago')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _WebSubscriptionsCard extends StatelessWidget {
  const _WebSubscriptionsCard();

  @override
  Widget build(BuildContext context) {
    return _WebSection(
      title: 'Subscriptions',
      child: Column(
        children: const [
          _SubscriptionRow(label: 'Premium', value: '1,204', color: Color(0xFFFF4D97)),
          _SubscriptionRow(label: 'Pro', value: '812', color: Color(0xFF6366F1)),
          _SubscriptionRow(label: 'Trial', value: '356', color: Color(0xFF22C55E)),
          _SubscriptionRow(label: 'Expired', value: '102', color: Color(0xFFF97316)),
        ],
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SubscriptionRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WebGainsAndAuditLogs extends StatelessWidget {
  const _WebGainsAndAuditLogs();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(child: _WebGainsCard()),
        SizedBox(width: 16),
        Expanded(child: _WebAuditLog()),
      ],
    );
  }
}

class _WebGainsCard extends StatelessWidget {
  const _WebGainsCard();

  @override
  Widget build(BuildContext context) {
    return _WebSection(
       title: 'Profit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
               const Text('Monthly Profit', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _GainChip(label: 'Subscriptions', value: ' 18,240'),
              _GainChip(label: 'Add-ons', value: ' 4,320'),
              _GainChip(label: 'Marketplace', value: ' 1,980'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _MiniBar(label: 'W1', value: 60),
                _MiniBar(label: 'W2', value: 80),
                _MiniBar(label: 'W3', value: 70),
                _MiniBar(label: 'W4', value: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GainChip extends StatelessWidget {
  final String label;
  final String value;

  const _GainChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;

  const _MiniBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: value,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D97),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _WebAuditLog extends StatelessWidget {
  const _WebAuditLog();

  @override
  Widget build(BuildContext context) {
    return _WebSection(
      title: 'Audit Logs',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Actor')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Target')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('10:12 AM')),
              DataCell(Text('admin@facetune.com')),
              DataCell(Text('Updated plan')),
              DataCell(Text('john.doe@example.com')),
            ]),
            DataRow(cells: [
              DataCell(Text('9:44 AM')),
              DataCell(Text('admin@facetune.com')),
              DataCell(Text('Refund issued')),
              DataCell(Text('emma.w@example.com')),
            ]),
            DataRow(cells: [
              DataCell(Text('Yesterday')),
              DataCell(Text('system')),
              DataCell(Text('Subscription expired')),
              DataCell(Text('mike.j@example.com')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _WebSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _WebSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
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
              activeThumbColor: const Color(0xFFFF4D97),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security, color: Color(0xFFFF4D97)),
            title: const Text('Two-Factor Auth'),
            subtitle: const Text('Enhance account security'),
            trailing: Switch(
              value: false,
              onChanged: (value) {},
              activeThumbColor: const Color(0xFFFF4D97),
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
