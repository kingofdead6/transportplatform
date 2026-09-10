import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import 'dispute_detail_screen.dart';
import 'widgets/entity_picker.dart';
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

  bool get _readOnly => context.read<AuthService>().currentUser?.adminSubRole == 'lecture';

  Future<void> _run(Future<void> Function() action, {String? successKey}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (successKey != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(context, successKey))));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        // Surface the server's actual reason instead of a generic message.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignOffer(TripOffer offer) =>
      _run(() => _tripService.assignCarrier(widget.tripId, {'offerId': offer.id}));

  Future<void> _issueInvoice() => _run(
        () => ApiClient.instance.post('/trips/${widget.tripId}/invoice'),
        successKey: 'invoice_issued',
      );

  Future<void> _openManualAssign() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ManualAssignDialog(tripId: widget.tripId),
    );
    if (done == true) _load();
  }

  Future<void> _openReassign() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ReassignDialog(tripId: widget.tripId),
    );
    if (done == true) _load();
  }

  Future<void> _cancelTrip() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'cancel_trip')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(context, 'cancel_trip_confirm')),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(labelText: tr(context, 'cancel_reason')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, 'cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.halte),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(context, 'confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _tripService.cancelTrip(widget.tripId, reason: reasonCtrl.text.trim()),
      successKey: 'trip_cancelled',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_trip?.reference ?? tr(context, 'trip_details'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null || _trip == null)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? ''),
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
    final canCancel = !['delivered', 'pod_confirmed', 'invoiced', 'paid', 'closed', 'cancelled']
        .contains(trip.status);

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

          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(tr(context, 'goods_type'),
                    trip.goodsType != null ? tr(context, 'goods_${trip.goodsType}') : '-'),
                _infoRow(tr(context, 'weight_kg'), trip.weightKg?.toStringAsFixed(0) ?? '-'),
                _infoRow(
                    tr(context, 'vehicle_type'),
                    trip.vehicleTypeRequired != null
                        ? tr(context, 'vehicle_${trip.vehicleTypeRequired}')
                        : '-'),
                _infoRow(tr(context, 'role_shipper'), trip.shipperName ?? '-'),
                _infoRow(tr(context, 'assigned_carrier'), trip.carrierName ?? '-'),
                if (trip.driverName != null)
                  _infoRow(tr(context, 'role_driver'), trip.driverName!),
                if (trip.agreedPrice != null)
                  _infoRow(tr(context, 'agreed_price'),
                      '${trip.agreedPrice!.toStringAsFixed(0)} DA'),
                if (trip.commissionAmount != null)
                  _infoRow(tr(context, 'commission'),
                      '${trip.commissionAmount!.toStringAsFixed(0)} DA'),
                if ((trip.specialInstructions ?? '').isNotEmpty)
                  _infoRow(tr(context, 'special_instructions'), trip.specialInstructions!),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(tr(context, 'offers_received'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (trip.offers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child:
                  Text(tr(context, 'no_offers_yet'), style: const TextStyle(color: AppColors.acier)),
            )
          else
            for (final offer in trip.offers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Card(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${offer.price.toStringAsFixed(0)} DA',
                              style: const TextStyle(
                                fontFamily: 'ArchivoCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            StatusBadge(status: offer.status, compact: true),
                          ],
                        ),
                      ),
                      if (!_readOnly && offer.status == 'pending')
                        OutlinedButton(
                          onPressed: _busy ? null : () => _assignOffer(offer),
                          child: Text(tr(context, 'assign_offer')),
                        ),
                    ],
                  ),
                ),
              ),

          const SizedBox(height: 20),
          if (!_readOnly)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openManualAssign,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(tr(context, 'assign_manually')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openReassign,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(tr(context, 'reassign')),
                ),
                if (trip.status == 'pod_confirmed')
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _issueInvoice,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(tr(context, 'issue_invoice')),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _cancelTrip,
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.halte),
                    label: Text(
                      tr(context, 'cancel_trip'),
                      style: const TextStyle(color: AppColors.halte),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 24),
          Text(tr(context, 'incidents'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // Reads trip.incidents, mapped from the backend's `incidentReports`.
          // The screen previously looked for a field named `incidents`, so the
          // list was always empty even when incidents existed.
          if (trip.incidents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child:
                  Text(tr(context, 'no_incidents'), style: const TextStyle(color: AppColors.acier)),
            )
          else
            for (final inc in trip.incidents)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.report_problem_outlined, color: AppColors.halte),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, 'incident_${inc.type}') == 'incident_${inc.type}'
                                  ? inc.type
                                  : tr(context, 'incident_${inc.type}'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if ((inc.note ?? '').isNotEmpty)
                              Text(inc.note!,
                                  style: const TextStyle(color: AppColors.acier, fontSize: 13)),
                            if (inc.reportedAt != null)
                              Text(
                                '${inc.reportedAt!.day}/${inc.reportedAt!.month}/${inc.reportedAt!.year}'
                                ' ${inc.reportedAt!.hour.toString().padLeft(2, '0')}:'
                                '${inc.reportedAt!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: AppColors.acier, fontSize: 11.5),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          if (trip.disputeId != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DisputeDetailScreen(disputeId: trip.disputeId!),
                ),
              ),
              icon: const Icon(Icons.gavel_outlined),
              label: Text(tr(context, 'dispute_link')),
            ),
          ],
          const SizedBox(height: 24),
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
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.acier, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}

/// Direct assignment. Carrier is chosen from a real list rather than typed as
/// an ObjectId.
class _ManualAssignDialog extends StatefulWidget {
  const _ManualAssignDialog({required this.tripId});
  final String tripId;

  @override
  State<_ManualAssignDialog> createState() => _ManualAssignDialogState();
}

class _ManualAssignDialogState extends State<_ManualAssignDialog> {
  final _priceCtrl = TextEditingController();
  final _commissionValueCtrl = TextEditingController();
  String? _carrierId;
  String _commissionMode = 'percent';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _commissionValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_carrierId == null) {
      setState(() => _error = tr(context, 'select_carrier_hint'));
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = tr(context, 'required_field'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await TripService().assignCarrier(widget.tripId, {
        'carrierId': _carrierId,
        'agreedPrice': price,
        'commissionMode': _commissionMode,
        if (_commissionValueCtrl.text.trim().isNotEmpty)
          'commissionValue': double.tryParse(_commissionValueCtrl.text.trim()),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'manual_assignment')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityPicker(
              label: tr(context, 'select_carrier'),
              loader: AdminLookups.carriers,
              value: _carrierId,
              emptyMessage: tr(context, 'no_carriers'),
              onChanged: (v) => setState(() => _carrierId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr(context, 'agreed_price')),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _commissionValueCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr(context, 'commission_value')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.halte, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(tr(context, 'cancel')),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr(context, 'confirm')),
        ),
      ],
    );
  }
}

/// Reassignment. Driver and vehicle lists follow the selected carrier.
class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.tripId});
  final String tripId;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  String? _carrierId;
  String? _driverId;
  String? _vehicleId;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_carrierId == null && _driverId == null && _vehicleId == null) {
      setState(() => _error = tr(context, 'required_field'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.put('/trips/${widget.tripId}/reassign', data: {
        if (_carrierId != null) 'carrierId': _carrierId,
        if (_driverId != null) 'driverId': _driverId,
        if (_vehicleId != null) 'vehicleId': _vehicleId,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrierId = _carrierId;
    return AlertDialog(
      title: Text(tr(context, 'reassign_trip')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityPicker(
              label: tr(context, 'select_carrier'),
              loader: AdminLookups.carriers,
              value: _carrierId,
              emptyMessage: tr(context, 'no_carriers'),
              onChanged: (v) => setState(() {
                _carrierId = v;
                // The previous crew belongs to the old carrier.
                _driverId = null;
                _vehicleId = null;
              }),
            ),
            const SizedBox(height: 12),
            // Keyed on the carrier so the lists reload when it changes.
            EntityPicker(
              key: ValueKey('drivers-$carrierId'),
              label: tr(context, 'select_driver'),
              loader: () =>
                  carrierId == null ? Future.value(<PickerOption>[]) : AdminLookups.driversOf(carrierId),
              value: _driverId,
              enabled: carrierId != null,
              emptyMessage: tr(context, 'select_carrier_hint'),
              onChanged: (v) => setState(() => _driverId = v),
            ),
            const SizedBox(height: 12),
            EntityPicker(
              key: ValueKey('vehicles-$carrierId'),
              label: tr(context, 'select_vehicle'),
              loader: () => carrierId == null
                  ? Future.value(<PickerOption>[])
                  : AdminLookups.vehiclesOf(carrierId),
              value: _vehicleId,
              enabled: carrierId != null,
              emptyMessage: tr(context, 'select_carrier_hint'),
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.halte, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(tr(context, 'cancel')),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr(context, 'confirm')),
        ),
      ],
    );
  }
}
