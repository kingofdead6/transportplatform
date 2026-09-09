import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/trip_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/trip_card.dart';
import 'trip_detail_screen.dart';
import 'return_loads_screen.dart';

/// Section 5.2 "لوحة الحمولات": open published loads filtered server-side to
/// the carrier's operating wilayas. Also surfaces the return-load suggestions
/// section (6.2) via a callout entry point.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _tripService = TripService();
  late Future<List<Trip>> _future;

  @override
  void initState() {
    super.initState();
    _future = _tripService.listTrips();
  }

  Future<void> _refresh() async {
    setState(() => _future = _tripService.listTrips());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.replay_circle_filled_outlined),
                  title: Text(tr(context, 'return_loads')),
                  subtitle: Text(
                    tr(context, 'return_loads_banner'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReturnLoadsScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (trips.isEmpty)
                EmptyState(message: tr(context, 'no_loads_available'))
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
    );
  }
}
