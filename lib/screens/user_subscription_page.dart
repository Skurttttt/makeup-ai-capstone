// lib/screens/user_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class UserSubscriptionPage extends StatefulWidget {
  const UserSubscriptionPage({super.key});

  @override
  State<UserSubscriptionPage> createState() => _UserSubscriptionPageState();
}

class _UserSubscriptionPageState extends State<UserSubscriptionPage> {
  final _supabaseService = SupabaseService();
  RealtimeChannel? _subscriptionChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final userId = _supabaseService.getCurrentUser()?.id;
    if (userId == null) return;

    _subscriptionChannel = _supabaseService.subscribeToSubscriptions(
      userId,
      onChange: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    final channel = _subscriptionChannel;
    if (channel != null) {
      _supabaseService.client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabaseService.getCurrentUser()?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Subscription')),
        body: const Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscription'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder(
        future: _supabaseService.getUserSubscriptions(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final subscriptions = snapshot.data ?? [];

          if (subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.card_membership_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Regular Plan (Free)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFFF4D97)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re currently on the free regular plan',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to subscription plans
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D97),
                    ),
                    child: const Text(
                      'Upgrade to Pro',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = subscriptions[index];
              final isActive = subscription['status'] == 'active';
              final periodEnd = subscription['current_period_end'] != null
                  ? DateTime.parse(subscription['current_period_end'])
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: isActive ? 4 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFFFF4D97) : Colors.grey[300]!,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    subscription['plan']?.toUpperCase() ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF4D97),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (subscription['plan'] == 'regular')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'FREE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green[100]
                                      : subscription['status'] == 'expired'
                                          ? Colors.red[100]
                                          : Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  subscription['status']?.toUpperCase() ?? 'UNKNOWN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Colors.green[700]
                                        : subscription['status'] == 'expired'
                                            ? Colors.red[700]
                                            : Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isActive)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 32,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSubscriptionDetail(
                              'Created',
                              DateFormat('MMM dd, yyyy').format(
                                DateTime.parse(subscription['created_at'] ?? ''),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (periodEnd != null)
                              _buildSubscriptionDetail(
                                'Renews on',
                                DateFormat('MMM dd, yyyy').format(periodEnd),
                              ),
                            const SizedBox(height: 8),
                            _buildSubscriptionDetail(
                              'Subscription ID',
                              subscription['id'].toString().substring(0, 8) + '...',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isActive)
                        ElevatedButton(
                          onPressed: () => _showManageDialog(subscription),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4D97),
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          child: const Text(
                            'Manage Subscription',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _showManageDialog(Map<String, dynamic> subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Change Plan'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(context);
                // Navigate to change plan
              },
            ),
            ListTile(
              title: const Text('View Invoice'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(context);
                // View invoice
              },
            ),
            ListTile(
              title: const Text('Cancel Subscription'),
              trailing: const Icon(Icons.arrow_forward),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showCancelConfirmation(subscription);
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

  void _showCancelConfirmation(Map<String, dynamic> subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Are you sure you want to cancel your subscription? You will lose access to premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabaseService.updateSubscription(
                subscriptionId: subscription['id'],
                updates: {'status': 'canceled'},
              );

              if (mounted) {
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Subscription cancelled')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Subscription', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
