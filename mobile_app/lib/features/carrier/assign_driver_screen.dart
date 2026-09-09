import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import 'models/vehicle.dart';

/// Section 5.2: once a trip is 'assigned' (awarded to this carrier, no driver
/// yet), the carrier picks one of their own drivers + vehicles to run it.
class AssignDriverScreen extends StatefulWidget {
  const AssignDriverScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<AssignDriverScreen> createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends State<AssignDriverScreen> {
  late Future<(List<CarrierDriver>, List<Vehicle>)> _future;
  String? _driverId;
  String? _vehicleId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<CarrierDriver>, List<Vehicle>)> _load() async {
    final api = ApiClient.instance;
    final driversRes = await api.get('/users/drivers');
    final vehiclesRes = await api.get('/vehicles/mine');
    final drivers = (driversRes.data as List).map((e) => CarrierDriver.fromJson(e)).toList();
    final vehicles = (vehiclesRes.data as List).map((e) => Vehicle.fromJson(e)).toList();
    return (drivers, vehicles);
  }

  Future<void> _submit() async {
    if (_driverId == null) {
      setState(() => _error = tr(context, 'required_field'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await TripService().assignDriver(widget.trip.id, driverId: _driverId!, vehicleId: _vehicleId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'assign_driver_vehicle'))),
      body: FutureBuilder<(List<CarrierDriver>, List<Vehicle>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final (drivers, vehicles) = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _driverId,
                  decoration: InputDecoration(labelText: tr(context, 'select_driver')),
                  items: drivers
                      .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.fullName ?? d.phone),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _driverId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  decoration: InputDecoration(labelText: tr(context, 'select_vehicle')),
                  items: vehicles
                      .map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text('${v.plateNumber} — ${v.brand ?? ''} ${v.model ?? ''}'.trim()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.halte)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tr(context, 'submit')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
