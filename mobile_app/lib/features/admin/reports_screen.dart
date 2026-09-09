import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import 'widgets/stat_tile.dart';

/// Reports tab (ADM-17/18): summary stats by period + margins report table
/// with an export-styled (placeholder) button. Dashboard already covers the
/// month-over-month summary, so this tab lets the admin pick a period and
/// focuses on the margins detail.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'month';
  Map<String, dynamic>? _summary;
  List<dynamic> _rows = const [];
  Map<String, dynamic> _totals = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/reports/summary', query: {'period': _period}),
        ApiClient.instance.get('/reports/margins'),
      ]);
      final summary = results[0].data as Map<String, dynamic>;
      final margins = results[1].data as Map<String, dynamic>;
      setState(() {
        _summary = summary;
        _rows = margins['rows'] as List? ?? const [];
        _totals = (margins['totals'] as Map<String, dynamic>?) ?? const {};
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _summary ?? const {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text(tr(context, 'admin_reports'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'day', label: Text(tr(context, 'period_day'))),
                  ButtonSegment(value: 'week', label: Text(tr(context, 'period_week'))),
                  ButtonSegment(value: 'month', label: Text(tr(context, 'period_month'))),
                ],
                selected: {_period},
                onSelectionChanged: (s) {
                  setState(() => _period = s.first);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text(tr(context, 'margins_report'), style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'export_note'))));
                },
                icon: const Icon(Icons.file_download_outlined),
                label: Text(tr(context, 'export')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_rows.isEmpty)
            EmptyState(message: tr(context, 'no_trips_found'))
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(tr(context, 'mission_reference'))),
                  const DataColumn(label: Text('Shipper')),
                  DataColumn(label: Text(tr(context, 'carrier'))),
                  const DataColumn(label: Text('Corridor')),
                  DataColumn(label: Text(tr(context, 'agreed_price'))),
                  DataColumn(label: Text(tr(context, 'commission'))),
                ],
                rows: [
                  for (final r in _rows)
                    DataRow(cells: [
                      DataCell(Text(r['reference']?.toString() ?? '')),
                      DataCell(Text(r['shipper']?.toString() ?? '')),
                      DataCell(Text(r['carrier']?.toString() ?? '')),
                      DataCell(Text(r['corridor']?.toString() ?? '')),
                      DataCell(Text('${(r['agreedPrice'] as num?)?.toStringAsFixed(0) ?? 0}')),
                      DataCell(Text('${(r['commission'] as num?)?.toStringAsFixed(0) ?? 0}')),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${tr(context, 'total_revenue')}: ${(_totals['totalRevenue'] as num?)?.toStringAsFixed(0) ?? 0} DA   ·   '
              '${tr(context, 'stat_total_commission')}: ${(_totals['totalCommission'] as num?)?.toStringAsFixed(0) ?? 0} DA',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
