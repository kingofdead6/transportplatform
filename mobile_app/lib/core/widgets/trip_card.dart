import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

/// Trip summary card: soft-shadow surface, colored left stripe for status at a glance,
/// origin -> destination as the headline, reference/weight/price as supporting detail.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap, this.trailingPrice});

  final Trip trip;
  final VoidCallback? onTap;
  final String? trailingPrice;

  @override
  Widget build(BuildContext context) {
    final stripeColor = AppColors.statusColor(trip.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppTheme.radiusMd)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${trip.pickup.wilaya ?? '-'}  →  ${trip.dropoff.wilaya ?? '-'}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: trip.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              trip.reference,
                              style: const TextStyle(color: AppColors.acier, fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                            if (trip.weightKg != null) ...[
                              const SizedBox(width: 8),
                              Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.acier, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(
                                '${trip.weightKg!.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                  fontFamily: 'ArchivoCondensed',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.acier,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (trailingPrice != null)
                              Text(
                                trailingPrice!,
                                style: const TextStyle(
                                  fontFamily: 'ArchivoCondensed',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.bitume,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.acier.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
