// lib/widgets/notification_bell.dart
//
// Animated bell icon with unread badge + tap-to-open notification center.

import 'package:flutter/material.dart';

import '../services/notification_service.dart';

const Color _kPink = Color(0xFFFF4D97);
const Color _kPinkDeep = Color(0xFFCC3A7A);

class NotificationBell extends StatefulWidget {
  final Color iconColor;
  final double iconSize;
  const NotificationBell({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 24,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    NotificationService.instance.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _shake.forward(from: 0);
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onChange);
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = NotificationService.instance.unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              // Quick triple wiggle then settle.
              final angle =
                  t == 0 ? 0.0 : 0.35 * (1 - t) * (t < 0.5 ? -1 : 1);
              return Transform.rotate(angle: angle, child: child);
            },
            child: Icon(
              count > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: widget.iconColor,
              size: widget.iconSize,
            ),
          ),
          onPressed: () => showNotificationSheet(context),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3D71), _kPinkDeep],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _kPink.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showNotificationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NotificationSheet(),
  );
}

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService.instance;
    final items = svc.items;
    final size = MediaQuery.of(context).size;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF9FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kPink, _kPinkDeep],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _kPink.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1D2E),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            svc.unreadCount > 0
                                ? '${svc.unreadCount} unread • ${items.length} total'
                                : items.isEmpty
                                    ? 'You\'re all caught up ✨'
                                    : '${items.length} total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty) ...[
                      _IconAction(
                        icon: Icons.done_all_rounded,
                        tooltip: 'Mark all read',
                        onTap: () {
                          svc.markAllRead();
                        },
                      ),
                      const SizedBox(width: 4),
                      _IconAction(
                        icon: Icons.delete_sweep_rounded,
                        tooltip: 'Clear all',
                        onTap: () {
                          svc.clear();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              // List
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(maxHeight: size.height * 0.5)
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final n = items[index];
                          return _NotificationCard(
                            notification: n,
                            onTap: () {
                              svc.markRead(n.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: _kPinkDeep),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(notification.type);
    final icon = _iconFor(notification.type);
    final label = _labelFor(notification.type);
    final unread = !notification.read;

    return Material(
      color: unread ? Colors.white : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      elevation: unread ? 1 : 0,
      shadowColor: accent.withOpacity(0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread ? accent.withOpacity(0.25) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.18), accent.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _timeAgo(notification.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.order:
        return const Color(0xFF22C55E);
      case AppNotificationType.lowStock:
        return const Color(0xFFFF9800);
      case AppNotificationType.message:
        return _kPink;
    }
  }

  IconData _iconFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.order:
        return Icons.shopping_bag_rounded;
      case AppNotificationType.lowStock:
        return Icons.inventory_2_rounded;
      case AppNotificationType.message:
        return Icons.chat_bubble_rounded;
    }
  }

  String _labelFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.order:
        return 'NEW ORDER';
      case AppNotificationType.lowStock:
        return 'STOCK';
      case AppNotificationType.message:
        return 'MESSAGE';
    }
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }
}

class _EmptyState extends StatelessWidget {
  final double maxHeight;
  const _EmptyState({required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_kPink.withOpacity(0.15), _kPink.withOpacity(0.05)],
                ),
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: _kPink,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New orders, low-stock alerts, and customer messages will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
