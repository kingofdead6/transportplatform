import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';

/// ADM-02: admin creates a trip on behalf of a shipper (phone-intake flow).
/// Requires picking a shipper (GET /api/users?role=shipper&search=) then
/// filling the same fields as the shipper's own create-trip form.
class CreateTripForShipperScreen extends StatefulWidget {
  const CreateTripForShipperScreen({super.key});

  @override
  State<CreateTripForShipperScreen> createState() => _CreateTripForShipperScreenState();
}

class _CreateTripForShipperScreenState extends State<CreateTripForShipperScreen> {
  final _formKey = GlobalKey<FormState>();

  AppUser? _selectedShipper;

  final _pickupAddressCtrl = TextEditingController();
  final _pickupWilayaCtrl = TextEditingController();
  final _dropoffAddressCtrl = TextEditingController();
  final _dropoffWilayaCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _fixedPriceCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  String? _goodsType;
  String? _vehicleType;
  String _pricingMode = 'fixed';
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'create_trip_for_shipper'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ShipperPicker(
              selected: _selectedShipper,
              onSelected: (u) => setState(() => _selectedShipper = u),
            ),
            const SizedBox(height: 16),
            Text(tr(context, 'pickup_point'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pickupAddressCtrl,
              decoration: InputDecoration(labelText: tr(context, 'address')),
              validator: (v) => (v == null || v.isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pickupWilayaCtrl,
              decoration: InputDecoration(labelText: tr(context, 'wilaya')),
              validator: (v) => (v == null || v.isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 16),
            Text(tr(context, 'dropoff_point'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dropoffAddressCtrl,
              decoration: InputDecoration(labelText: tr(context, 'address')),
              validator: (v) => (v == null || v.isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dropoffWilayaCtrl,
              decoration: InputDecoration(labelText: tr(context, 'wilaya')),
              validator: (v) => (v == null || v.isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _goodsType,
              decoration: InputDecoration(labelText: tr(context, 'goods_type')),
              items: [
                for (final g in goodsTypes) DropdownMenuItem(value: g, child: Text(tr(context, 'goods_$g'))),
              ],
              onChanged: (v) => setState(() => _goodsType = v),
              validator: (v) => v == null ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'weight_kg')),
              validator: (v) => (v == null || v.isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: InputDecoration(labelText: tr(context, 'vehicle_type')),
              items: [
                for (final v in vehicleTypes) DropdownMenuItem(value: v, child: Text(tr(context, 'vehicle_$v'))),
              ],
              onChanged: (v) => setState(() => _vehicleType = v),
              validator: (v) => v == null ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _pricingMode,
              decoration: InputDecoration(labelText: tr(context, 'pricing_mode')),
              items: [
                DropdownMenuItem(value: 'fixed', child: Text(tr(context, 'fixed_price'))),
                DropdownMenuItem(value: 'offers', child: Text(tr(context, 'request_offers'))),
              ],
              onChanged: (v) => setState(() => _pricingMode = v ?? 'fixed'),
            ),
            if (_pricingMode == 'fixed') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _fixedPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr(context, 'fixed_price')),
                validator: (v) => (v == null || v.isEmpty) ? tr(context, 'required_field') : null,
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: tr(context, 'special_instructions')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(context, 'submit')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedShipper == null) {
      setState(() => _error = tr(context, 'no_shipper_selected'));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final body = {
        'shipperId': _selectedShipper!.id,
        'pickup': {'address': _pickupAddressCtrl.text.trim(), 'wilaya': _pickupWilayaCtrl.text.trim()},
        'dropoff': {'address': _dropoffAddressCtrl.text.trim(), 'wilaya': _dropoffWilayaCtrl.text.trim()},
        'goodsType': _goodsType,
        'weightKg': double.tryParse(_weightCtrl.text.trim()),
        'vehicleTypeRequired': _vehicleType,
        'pricingMode': _pricingMode,
        if (_pricingMode == 'fixed') 'fixedPrice': double.tryParse(_fixedPriceCtrl.text.trim()),
        if (_instructionsCtrl.text.trim().isNotEmpty) 'specialInstructions': _instructionsCtrl.text.trim(),
      };
      await TripService().createTrip(body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'trip_created_success'))));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _saving = false;
      });
    }
  }
}

class _ShipperPicker extends StatefulWidget {
  const _ShipperPicker({required this.selected, required this.onSelected});
  final AppUser? selected;
  final ValueChanged<AppUser?> onSelected;

  @override
  State<_ShipperPicker> createState() => _ShipperPickerState();
}

class _ShipperPickerState extends State<_ShipperPicker> {
  final _searchCtrl = TextEditingController();
  List<AppUser> _results = const [];
  bool _searching = false;
  Timer? _debounce;

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final res = await ApiClient.instance.get('/users', query: {'role': 'shipper', 'search': query});
      final list = (res.data as List).map((e) => AppUser.fromJson(e)).toList();
      setState(() {
        _results = list;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'select_shipper'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (widget.selected != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.convoi),
              title: Text(widget.selected!.displayName),
              subtitle: Text(widget.selected!.phone),
              trailing: TextButton(
                onPressed: () => widget.onSelected(null),
                child: Text(tr(context, 'cancel')),
              ),
            ),
          )
        else ...[
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: tr(context, 'search_shipper'),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
            },
          ),
          const SizedBox(height: 8),
          for (final u in _results)
            Card(
              child: ListTile(
                title: Text(u.displayName),
                subtitle: Text(u.phone),
                onTap: () => widget.onSelected(u),
              ),
            ),
        ],
      ],
    );
  }
}
