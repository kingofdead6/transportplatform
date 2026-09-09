import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/trip_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/trip_card.dart';

/// Secondary/low-priority screen (section 5.3 spec item 6): a simple list of
/// past missions (delivered/pod_confirmed/closed). Not part of the core flow.
class MissionHistoryScreen extends StatefulWidget {
  const MissionHistoryScreen({super.key});

  @override
  State<MissionHistoryScreen> createState() => _MissionHistoryScreenState();
}

class _MissionHistoryScreenState extends State<MissionHistoryScreen> {
  final _tripService = TripService();
  late Future<List<Trip>> _future;

  static const _pastStatuses = {'delivered', 'pod_confirmed', 'closed'};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Trip>> _load() async {
    final trips = await _tripService.listTrips();
    final past = trips.where((t) => _pastStatuses.contains(t.status)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return past;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'mission_history'))),
      body: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return EmptyState(message: tr(context, 'no_past_missions'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => TripCard(trip: trips[i]),
          );
        },
      ),
    );
  }
}
