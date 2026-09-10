import 'package:flutter/material.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/trip.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Simple horizontal-free stepper over tripLifecycleOrder: past steps get a
/// convoi check, current step is highlighted sangle, future steps are acier/grey.
/// Exception states (cancelled/disputed/suspended) render as a single halte badge.
class TripTimeline extends StatelessWidget {
  const TripTimeline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (!tripLifecycleOrder.contains(status)) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.halte.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Text(
          tr(context, 'status_$status'),
          style: const TextStyle(color: AppColors.halte, fontWeight: FontWeight.w700),
        ),
      );
    }

    final currentIndex = tripLifecycleOrder.indexOf(status);

    return Column(
      children: [
        for (int i = 0; i < tripLifecycleOrder.length; i++)
          _StepRow(
            label: tr(context, 'status_${tripLifecycleOrder[i]}'),
            state: i < currentIndex
                ? _StepState.past
                : i == currentIndex
                    ? _StepState.current
                    : _StepState.future,
            isLast: i == tripLifecycleOrder.length - 1,
          ),
      ],
    );
  }
}

enum _StepState { past, current, future }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state, required this.isLast});
  final String label;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Widget icon;
    switch (state) {
      case _StepState.past:
        color = AppColors.convoi;
        icon = const Icon(Icons.check_circle, size: 18, color: AppColors.convoi);
        break;
      case _StepState.current:
        color = AppColors.sangle;
        icon = const Icon(Icons.radio_button_checked, size: 18, color: AppColors.sangle);
        break;
      case _StepState.future:
        color = AppColors.acier;
        icon = const Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.acier);
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            icon,
            if (!isLast) Container(width: 2, height: 20, color: color.withValues(alpha: 0.4)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                color: state == _StepState.future ? AppColors.acier : AppColors.bitume,
                fontWeight: state == _StepState.current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
