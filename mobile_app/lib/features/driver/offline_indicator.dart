import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/offline_queue.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Section 5.3/CHA-12: purely informational chip — actions already queued and will
/// auto-send on reconnect (TripService/OfflineQueue handle that). Not blocking.
///
/// Watches the queue so the count updates as actions are queued and drained; it
/// previously read the count once and never refreshed.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<OfflineQueue>().pendingCount;
    if (pending <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.halte.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppColors.halte.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.halte),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tr(context, 'no_network')} ($pending ${tr(context, 'pending_sync')})',
              style: const TextStyle(
                color: AppColors.halte,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
