import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import 'dispute_detail_screen.dart';
import 'widgets/trip_timeline.dart';

/// Trip detail (ADM-01..08): full info, timeline, offers, assign/reassign,
/// invoice issuance, incidents, dispute link.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _tripService = TripService();
  Trip? _trip;
  Map<String, dynamic>? _raw;
  bool _loading = true;
  String? _error;
  List<dynamic> _incidents = const [];

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
      final res = await ApiClient.instance.get('/trips/${widget.tripId}');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _raw = data;
        _trip = Trip.fromJson(data);
        _incidents = data['incidents'] as List? ?? const [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  bool get _readOnly => context.read<AuthService>().currentUser?.adminSubRole == 'lecture';

  Future<void> _assignOffer(TripOffer offer) async {
    try {
      await _tripService.assignCarrier(widget.tripId, {'offerId': offer.id});
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    }
  }

  Future<void> _openManualAssign() async {
    await showDialog(context: context, builder: (_) => _ManualAssignDialog(tripId: widget.tripId));
    _load();
  }

  Future<void> _openReassign() async {
    await showDialog(context: context, builder: (_) => _ReassignDialog(tripId: widget.tripId));
    _load();
  }

  Future<void> _issueInvoice() async {
    try {
      await ApiClient.instance.post('/trips/${widget.tripId}/invoice');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'invoice_issued'))));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_trip?.reference ?? tr(context, 'trip_details'))),
      body: _loading
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
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final trip = _trip!;
    final disputeId = _raw?['disputeId'];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
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
          const SizedBox(height: 16),
          Text(tr(context, 'timeline'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TripTimeline(status: trip.status),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(tr(context, 'goods_type'), trip.goodsType ?? '-'),
                  _infoRow(tr(context, 'weight_kg'), trip.weightKg?.toStringAsFixed(0) ?? '-'),
                  _infoRow(tr(context, 'vehicle_type'), trip.vehicleTypeRequired ?? '-'),
                  _infoRow('Shipper', trip.shipperName ?? '-'),
                  _infoRow(tr(context, 'assigned_carrier'), trip.carrierName ?? '-'),
                  if (trip.agreedPrice != null) _infoRow(tr(context, 'agreed_price'), '${trip.agreedPrice!.toStringAsFixed(0)} DA'),
                  if (trip.commissionAmount != null) _infoRow(tr(context, 'commission'), '${trip.commissionAmount!.toStringAsFixed(0)} DA'),
                  if ((trip.specialInstructions ?? '').isNotEmpty)
                    _infoRow(tr(context, 'special_instructions'), trip.specialInstructions!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr(context, 'offers_received'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (trip.offers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(tr(context, 'no_offers_yet'), style: const TextStyle(color: AppColors.acier)),
            )
          else
            for (final offer in trip.offers)
              Card(
                child: ListTile(
                  title: Text('${offer.price.toStringAsFixed(0)} DA'),
                  subtitle: Text('${offer.carrierId} · ${offer.status}'),
                  trailing: (!_readOnly && offer.status == 'pending')
                      ? TextButton(
                          onPressed: () => _assignOffer(offer),
                          child: Text(tr(context, 'assign_offer')),
                        )
                      : null,
                ),
              ),
          const SizedBox(height: 20),
          if (!_readOnly)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openManualAssign,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(tr(context, 'assign_manually')),
                ),
                OutlinedButton.icon(
                  onPressed: _openReassign,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(tr(context, 'reassign')),
                ),
                if (trip.status == 'pod_confirmed')
                  ElevatedButton.icon(
                    onPressed: _issueInvoice,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(tr(context, 'issue_invoice')),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Text(tr(context, 'incidents'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_incidents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(tr(context, 'no_incidents'), style: const TextStyle(color: AppColors.acier)),
            )
          else
            for (final inc in _incidents)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: AppColors.halte),
                  title: Text(inc['type']?.toString() ?? ''),
                  subtitle: Text(inc['note']?.toString() ?? ''),
                ),
              ),
          if (disputeId != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DisputeDetailScreen(disputeId: disputeId.toString())),
                );
              },
              icon: const Icon(Icons.gavel_outlined),
              label: Text(tr(context, 'dispute_link')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: AppColors.acier, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ManualAssignDialog extends StatefulWidget {
  const _ManualAssignDialog({required this.tripId});
  final String tripId;

  @override
  State<_ManualAssignDialog> createState() => _ManualAssignDialogState();
}

class _ManualAssignDialogState extends State<_ManualAssignDialog> {
  final _carrierIdCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _commissionValueCtrl = TextEditingController();
  String _commissionMode = 'percent';
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'manual_assignment')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _carrierIdCtrl,
              decoration: InputDecoration(labelText: tr(context, 'select_carrier')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'agreed_price')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _commissionMode,
              decoration: InputDecoration(labelText: tr(context, 'commission_mode')),
              items: [
                DropdownMenuItem(value: 'fixed', child: Text(tr(context, 'commission_fixed'))),
                DropdownMenuItem(value: 'percent', child: Text(tr(context, 'commission_percent'))),
                DropdownMenuItem(value: 'margin', child: Text(tr(context, 'commission_margin'))),
              ],
              onChanged: (v) => setState(() => _commissionMode = v ?? 'percent'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commissionValueCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'commission_value')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr(context, 'cancel'))),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await TripService().assignCarrier(widget.tripId, {
                      'carrierId': _carrierIdCtrl.text.trim(),
                      'agreedPrice': double.tryParse(_priceCtrl.text.trim()) ?? 0,
                      'commissionMode': _commissionMode,
                      'commissionValue': double.tryParse(_commissionValueCtrl.text.trim()) ?? 0,
                    });
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    setState(() {
                      _error = tr(context, 'error_generic');
                      _saving = false;
                    });
                  }
                },
          child: Text(tr(context, 'confirm')),
        ),
      ],
    );
  }
}

class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.tripId});
  final String tripId;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  final _carrierIdCtrl = TextEditingController();
  final _driverIdCtrl = TextEditingController();
  final _vehicleIdCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'reassign_trip')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _carrierIdCtrl, decoration: InputDecoration(labelText: tr(context, 'select_carrier'))),
            const SizedBox(height: 8),
            TextField(controller: _driverIdCtrl, decoration: InputDecoration(labelText: tr(context, 'select_driver'))),
            const SizedBox(height: 8),
            TextField(controller: _vehicleIdCtrl, decoration: InputDecoration(labelText: tr(context, 'select_vehicle'))),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr(context, 'cancel'))),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await ApiClient.instance.put('/trips/${widget.tripId}/reassign', data: {
                      'carrierId': _carrierIdCtrl.text.trim(),
                      'driverId': _driverIdCtrl.text.trim(),
                      'vehicleId': _vehicleIdCtrl.text.trim(),
                    });
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    setState(() {
                      _error = tr(context, 'error_generic');
                      _saving = false;
                    });
                  }
                },
          child: Text(tr(context, 'confirm')),
        ),
      ],
    );
  }
}
