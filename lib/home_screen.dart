import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_tab.dart';
import 'screens/scan_tab.dart';
import 'screens/market_tab.dart';
import 'screens/subscription_tab.dart';
import 'screens/settings_tab.dart';
import 'screens/buyer_orders_screen.dart';
import 'services/notification_service.dart';
import 'services/scan_quota_service.dart'; // ADDED THIS IMPORT
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  bool _scanDisabled = false;
  StreamSubscription<AppNotification>? _notifSub;

  final List<Widget> _tabs = const [
    HomeTab(),
    ScanTab(),
    MarketTab(),
    BuyerOrdersScreen(),
    SubscriptionTab(),
    SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _checkScanAvailability();

    final uid = Supabase.instance.client.auth.currentUser?.id;

    if (uid != null) {
      NotificationService.instance.startForBuyer(uid);
    }
    _notifSub = NotificationService.instance.onNewNotification.listen(_pingBuyer);
  }

  Future<void> _checkScanAvailability() async {
    final usage = await ScanQuotaService.instance.getUsage();

    if (!mounted) return;

    setState(() {
      _scanDisabled = !usage.hasRemaining;
    });
  }

  Future<void> _handleTabTap(int index) async {
    const int scanIndex = 1;

    if (index == scanIndex) {
      final usage = await ScanQuotaService.instance.getUsage();

      if (!usage.hasRemaining) {
        if (!mounted) return;

        final next = usage.nextResetAt;

        await showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text(
                'Daily Scan Limit Reached',
              ),
              content: Text(
                'You have reached your '
                '${usage.dailyLimit} free scans for today.\n\n'
                'Next scan available:\n'
                '${next.month}/${next.day}/${next.year}',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Okay'),
                ),
              ],
            );
          },
        );

        await _checkScanAvailability();

        return;
      }
    }

    setState(() {
      _currentIndex = index;
    });

    await _checkScanAvailability();
  }

  void _pingBuyer(AppNotification n) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final color = switch (n.type) {
        AppNotificationType.order   => const Color(0xFF22C55E),
        AppNotificationType.lowStock => const Color(0xFFFF9800),
        AppNotificationType.message  => const Color(0xFFFF4D97),
      };
      final icon = switch (n.type) {
        AppNotificationType.order   => Icons.shopping_bag_rounded,
        AppNotificationType.lowStock => Icons.inventory_2_rounded,
        AppNotificationType.message  => Icons.chat_bubble_rounded,
      };
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(n.body,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ));
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    NotificationService.instance.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),

      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,

        height: 68,

        backgroundColor: Colors.white,

        indicatorColor: const Color(0xFFFF4D97).withOpacity(0.12),

        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,

        onDestinationSelected: _handleTabTap,

        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.face_retouching_natural_outlined,
              color: _scanDisabled ? Colors.grey : null,
            ),
            selectedIcon: Icon(
              Icons.face_retouching_natural,
              color: _scanDisabled ? Colors.grey : null,
            ),
            label: 'Scan',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.shopping_bag_outlined,
            ),
            selectedIcon: Icon(
              Icons.shopping_bag,
            ),
            label: 'Market',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon: Icon(
              Icons.receipt_long,
            ),
            label: 'Orders',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.workspace_premium_outlined,
            ),
            selectedIcon: Icon(
              Icons.workspace_premium,
            ),
            label: 'Premium',
          ),

          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}