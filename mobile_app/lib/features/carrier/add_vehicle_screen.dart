import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

/// Section 5.2 fleet management: POST /api/vehicles.
class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _capacityController = TextEditingController();
  final _yearController = TextEditingController();
  String _type = vehicleTypes.first;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/vehicles', data: {
        'plateNumber': _plateController.text.trim(),
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'type': _type,
        if (_capacityController.text.trim().isNotEmpty)
          'payloadCapacityKg': double.tryParse(_capacityController.text.trim()),
        if (_yearController.text.trim().isNotEmpty)
          'yearOfManufacture': int.tryParse(_yearController.text.trim()),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _capacityController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'add_vehicle'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _plateController,
              decoration: InputDecoration(labelText: tr(context, 'plate_number')),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              decoration: InputDecoration(labelText: tr(context, 'brand')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelController,
              decoration: InputDecoration(labelText: tr(context, 'model')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: tr(context, 'vehicle_type')),
              items: vehicleTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(tr(context, 'vehicle_$t'))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'payload_capacity')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'year_of_manufacture')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}
