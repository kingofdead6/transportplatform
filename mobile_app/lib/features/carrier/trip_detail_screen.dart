import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import 'offer_form.dart';
import 'assign_driver_screen.dart';
import 'widgets/trip_progress.dart';

/// Trip detail for a carrier: shows locations/goods/pricing, the offer form
/// when pricingMode == 'bidding', assign-driver CTA when status == 'assigned',
/// or a read-only progress stepper further along the lifecycle.
/// Never fetches or displays competitor offers — the API only returns this
/// carrier's own offer in `trip.offers`.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<Trip> _future;

  @override
  void initState() {
    super.initState();
    _future = TripService().getTrip(widget.tripId);
  }

  void _reload() {
    setState(() => _future = TripService().getTrip(widget.tripId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'trip_details'))),
      body: FutureBuilder<Trip>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final trip = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TripStatusHeader(status: trip.status),
              const SizedBox(height: 4),
              Text(trip.reference, style: const TextStyle(color: AppColors.acier)),
              const SizedBox(height: 16),
              _InfoCard(trip: trip),
              const SizedBox(height: 20),
              if (trip.pricingMode == 'bidding' &&
                  (trip.status == 'published' || trip.status == 'offers_received'))
                _OfferSection(trip: trip, onSubmitted: (_) => _reload())
              else if (trip.pricingMode == 'fixed' &&
                  (trip.status == 'published' || trip.status == 'offers_received'))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.acier),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tr(context, 'fixed_price_note'))),
                      ],
                    ),
                  ),
                )
              else if (trip.offers.isNotEmpty)
                _MyOfferCard(trip: trip),
              if (trip.status == 'assigned') ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(tr(context, 'assign_driver_vehicle')),
                  onPressed: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => AssignDriverScreen(trip: trip)),
                    );
                    if (ok == true) _reload();
                  },
                ),
              ],
              if (tripLifecycleOrder.indexOf(trip.status) >
                  tripLifecycleOrder.indexOf('assigned')) ...[
                const SizedBox(height: 20),
                TripProgress(status: trip.status),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: tr(context, 'pickup'), value: trip.pickup.wilaya ?? trip.pickup.address ?? '-'),
            _Row(label: tr(context, 'dropoff'), value: trip.dropoff.wilaya ?? trip.dropoff.address ?? '-'),
            if (trip.goodsType != null) _Row(label: tr(context, 'goods'), value: trip.goodsType!),
            if (trip.weightKg != null)
              _Row(label: tr(context, 'weight'), value: '${trip.weightKg!.toStringAsFixed(0)} kg'),
            if (trip.vehicleTypeRequired != null)
              _Row(label: tr(context, 'vehicle_type'), value: trip.vehicleTypeRequired!),
            if (trip.requestedDeliveryDate != null)
              _Row(
                label: tr(context, 'requested_delivery'),
                value:
                    '${trip.requestedDeliveryDate!.day}/${trip.requestedDeliveryDate!.month}/${trip.requestedDeliveryDate!.year}',
              ),
            if (trip.pricingMode == 'fixed' && trip.fixedPrice != null)
              _Row(label: tr(context, 'fixed_price'), value: '${trip.fixedPrice!.toStringAsFixed(0)} DA'),
            if (trip.agreedPrice != null)
              _Row(label: tr(context, 'price'), value: '${trip.agreedPrice!.toStringAsFixed(0)} DA'),
            if (trip.specialInstructions != null && trip.specialInstructions!.isNotEmpty)
              _Row(label: tr(context, 'special_instructions'), value: trip.specialInstructions!),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.acier)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _OfferSection extends StatelessWidget {
  const _OfferSection({required this.trip, required this.onSubmitted});
  final Trip trip;
  final ValueChanged<Trip> onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (trip.offers.isNotEmpty) {
      return _MyOfferCard(trip: trip);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OfferForm(trip: trip, onSubmitted: onSubmitted),
      ),
    );
  }
}

class _MyOfferCard extends StatelessWidget {
  const _MyOfferCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final offer = trip.offers.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr(context, 'your_offer'), style: const TextStyle(fontWeight: FontWeight.w700)),
                StatusBadge(status: offer.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${offer.price.toStringAsFixed(0)} DA',
              style: const TextStyle(fontFamily: 'ArchivoCondensed', fontWeight: FontWeight.w700, fontSize: 20),
            ),
            if (offer.validUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${tr(context, 'valid_until')} ${offer.validUntil!.day}/${offer.validUntil!.month}/${offer.validUntil!.year}',
                  style: const TextStyle(color: AppColors.acier, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
