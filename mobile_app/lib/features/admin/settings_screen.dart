import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';

/// Settings tab (ADM-21): GET/PUT /api/settings. Reference prices shown
/// read-only for this pass (full CRUD is nice-to-have per spec).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  final _commissionCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _windowCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  List<dynamic> _referencePrices = const [];

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
      final res = await ApiClient.instance.get('/settings');
      final data = res.data as Map<String, dynamic>;
      _commissionCtrl.text = '${data['defaultCommissionPercent'] ?? ''}';
      _radiusCtrl.text = '${data['returnLoadRadiusKm'] ?? ''}';
      _windowCtrl.text = '${data['returnLoadWindowDays'] ?? ''}';
      _vatCtrl.text = '${data['vatPercent'] ?? ''}';
      _prefixCtrl.text = '${data['invoicePrefix'] ?? ''}';
      setState(() {
        _referencePrices = data['referencePrices'] as List? ?? const [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.put('/settings', data: {
        'defaultCommissionPercent': double.tryParse(_commissionCtrl.text.trim()),
        'returnLoadRadiusKm': double.tryParse(_radiusCtrl.text.trim()),
        'returnLoadWindowDays': int.tryParse(_windowCtrl.text.trim()),
        'vatPercent': double.tryParse(_vatCtrl.text.trim()),
        'invoicePrefix': _prefixCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'settings_saved'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = context.watch<AuthService>().currentUser?.adminSubRole == 'lecture';

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _commissionCtrl,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr(context, 'default_commission_percent')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _radiusCtrl,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr(context, 'return_load_radius_km')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _windowCtrl,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr(context, 'return_load_window_days')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vatCtrl,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr(context, 'vat_percent')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _prefixCtrl,
          enabled: !readOnly,
          decoration: InputDecoration(labelText: tr(context, 'invoice_prefix')),
        ),
        if (!readOnly) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr(context, 'save')),
          ),
        ],
        const SizedBox(height: 28),
        Text(tr(context, 'reference_prices'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_referencePrices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(tr(context, 'no_trips_found'), style: const TextStyle(color: AppColors.acier)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(tr(context, 'pickup'))),
                DataColumn(label: Text(tr(context, 'dropoff'))),
                DataColumn(label: Text(tr(context, 'vehicle_type'))),
                DataColumn(label: Text(tr(context, 'price'))),
              ],
              rows: [
                for (final p in _referencePrices)
                  DataRow(cells: [
                    DataCell(Text(p['fromWilaya']?.toString() ?? '')),
                    DataCell(Text(p['toWilaya']?.toString() ?? '')),
                    DataCell(Text(p['vehicleType']?.toString() ?? '')),
                    DataCell(Text('${(p['pricePerTrip'] as num?)?.toStringAsFixed(0) ?? 0} DA')),
                  ]),
              ],
            ),
          ),
      ],
    );
  }
}
