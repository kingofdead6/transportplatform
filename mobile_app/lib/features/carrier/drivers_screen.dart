import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import 'models/vehicle.dart';
import 'add_driver_screen.dart';

/// Driver roster list. Section 5.2: GET /api/users/drivers.
class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  late Future<List<CarrierDriver>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CarrierDriver>> _load() async {
    final res = await ApiClient.instance.get('/users/drivers');
    return (res.data as List).map((e) => CarrierDriver.fromJson(e)).toList();
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
            MaterialPageRoute(builder: (_) => const AddDriverScreen()),
          );
          if (added == true) _refresh();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CarrierDriver>>(
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
            final drivers = snapshot.data ?? [];
            if (drivers.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(message: tr(context, 'no_drivers_yet'), icon: Icons.badge_outlined),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: drivers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _DriverCard(driver: drivers[i]),
            );
          },
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});
  final CarrierDriver driver;

  @override
  Widget build(BuildContext context) {
    final flagged = isExpiringSoon(driver.licenseExpiresAt);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
        border: flagged
            ? Border.all(color: AppColors.halte.withValues(alpha: 0.5))
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.beton,
            child: Icon(Icons.person, color: AppColors.acier),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName ?? driver.phone,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(driver.phone, style: const TextStyle(color: AppColors.acier, fontSize: 12)),
                if (driver.licenseCategory != null)
                  Text(
                    '${tr(context, 'license_category')}: ${driver.licenseCategory}',
                    style: const TextStyle(color: AppColors.acier, fontSize: 12),
                  ),
                if (driver.licenseExpiresAt != null)
                  Row(
                    children: [
                      if (flagged) const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.halte),
                      if (flagged) const SizedBox(width: 4),
                      Text(
                        '${tr(context, 'license_expiry')}: '
                        '${driver.licenseExpiresAt!.day}/${driver.licenseExpiresAt!.month}/${driver.licenseExpiresAt!.year}',
                        style: TextStyle(
                          color: flagged ? AppColors.halte : AppColors.acier,
                          fontSize: 12,
                          fontWeight: flagged ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
