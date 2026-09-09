import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import 'trip_list_screen.dart' show StatusLabels;

/// Section 5.1: trip detail — lifecycle stepper, offers (if any), confirm receipt,
/// rate carrier, last-known-position map preview, and documents list.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _tripService = TripService();
  Trip? _trip;
  List<dynamic> _documents = [];
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;

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
      List<dynamic> docs = [];
      try {
        final res = await ApiClient.instance.get('/trips/${widget.tripId}/documents');
        docs = res.data is List ? res.data as List : (res.data['documents'] as List? ?? []);
      } catch (_) {
        // Documents endpoint failing shouldn't block showing the trip itself.
      }
      setState(() {
        _trip = trip;
        _documents = docs;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptOffer(TripOffer offer) async {
    setState(() => _actionBusy = true);
    try {
      await _tripService.assignCarrier(widget.tripId, {'offerId': offer.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'offer_accepted'))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _confirmReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'confirm_receipt')),
        content: Text(tr(context, 'confirm_receipt_prompt')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, 'cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, 'confirm'))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _actionBusy = true);
    try {
      await _tripService.confirmPod(widget.tripId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'trip_details'))),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _trip == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? '', style: const TextStyle(color: AppColors.halte)),
        ),
      );
    }
    final trip = _trip!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${trip.pickup.wilaya ?? '-'}  →  ${trip.dropoff.wilaya ?? '-'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(status: trip.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(trip.reference, style: const TextStyle(color: AppColors.acier)),
          const SizedBox(height: 20),
          _LifecycleStepper(status: trip.status),
          const SizedBox(height: 24),
          _InfoCard(trip: trip),
          if (trip.status == 'published' || trip.status == 'offers_received') ...[
            const SizedBox(height: 24),
            _OffersSection(
              offers: trip.offers,
              busy: _actionBusy,
              onAccept: _acceptOffer,
            ),
          ],
          if (trip.status == 'delivered') ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _actionBusy ? null : _confirmReceipt,
              child: Text(tr(context, 'confirm_receipt')),
            ),
          ],
          if (trip.status == 'pod_confirmed') ...[
            const SizedBox(height: 24),
            _ReviewForm(tripId: trip.id, onSubmitted: _load),
          ],
          if (trip.lastKnownLocation?.lat != null && _isInTransit(trip.status)) ...[
            const SizedBox(height: 24),
            _SectionHeader(tr(context, 'last_position')),
            const SizedBox(height: 8),
            _MapPreview(location: trip.lastKnownLocation!),
          ],
          const SizedBox(height: 24),
          _SectionHeader(tr(context, 'documents_section')),
          const SizedBox(height: 8),
          _DocumentsList(documents: _documents),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _isInTransit(String status) => const [
        'driver_assigned',
        'en_route_pickup',
        'loaded',
        'en_route_delivery',
        'arrived_delivery',
      ].contains(status);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
  }
}

class _LifecycleStepper extends StatelessWidget {
  const _LifecycleStepper({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final currentIndex = tripLifecycleOrder.indexOf(status);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tripLifecycleOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final isPast = currentIndex >= 0 && i < currentIndex;
          final isCurrent = i == currentIndex;
          final color = isPast || isCurrent ? AppColors.convoi : AppColors.acier;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPast ? Icons.check_circle : (isCurrent ? Icons.radio_button_checked : Icons.circle_outlined),
                color: isCurrent ? AppColors.sangle : color,
                size: 20,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 72,
                child: Text(
                  StatusLabels.of(context, tripLifecycleOrder[i]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrent ? AppColors.bitume : AppColors.acier,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(context, 'goods_type', trip.goodsType != null ? tr(context, 'goods_${trip.goodsType}') : '-'),
            _row(context, 'weight_kg', trip.weightKg != null ? '${trip.weightKg!.toStringAsFixed(0)} kg' : '-'),
            _row(context, 'vehicle_type',
                trip.vehicleTypeRequired != null ? tr(context, 'vehicle_${trip.vehicleTypeRequired}') : '-'),
            _row(
              context,
              'price',
              trip.agreedPrice != null
                  ? '${trip.agreedPrice!.toStringAsFixed(0)} DA'
                  : (trip.fixedPrice != null ? '${trip.fixedPrice!.toStringAsFixed(0)} DA' : tr(context, 'request_offers')),
            ),
            if (trip.carrierName != null) _row(context, 'carrier', trip.carrierName!),
            if (trip.specialInstructions != null && trip.specialInstructions!.isNotEmpty)
              _row(context, 'special_instructions', trip.specialInstructions!),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(tr(context, labelKey), style: const TextStyle(color: AppColors.acier, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffersSection extends StatelessWidget {
  const _OffersSection({required this.offers, required this.busy, required this.onAccept});

  final List<TripOffer> offers;
  final bool busy;
  final ValueChanged<TripOffer> onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(tr(context, 'offers_received')),
        const SizedBox(height: 8),
        if (offers.isEmpty)
          Text(tr(context, 'no_offers_yet'), style: const TextStyle(color: AppColors.acier))
        else
          ...offers.map(
            (offer) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${offer.price.toStringAsFixed(0)} DA',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (offer.vehicleTypeProposed != null)
                            Text(
                              tr(context, 'vehicle_${offer.vehicleTypeProposed}'),
                              style: const TextStyle(color: AppColors.acier, fontSize: 12),
                            ),
                          if (offer.note != null && offer.note!.isNotEmpty)
                            Text(offer.note!, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (offer.status == 'pending')
                      OutlinedButton(
                        onPressed: busy ? null : () => onAccept(offer),
                        child: Text(tr(context, 'accept_offer')),
                      )
                    else
                      StatusBadge(status: offer.status),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.tripId, required this.onSubmitted});

  final String tripId;
  final VoidCallback onSubmitted;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _tripService = TripService();
  final _commentCtrl = TextEditingController();
  int _punctuality = 5;
  int _goodsCondition = 5;
  int _behavior = 5;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final overall = ((_punctuality + _goodsCondition + _behavior) / 3).round();
      await _tripService.reviewTrip(widget.tripId, {
        'rating': overall,
        'punctuality': _punctuality,
        'goodsCondition': _goodsCondition,
        'behavior': _behavior,
        'comment': _commentCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'review_sent'))));
      widget.onSubmitted();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Text(tr(context, 'review_sent'), style: const TextStyle(color: AppColors.convoi, fontWeight: FontWeight.w600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(tr(context, 'rate_carrier')),
        const SizedBox(height: 8),
        _StarRow(label: tr(context, 'punctuality'), value: _punctuality, onChanged: (v) => setState(() => _punctuality = v)),
        _StarRow(label: tr(context, 'goods_condition'), value: _goodsCondition, onChanged: (v) => setState(() => _goodsCondition = v)),
        _StarRow(label: tr(context, 'behavior'), value: _behavior, onChanged: (v) => setState(() => _behavior = v)),
        const SizedBox(height: 8),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(labelText: tr(context, 'comment')),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr(context, 'submit_review')),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13))),
          ...List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                star <= value ? Icons.star : Icons.star_border,
                color: AppColors.sangle,
                size: 22,
              ),
              onPressed: () => onChanged(star),
            );
          }),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.location});
  final TripLocation location;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(location.lat!, location.lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: position, zoom: 12),
          markers: {Marker(markerId: const MarkerId('last_known'), position: position)},
          zoomControlsEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.documents});
  final List<dynamic> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Text(tr(context, 'no_documents'), style: const TextStyle(color: AppColors.acier));
    }
    return Column(
      children: documents.map((doc) {
        final type = (doc is Map ? doc['type'] : null) ?? '';
        final url = (doc is Map ? doc['url'] : null) ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.acier),
            title: Text(type.toString()),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.tryParse(url.toString());
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      }).toList(),
    );
  }
}
