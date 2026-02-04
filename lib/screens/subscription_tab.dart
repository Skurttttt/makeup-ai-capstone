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
  String? _selectedPlanType; // 'pro' or 'premium'
  String? _selectedDuration;

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
        leading: _selectedPlanType != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _selectedPlanType = null;
                    _selectedDuration = null;
                  });
                },
              )
            : null,
      ),
      body: _selectedPlanType == null
          ? _buildComparisonView()
          : _buildDurationSelection(),
    );
  }

  Widget _buildComparisonView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
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
                const Icon(Icons.workspace_premium, size: 60, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'Choose Your Plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compare features and pick what\'s right for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Plan Comparison Table
          const Text(
            'Feature Comparison',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Comparison Cards
          _buildComparisonCard(
            'Daily Scans',
            free: '3 scans/day',
            pro: 'Unlimited',
            premium: 'Unlimited',
            icon: Icons.camera_alt,
          ),
          _buildComparisonCard(
            'Makeup Looks',
            free: '1 look',
            pro: '3 looks',
            premium: 'All 5 looks',
            icon: Icons.face_retouching_natural,
          ),
          _buildComparisonCard(
            'Save Results',
            free: '✗',
            pro: '✓',
            premium: '✓',
            icon: Icons.save,
          ),
          _buildComparisonCard(
            'HD Export',
            free: '✗',
            pro: '✗',
            premium: '✓',
            icon: Icons.high_quality,
          ),
          _buildComparisonCard(
            'Remove Watermark',
            free: '✗',
            pro: '✓',
            premium: '✓',
            icon: Icons.check_circle,
          ),

          const SizedBox(height: 32),

          // Action Buttons
          const Text(
            'Select Your Plan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Pro Button
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedPlanType = 'pro';
                _selectedDuration = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D97),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get Pro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Starting at ₱199/week',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Premium Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedPlanType = 'premium';
                  _selectedDuration = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Get Premium',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'BEST VALUE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Starting at ₱299/week',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Cancel anytime. No commitment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    String feature, {
    required String free,
    required String pro,
    required String premium,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D97).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFFF4D97)),
              ),
              const SizedBox(width: 12),
              Text(
                feature,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Free',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      free,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: free == '✗' ? Colors.red : Colors.grey[800],
                        fontWeight: free == '✓' || free == '✗' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF4D97),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pro,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: pro == '✗' ? Colors.red : const Color(0xFFFF4D97),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF8C00),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      premium,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFF8C00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _selectedPlanType == 'premium'
                    ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                    : [const Color(0xFFFF4D97), const Color(0xFFFF8DC7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedPlanType == 'pro' ? 'FaceTune Pro' : 'FaceTune Premium',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Duration Title
          const Text(
            'Choose Your Duration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a billing period that works best for you',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Duration Options
          _buildDurationOptions(),

          const SizedBox(height: 32),

          // Continue Button
          ElevatedButton(
            onPressed: _selectedDuration != null
                ? () {
                    _showSubscribeDialog(context);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedPlanType == 'premium'
                  ? const Color(0xFFFF8C00)
                  : const Color(0xFFFF4D97),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continue to Payment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cancel anytime. Terms and conditions apply.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationOptions() {
    List<Map<String, String>> durations = [];

    // Pro plan
    if (_selectedPlanType == 'pro') {
      durations = [
        {'label': '1 Week', 'value': 'week', 'price': '₱199'},
        {'label': '1 Month', 'value': 'month', 'price': '₱499'},
        {'label': '3 Months', 'value': 'quarter', 'price': '₱1,299'},
      ];
    }
    // Premium plan
    else if (_selectedPlanType == 'premium') {
      durations = [
        {'label': '1 Week Trial', 'value': 'week', 'price': '₱299'},
        {'label': '1 Month', 'value': 'month', 'price': '₱2,499'},
        {'label': '1 Year', 'value': 'year', 'price': '₱4,999'},
      ];
    }

    return Column(
      children: durations.map((duration) {
        final isSelected = _selectedDuration == duration['value'];
        return Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDuration = duration['value'];
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (_selectedPlanType == 'premium' 
                          ? const Color(0xFFFF8C00).withOpacity(0.1) 
                          : const Color(0xFFFF4D97).withOpacity(0.1))
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? (_selectedPlanType == 'premium' 
                            ? const Color(0xFFFF8C00) 
                            : const Color(0xFFFF4D97))
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected 
                              ? (_selectedPlanType == 'premium' 
                                  ? const Color(0xFFFF8C00) 
                                  : const Color(0xFFFF4D97))
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Icon(
                                Icons.check, 
                                size: 16, 
                                color: _selectedPlanType == 'premium' 
                                    ? const Color(0xFFFF8C00) 
                                    : const Color(0xFFFF4D97),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            duration['label']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      duration['price']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _selectedPlanType == 'premium' 
                            ? const Color(0xFFFF8C00) 
                            : const Color(0xFFFF4D97),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  void _showSubscribeDialog(BuildContext context) {
    final planName = _selectedPlanType == 'pro' ? 'FaceTune Pro' : 'FaceTune Premium';
    
    // Find the price based on duration
    String price = '₱0';
    if (_selectedPlanType == 'pro') {
      if (_selectedDuration == 'week') price = '₱199';
      if (_selectedDuration == 'month') price = '₱499';
      if (_selectedDuration == 'quarter') price = '₱1,299';
    } else if (_selectedPlanType == 'premium') {
      if (_selectedDuration == 'week') price = '₱299';
      if (_selectedDuration == 'month') price = '₱2,499';
      if (_selectedDuration == 'year') price = '₱4,999';
    }
    
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
              'Duration: $_selectedDuration',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: $price',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _selectedPlanType == 'premium' 
                    ? const Color(0xFFFF8C00) 
                    : const Color(0xFFFF4D97),
              ),
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$planName subscription activated! 🎉'),
                  backgroundColor: _selectedPlanType == 'premium' 
                      ? const Color(0xFFFF8C00) 
                      : const Color(0xFFFF4D97),
                ),
              );
              setState(() {
                _selectedPlanType = null;
                _selectedDuration = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedPlanType == 'premium' 
                  ? const Color(0xFFFF8C00) 
                  : const Color(0xFFFF4D97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}
