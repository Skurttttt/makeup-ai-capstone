// lib/screens/subscription_tab.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SubscriptionTab extends StatefulWidget {
  const SubscriptionTab({super.key});

  @override
  State<SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<SubscriptionTab> {
  final _supabaseService = SupabaseService();
  Map<String, dynamic>? _selectedPlan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Premium Plans',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: _selectedPlan != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _selectedPlan = null;
                  });
                },
              )
            : null,
      ),
      body: _selectedPlan == null ? _buildPlansList() : _buildPlanDetails(),
    );
  }

  Widget _buildPlansList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getAllPlans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D97)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading plans: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return const Center(
            child: Text('No subscription plans available', style: TextStyle(color: Colors.black54)),
          );
        }

        // Filter out inactive plans and free plan
        final activePlans = plans.where((plan) => 
          (plan['is_active'] == true) && 
          (plan['name']?.toString().toLowerCase() != 'free')
        ).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D97), Color(0xFFFF8DC7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, size: 50, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text(
                      'Choose Your Plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upgrade to unlock premium features',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Plan Cards
              ...activePlans.map((plan) => _buildPlanCard(plan)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planName = plan['display_name'] ?? plan['name'] ?? 'N/A';
    final price = plan['price'] ?? 0;
    final billingPeriod = plan['billing_period'] ?? '';
    final description = plan['description'] ?? '';
    final isPremium = planName.toLowerCase().contains('premium');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? Colors.transparent : const Color(0xFFFF4D97),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? Colors.orange : const Color(0xFFFF4D97)).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPlan = plan;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isPremium ? Colors.white : const Color(0xFFFF4D97),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isPremium ? Colors.white.withOpacity(0.9) : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: isPremium ? Colors.white : const Color(0xFFFF4D97),
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isPremium ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/$billingPeriod',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPremium ? Colors.white.withOpacity(0.8) : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanDetails() {
    if (_selectedPlan == null) return const SizedBox();

    final planName = _selectedPlan!['display_name'] ?? _selectedPlan!['name'] ?? 'N/A';
    final price = _selectedPlan!['price'] ?? 0;
    final billingPeriod = _selectedPlan!['billing_period'] ?? '';
    final description = _selectedPlan!['description'] ?? '';
    final dailyScans = _selectedPlan!['daily_scan_limit'] ?? 0;
    final availableLooks = _selectedPlan!['available_looks'] ?? 0;
    final canSave = _selectedPlan!['can_save_results'] ?? false;
    final canExportHd = _selectedPlan!['can_export_hd'] ?? false;
    final removeWatermark = _selectedPlan!['remove_watermark'] ?? false;
    final isPremium = planName.toLowerCase().contains('premium');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isPremium
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFF4D97), Color(0xFFFF8DC7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  isPremium ? Icons.workspace_premium : Icons.star,
                  size: 50,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  planName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '/$billingPeriod',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Features List
          const Text(
            'What\'s Included',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            icon: Icons.camera_alt,
            title: 'Daily Scans',
            value: dailyScans == -1 ? 'Unlimited' : '$dailyScans scans/day',
            included: true,
          ),
          _buildFeatureItem(
            icon: Icons.face_retouching_natural,
            title: 'Makeup Looks',
            value: availableLooks == -1 ? 'All looks' : '$availableLooks looks',
            included: true,
          ),
          _buildFeatureItem(
            icon: Icons.save,
            title: 'Save Results',
            value: canSave ? 'Yes' : 'No',
            included: canSave,
          ),
          _buildFeatureItem(
            icon: Icons.high_quality,
            title: 'HD Export',
            value: canExportHd ? 'Yes' : 'No',
            included: canExportHd,
          ),
          _buildFeatureItem(
            icon: Icons.check_circle,
            title: 'Remove Watermark',
            value: removeWatermark ? 'Yes' : 'No',
            included: removeWatermark,
          ),

          const SizedBox(height: 20),

          // Subscribe Button
          ElevatedButton(
            onPressed: () => _showSubscribeConfirmation(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.orange : const Color(0xFFFF4D97),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: Text(
              'Subscribe to $planName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String value,
    required bool included,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: included ? const Color(0xFFFF4D97).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: included ? const Color(0xFFFF4D97) : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: included ? const Color(0xFFFF4D97) : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            included ? Icons.check_circle : Icons.cancel,
            color: included ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showSubscribeConfirmation() {
    if (_selectedPlan == null) return;

    final planName = _selectedPlan!['display_name'] ?? _selectedPlan!['name'] ?? 'N/A';
    final price = _selectedPlan!['price'] ?? 0;
    final billingPeriod = _selectedPlan!['billing_period'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Subscribe to $planName',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan: $planName',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ₱${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF4D97),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Billing: $billingPeriod',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will activate your subscription. You can cancel anytime.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
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
              Navigator.pop(context);

              try {
                // Get current user
                final currentUser = _supabaseService.client.auth.currentUser;
                if (currentUser == null) {
                  throw 'User not logged in';
                }

                // Calculate end date based on billing period
                DateTime endDate;
                final period = billingPeriod.toLowerCase();
                if (period.contains('day')) {
                  endDate = DateTime.now().add(const Duration(days: 1));
                } else if (period.contains('week')) {
                  endDate = DateTime.now().add(const Duration(days: 7));
                } else if (period.contains('month')) {
                  endDate = DateTime.now().add(const Duration(days: 30));
                } else if (period.contains('year')) {
                  endDate = DateTime.now().add(const Duration(days: 365));
                } else if (period.contains('lifetime')) {
                  endDate = DateTime.now().add(const Duration(days: 36500));
                } else {
                  endDate = DateTime.now().add(const Duration(days: 30));
                }

                // Create the subscription in database
                await _supabaseService.createUserSubscription(
                  accountId: currentUser.id,
                  planId: _selectedPlan!['id'],
                  status: 'active',
                  currentPeriodEnd: endDate,
                  amountPaid: price.toDouble(),
                );

                // Log subscription purchase for audit
                await _supabaseService.logAdminAction(
                  action: 'subscription_purchase',
                  target: 'subscription',
                  metadata: {
                    'plan_name': planName,
                    'price': price,
                    'billing_period': billingPeriod,
                    'purchase_time': DateTime.now().toIso8601String(),
                    'end_date': endDate.toIso8601String(),
                  },
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$planName subscription activated! 🎉'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {
                    _selectedPlan = null;
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to activate subscription: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Subscribe', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
