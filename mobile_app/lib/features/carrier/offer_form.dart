import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';

/// Section 5.2: bidding-mode offer submission (price + validity + note).
/// Only shown when trip.pricingMode == 'bidding'.
class OfferForm extends StatefulWidget {
  const OfferForm({super.key, required this.trip, required this.onSubmitted});

  final Trip trip;
  final ValueChanged<Trip> onSubmitted;

  @override
  State<OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferForm> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _validUntil;
  bool _loading = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final updated = await TripService().submitOffer(widget.trip.id, {
        'price': double.parse(_priceController.text.trim()),
        if (_validUntil != null) 'validUntil': _validUntil!.toIso8601String(),
        if (widget.trip.vehicleTypeRequired != null)
          'vehicleTypeProposed': widget.trip.vehicleTypeRequired,
        if (_noteController.text.trim().isNotEmpty) 'note': _noteController.text.trim(),
      });
      widget.onSubmitted(updated);
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
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'submit_offer'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr(context, 'your_price')),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return tr(context, 'required_field');
              if (double.tryParse(v.trim()) == null) return tr(context, 'required_field');
              return null;
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: tr(context, 'valid_until')),
              child: Text(
                _validUntil == null
                    ? tr(context, 'select_date')
                    : '${_validUntil!.day}/${_validUntil!.month}/${_validUntil!.year}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(labelText: tr(context, 'note_optional')),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.halte)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr(context, 'submit_offer')),
          ),
        ],
      ),
    );
  }
}
