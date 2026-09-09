import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import 'status_badge.dart';

/// Section 11.6 "bitaqat al-rihla": 4px left status stripe, origin -> destination on
/// one line with an arrow, load/vehicle as condensed numerals, price aligned to the trailing edge.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap, this.trailingPrice});

  final Trip trip;
  final VoidCallback? onTap;
  final String? trailingPrice;

  @override
  Widget build(BuildContext context) {
    final stripeColor = AppColors.statusColor(trip.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E6E8)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, decoration: BoxDecoration(color: stripeColor)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${trip.pickup.wilaya ?? '-'}  →  ${trip.dropoff.wilaya ?? '-'}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(status: trip.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            trip.reference,
                            style: const TextStyle(color: AppColors.acier, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          if (trip.weightKg != null)
                            Text(
                              '${trip.weightKg!.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontFamily: 'ArchivoCondensed',
                                fontWeight: FontWeight.w600,
                                color: AppColors.acier,
                                fontSize: 12,
                              ),
                            ),
                          const Spacer(),
                          if (trailingPrice != null)
                            Text(
                              trailingPrice!,
                              style: const TextStyle(
                                fontFamily: 'ArchivoCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
