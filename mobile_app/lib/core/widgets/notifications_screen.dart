import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// The notification centre (section 6.5). Reachable from every role's home via
/// the bell in the app bar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'notifications')),
        actions: [
          if (service.unreadCount > 0)
            TextButton(
              onPressed: service.markAllRead,
              child: Text(tr(context, 'mark_all_read')),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: service.load,
        child: _buildBody(context, service),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationService service) {
    if (service.isLoading && service.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (service.error != null && service.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(message: service.error!, icon: Icons.error_outline),
        ],
      );
    }
    if (service.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            message: tr(context, 'notifications_empty'),
            icon: Icons.notifications_none_rounded,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: service.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final n = service.items[i];
        return _NotificationTile(
          notification: n,
          onTap: () => service.markRead(n.id),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  static const _icons = {
    'new_offer': Icons.local_offer_outlined,
    'trip_assigned': Icons.assignment_turned_in_outlined,
    'loaded': Icons.inventory_2_outlined,
    'delivered': Icons.check_circle_outline,
    'delay': Icons.warning_amber_rounded,
    'document_expiring': Icons.event_busy_outlined,
    'payment_due': Icons.receipt_long_outlined,
    'return_load_available': Icons.replay_circle_filled_outlined,
    'dispute_update': Icons.gavel_outlined,
    'account_status': Icons.badge_outlined,
    'message': Icons.chat_bubble_outline,
  };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final accent = notification.isCritical ? AppColors.halte : AppColors.sangle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
            border: unread ? Border.all(color: accent.withValues(alpha: 0.35)) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  _icons[notification.type] ?? Icons.notifications_none_rounded,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title ?? tr(context, 'notifications'),
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    if ((notification.body ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body!,
                        style: const TextStyle(color: AppColors.acier, fontSize: 13, height: 1.35),
                      ),
                    ],
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _relative(context, notification.createdAt!),
                        style: const TextStyle(color: AppColors.acier, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _relative(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return tr(context, 'just_now');
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return '${diff.inHours} h';
    if (diff.inDays < 30) return '${diff.inDays} j';
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// App-bar bell with an unread badge.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<NotificationService>().unreadCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: tr(context, 'notifications'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.halte,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
