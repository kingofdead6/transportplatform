import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/trip_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/trip_card.dart';
import 'create_trip_for_shipper_screen.dart';
import 'trip_detail_screen.dart';

/// Trips tab (Pilotage des routes, ADM-01..08): all trips, admin unrestricted.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _tripService = TripService();
  bool _loading = true;
  String? _error;
  List<Trip> _trips = const [];
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await _tripService.listTrips(
        query: _statusFilter != null ? {'status': _statusFilter} : null,
      );
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: tr(context, 'all_statuses'),
                    selected: _statusFilter == null,
                    onTap: () {
                      setState(() => _statusFilter = null);
                      _load();
                    },
                  ),
                  for (final status in tripLifecycleOrder)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: tr(context, 'status_$status'),
                        selected: _statusFilter == status,
                        onTap: () {
                          setState(() => _statusFilter = status);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 8),
                            OutlinedButton(onPressed: _load, child: Text(tr(context, 'retry'))),
                          ],
                        ),
                      )
                    : _trips.isEmpty
                        ? EmptyState(message: tr(context, 'no_trips_found'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _trips.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final trip = _trips[i];
                                return TripCard(
                                  trip: trip,
                                  trailingPrice: trip.agreedPrice != null
                                      ? '${trip.agreedPrice!.toStringAsFixed(0)} DA'
                                      : (trip.fixedPrice != null ? '${trip.fixedPrice!.toStringAsFixed(0)} DA' : null),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
                                    );
                                    _load();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateTripForShipperScreen()),
          );
          if (created == true) _load();
        },
        label: Text(tr(context, 'create_trip_for_shipper')),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}
