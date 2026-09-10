import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/trip_card.dart';
import 'trip_detail_screen.dart';

/// Section 6.2 "حمولة العودة": loads suggested near the carrier's last dropoff.
class ReturnLoadsScreen extends StatefulWidget {
  const ReturnLoadsScreen({super.key});

  @override
  State<ReturnLoadsScreen> createState() => _ReturnLoadsScreenState();
}

class _ReturnLoadsScreenState extends State<ReturnLoadsScreen> {
  late Future<List<Trip>> _future;

  @override
  void initState() {
    super.initState();
    _future = TripService().getReturnLoads();
  }

  Future<void> _refresh() async {
    setState(() => _future = TripService().getReturnLoads());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'return_loads'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Trip>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(message: '${snapshot.error}', icon: Icons.error_outline),
                ],
              );
            }
            final trips = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.sangle.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.sangle.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.sangle, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(tr(context, 'return_loads_banner'), style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (trips.isEmpty)
                  EmptyState(message: tr(context, 'no_return_loads'))
                else
                  ...trips.map(
                    (trip) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TripCard(
                        trip: trip,
                        trailingPrice: trip.pricingMode == 'fixed' && trip.fixedPrice != null
                            ? '${trip.fixedPrice!.toStringAsFixed(0)} DA'
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
