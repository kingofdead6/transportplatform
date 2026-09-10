import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import 'models/vehicle.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

/// Fleet vehicle list. Section 5.2 fleet management: GET /api/vehicles/mine.
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  late Future<List<Vehicle>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Vehicle>> _load() async {
    final res = await ApiClient.instance.get('/vehicles/mine');
    return (res.data as List).map((e) => Vehicle.fromJson(e)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.sangle,
        foregroundColor: AppColors.bitume,
        child: const Icon(Icons.add),
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
          );
          if (added == true) _refresh();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Vehicle>>(
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
            final vehicles = snapshot.data ?? [];
            if (vehicles.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(message: tr(context, 'no_vehicles_yet'), icon: Icons.local_shipping_outlined),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _VehicleCard(
                vehicle: vehicles[i],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicles[i])),
                  );
                  _refresh();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap});
  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expiry = vehicle.nearestExpiry;
    final flagged = isExpiringSoon(expiry);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow,
          border: flagged
              ? Border.all(color: AppColors.halte.withValues(alpha: 0.5))
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.plateNumber,
                    style: const TextStyle(fontFamily: 'ArchivoCondensed', fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                _StatusChip(status: vehicle.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [vehicle.brand, vehicle.model].where((s) => s != null && s.isNotEmpty).join(' '),
              style: const TextStyle(color: AppColors.acier, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(tr(context, vehicle.type == 'flatbed' ? 'vehicle_flatbed' : 'vehicle_${vehicle.type}')),
                if (vehicle.payloadCapacityKg != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${vehicle.payloadCapacityKg!.toStringAsFixed(0)} kg',
                    style: const TextStyle(fontFamily: 'ArchivoCondensed', fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            if (flagged) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.halte),
                  const SizedBox(width: 4),
                  Text(
                    isExpired(expiry) ? tr(context, 'expired') : tr(context, 'expires_soon'),
                    style: const TextStyle(color: AppColors.halte, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status == 'available' ? 'available' : status);
    final labelKey = 'status_$status';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(tr(context, labelKey), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
