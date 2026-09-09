import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/trip_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/trip_card.dart';
import 'trip_detail_screen.dart';

/// Trips already assigned to this carrier (any status), section 5.2 "رحلاتي".
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final _tripService = TripService();
  late Future<List<Trip>> _future;

  @override
  void initState() {
    super.initState();
    _future = _tripService.listTrips(query: {'mine': 'true'});
  }

  Future<void> _refresh() async {
    setState(() => _future = _tripService.listTrips(query: {'mine': 'true'}));
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
          if (trips.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                EmptyState(message: tr(context, 'no_trips_assigned')),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final trip = trips[i];
              return TripCard(
                trip: trip,
                trailingPrice: trip.agreedPrice != null
                    ? '${trip.agreedPrice!.toStringAsFixed(0)} DA'
                    : null,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
                  );
                  _refresh();
                },
              );
            },
          );
        },
      ),
    );
  }
}
