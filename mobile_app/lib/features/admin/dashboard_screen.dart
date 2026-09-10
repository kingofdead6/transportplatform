import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/stat_tile.dart';

/// Dashboard tab: GET /api/reports/summary?period=month stat tiles +
/// document expiry alerts. Section 5.4 "قيادة الرحلات" overview.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<dynamic> _expiringUsers = const [];
  List<dynamic> _expiringVehicles = const [];

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
      final results = await Future.wait([
        ApiClient.instance.get('/reports/summary', query: {'period': 'month'}),
        ApiClient.instance.get('/users/alerts/documents', query: {'days': 30}),
      ]);
      final summary = results[0].data as Map<String, dynamic>;
      final alerts = results[1].data as Map<String, dynamic>;
      setState(() {
        _summary = summary;
        _expiringUsers = alerts['users'] as List? ?? const [];
        _expiringVehicles = alerts['vehicles'] as List? ?? const [];
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: Text(tr(context, 'retry'))),
          ],
        ),
      );
    }

    final s = _summary ?? const {};
    final byStatus = (s['byStatus'] as Map?) ?? {};
    final returnRate = (s['returnLoadRate'] as num?)?.toDouble() ?? 0;
    final totalAlerts = _expiringUsers.length + _expiringVehicles.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (totalAlerts > 0) _AlertBanner(count: totalAlerts),
          if (totalAlerts > 0) const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(label: tr(context, 'stat_total_trips'), value: '${s['totalTrips'] ?? 0}'),
              StatTile(
                label: tr(context, 'stat_total_invoiced'),
                value: '${(s['totalInvoiced'] as num?)?.toStringAsFixed(0) ?? 0} DA',
              ),
              StatTile(
                label: tr(context, 'stat_total_collected'),
                value: '${(s['totalCollected'] as num?)?.toStringAsFixed(0) ?? 0} DA',
                color: AppColors.convoi,
              ),
              StatTile(
                label: tr(context, 'stat_total_commission'),
                value: '${(s['totalCommission'] as num?)?.toStringAsFixed(0) ?? 0} DA',
              ),
              StatTile(
                label: tr(context, 'stat_return_load_rate'),
                value: '${(returnRate * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(tr(context, 'by_status'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final entry in byStatus.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, color: AppColors.statusColor(entry.key.toString())),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.key.toString())),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontFamily: 'ArchivoCondensed', fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  if (byStatus.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(tr(context, 'no_trips_found'), style: const TextStyle(color: AppColors.acier)),
                    ),
                ],
              ),
            ),
          ),
          if (totalAlerts > 0) ...[
            const SizedBox(height: 24),
            Text(tr(context, 'document_alerts'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            for (final u in _expiringUsers)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person, color: AppColors.halte),
                  title: Text((u['companyName'] ?? u['fullName'] ?? u['phone'] ?? '').toString()),
                  subtitle: Text(u['role']?.toString() ?? ''),
                ),
              ),
            for (final v in _expiringVehicles)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping, color: AppColors.halte),
                  title: Text((v['plateNumber'] ?? v['brand'] ?? '').toString()),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.halte.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.halte.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.halte),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tr(context, 'document_alerts')} ($count)',
              style: const TextStyle(color: AppColors.halte, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
