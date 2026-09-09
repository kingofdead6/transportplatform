import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/trip_card.dart';
import 'trip_detail_screen.dart';

/// Section 5.1: shipper's own trip list, filterable by status, tap -> detail.
class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final _tripService = TripService();
  List<Trip> _trips = [];
  bool _loading = true;
  String? _error;
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
      setState(() => _trips = trips);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusFilterBar(
          selected: _statusFilter,
          onSelected: (status) {
            setState(() => _statusFilter = status);
            _load();
          },
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.halte)),
        ),
      );
    }
    if (_trips.isEmpty) {
      return EmptyState(message: tr(context, 'no_active_trip'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = <String?>[null, ...tripLifecycleOrder];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final status = statuses[i];
          final isSelected = status == selected;
          return ChoiceChip(
            label: Text(status == null ? tr(context, 'all') : StatusLabels.of(context, status)),
            selected: isSelected,
            onSelected: (_) => onSelected(status),
            selectedColor: AppColors.sangle.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.bitume : AppColors.acier,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}

/// Small helper reusing StatusBadge's french labels for the filter chips, falling back
/// to the raw status code for a locale-agnostic label (StatusBadge itself already covers
/// on-card display; this is just for chip text without recreating the badge visuals).
class StatusLabels {
  static String of(BuildContext context, String status) {
    final key = 'status_$status';
    final label = tr(context, key);
    return label == key ? status.replaceAll('_', ' ') : label;
  }
}
