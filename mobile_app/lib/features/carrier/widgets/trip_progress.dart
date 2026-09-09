import 'package:flutter/material.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/trip.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';

/// Read-only vertical stepper over tripLifecycleOrder: past = green check,
/// current = highlighted (sangle), future = grey. Used on carrier trip detail
/// once a trip is beyond 'assigned' (assignment happens via a dedicated form).
class TripProgress extends StatelessWidget {
  const TripProgress({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final currentIndex = tripLifecycleOrder.indexOf(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'progress'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        ...List.generate(tripLifecycleOrder.length, (i) {
          final step = tripLifecycleOrder[i];
          final isPast = currentIndex >= 0 && i < currentIndex;
          final isCurrent = i == currentIndex;
          final color = isPast
              ? AppColors.convoi
              : isCurrent
                  ? AppColors.sangle
                  : AppColors.acier.withValues(alpha: 0.4);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    isPast ? Icons.check_circle : Icons.circle,
                    size: 16,
                    color: color,
                  ),
                  if (i != tripLifecycleOrder.length - 1)
                    Container(width: 2, height: 22, color: color.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  step,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent ? AppColors.bitume : AppColors.acier,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// Small header row combining a StatusBadge with the current status label.
class TripStatusHeader extends StatelessWidget {
  const TripStatusHeader({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(tr(context, 'trip_details'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        StatusBadge(status: status),
      ],
    );
  }
}
