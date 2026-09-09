import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Section 11.6: "mission stages are a vertical timeline with timestamps."
/// Completed stages show a check + timestamp, current stage is highlighted (Sangle),
/// future stages are greyed out. Purely presentational — driven by trip.status.
class MissionTimeline extends StatelessWidget {
  const MissionTimeline({super.key, required this.currentStatus, this.timestamps = const {}});

  /// Current trip.status value (a key from tripLifecycleOrder).
  final String currentStatus;

  /// Optional map of stage key -> DateTime, from trip.statusHistory if available.
  final Map<String, DateTime> timestamps;

  static const List<String> _stages = [
    'driver_assigned',
    'en_route_pickup',
    'loaded',
    'en_route_delivery',
    'arrived_delivery',
    'delivered',
  ];

  static const Map<String, String> _labelKeys = {
    'driver_assigned': 'timeline_assigned',
    'en_route_pickup': 'timeline_pickup_departed',
    'loaded': 'timeline_loaded',
    'en_route_delivery': 'timeline_en_route',
    'arrived_delivery': 'timeline_arrived',
    'delivered': 'timeline_delivered',
  };

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexOf(currentStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stages.length; i++)
          _TimelineRow(
            label: tr(context, _labelKeys[_stages[i]]!),
            timestamp: timestamps[_stages[i]],
            state: currentIndex < 0
                ? _StageState.future
                : i < currentIndex
                    ? _StageState.done
                    : i == currentIndex
                        ? _StageState.current
                        : _StageState.future,
            isLast: i == _stages.length - 1,
          ),
      ],
    );
  }
}

enum _StageState { done, current, future }

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.state,
    required this.isLast,
    this.timestamp,
  });

  final String label;
  final DateTime? timestamp;
  final _StageState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = switch (state) {
      _StageState.done => AppColors.convoi,
      _StageState.current => AppColors.sangle,
      _StageState.future => AppColors.acier.withValues(alpha: 0.35),
    };
    final Color textColor = switch (state) {
      _StageState.done => AppColors.bitume,
      _StageState.current => AppColors.bitume,
      _StageState.future => AppColors.acier,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: state == _StageState.future ? Colors.transparent : dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: state == _StageState.done
                    ? const Icon(Icons.check, size: 14, color: AppColors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: state == _StageState.done
                        ? AppColors.convoi
                        : AppColors.acier.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: state == _StageState.current ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      _formatTime(timestamp!),
                      style: const TextStyle(
                        fontFamily: 'ArchivoCondensed',
                        fontSize: 13,
                        color: AppColors.acier,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
