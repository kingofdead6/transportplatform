import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import 'offer_form.dart';
import 'assign_driver_screen.dart';
import 'widgets/trip_progress.dart';

/// Trip detail for a carrier: locations/goods/pricing, the offer form when
/// pricingMode == 'bidding', a direct accept action when pricingMode == 'fixed',
/// the assign-driver CTA once awarded, then a read-only progress stepper.
/// Never fetches or displays competitor offers — the API only returns this
/// carrier's own offer in `trip.offers`.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _tripService = TripService();

  Trip? _trip;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final trip = await _tripService.getTrip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Taking a fixed-price load: this action had no implementation at all, so a
  /// carrier could never accept the half of the marketplace priced this way.
  Future<void> _acceptFixedPrice() async {
    final trip = _trip;
    if (trip == null || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'accept_load')),
        content: Text(
          '${tr(context, 'accept_load_confirm')}\n\n'
          '${trip.pickup.wilaya ?? '-'} → ${trip.dropoff.wilaya ?? '-'}\n'
          '${trip.fixedPrice?.toStringAsFixed(0) ?? '-'} DA',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, 'cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(context, 'confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final updated = await _tripService.acceptFixedPrice(trip.id);
      if (!mounted) return;
      setState(() => _trip = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'load_accepted'))));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Another carrier may have taken it first — reload so the screen reflects that.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'trip_details'))),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null || _trip == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: AppColors.acier),
              const SizedBox(height: 12),
              Text(_error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: Text(tr(context, 'retry'))),
            ],
          ),
        ),
      );
    }

    final trip = _trip!;
    final isOpen = trip.status == 'published' || trip.status == 'offers_received';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TripStatusHeader(status: trip.status),
          const SizedBox(height: 4),
          Text(trip.reference, style: const TextStyle(color: AppColors.acier)),
          const SizedBox(height: 16),
          _InfoCard(trip: trip),
          const SizedBox(height: 20),

          if (isOpen && trip.pricingMode == 'bidding')
            _OfferSection(trip: trip, onSubmitted: (t) => setState(() => _trip = t))
          else if (isOpen && trip.pricingMode == 'fixed')
            _FixedPriceCard(trip: trip, busy: _busy, onAccept: _acceptFixedPrice)
          else if (trip.offers.isNotEmpty)
            _MyOfferCard(trip: trip),

          if (trip.status == 'assigned') ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(tr(context, 'assign_driver_vehicle')),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => AssignDriverScreen(trip: trip)),
                      );
                      if (ok == true) _load();
                    },
            ),
          ],

          // Contacts become useful only once the trip is actually awarded.
          if (!isOpen && (trip.shipperPhone != null || trip.driverPhone != null)) ...[
            const SizedBox(height: 20),
            _ContactsCard(trip: trip, onCall: _call),
          ],

          if (tripLifecycleOrder.indexOf(trip.status) >
              tripLifecycleOrder.indexOf('assigned')) ...[
            const SizedBox(height: 20),
            TripProgress(status: trip.status),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The fixed-price action: price on display plus a single confirming CTA.
class _FixedPriceCard extends StatelessWidget {
  const _FixedPriceCard({required this.trip, required this.busy, required this.onAccept});

  final Trip trip;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'fixed_price'),
            style: const TextStyle(color: AppColors.acier, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${trip.fixedPrice?.toStringAsFixed(0) ?? '-'} DA',
            style: const TextStyle(
              fontFamily: 'ArchivoCondensed',
              fontWeight: FontWeight.w800,
              fontSize: 30,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'fixed_price_note'),
            style: const TextStyle(color: AppColors.acier, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: busy ? null : onAccept,
            icon: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(tr(context, 'accept_load')),
          ),
        ],
      ),
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.trip, required this.onCall});

  final Trip trip;
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          if (trip.shipperPhone != null)
            _ContactRow(
              icon: Icons.business_outlined,
              name: trip.shipperName ?? tr(context, 'role_shipper'),
              phone: trip.shipperPhone!,
              onCall: onCall,
            ),
          if (trip.shipperPhone != null && trip.driverPhone != null)
            const Divider(height: 20),
          if (trip.driverPhone != null)
            _ContactRow(
              icon: Icons.person_outline,
              name: trip.driverName ?? tr(context, 'role_driver'),
              phone: trip.driverPhone!,
              onCall: onCall,
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.name,
    required this.phone,
    required this.onCall,
  });

  final IconData icon;
  final String name;
  final String phone;
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.acier, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              Text(phone, style: const TextStyle(color: AppColors.acier, fontSize: 12.5)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => onCall(phone),
          icon: const Icon(Icons.call, color: AppColors.convoi),
          tooltip: tr(context, 'call'),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            label: tr(context, 'pickup'),
            value: trip.pickup.wilaya ?? trip.pickup.address ?? '-',
          ),
          _Row(
            label: tr(context, 'dropoff'),
            value: trip.dropoff.wilaya ?? trip.dropoff.address ?? '-',
          ),
          if (trip.goodsType != null)
            _Row(label: tr(context, 'goods'), value: tr(context, 'goods_${trip.goodsType}')),
          if (trip.weightKg != null)
            _Row(label: tr(context, 'weight'), value: '${trip.weightKg!.toStringAsFixed(0)} kg'),
          if (trip.vehicleTypeRequired != null)
            _Row(
              label: tr(context, 'vehicle_type'),
              value: tr(context, 'vehicle_${trip.vehicleTypeRequired}'),
            ),
          if (trip.requestedDeliveryDate != null)
            _Row(
              label: tr(context, 'requested_delivery'),
              value: '${trip.requestedDeliveryDate!.day}/'
                  '${trip.requestedDeliveryDate!.month}/'
                  '${trip.requestedDeliveryDate!.year}',
            ),
          if (trip.pricingMode == 'fixed' && trip.fixedPrice != null)
            _Row(
              label: tr(context, 'fixed_price'),
              value: '${trip.fixedPrice!.toStringAsFixed(0)} DA',
            ),
          if (trip.agreedPrice != null)
            _Row(label: tr(context, 'price'), value: '${trip.agreedPrice!.toStringAsFixed(0)} DA'),
          if (trip.specialInstructions != null && trip.specialInstructions!.isNotEmpty)
            _Row(label: tr(context, 'special_instructions'), value: trip.specialInstructions!),
        ],
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
            child: Text(label, style: const TextStyle(color: AppColors.acier, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: OfferForm(trip: trip, onSubmitted: onSubmitted),
    );
  }
}

class _MyOfferCard extends StatelessWidget {
  const _MyOfferCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final offer = trip.offers.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
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
            style: const TextStyle(
              fontFamily: 'ArchivoCondensed',
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          if (offer.validUntil != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${tr(context, 'valid_until')} '
                '${offer.validUntil!.day}/${offer.validUntil!.month}/${offer.validUntil!.year}',
                style: const TextStyle(color: AppColors.acier, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
