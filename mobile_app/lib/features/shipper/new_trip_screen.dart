import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/constants/algeria_wilayas.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';

/// Section 5.1: shipper trip-creation form. Single scrollable form per spec.
/// Publish is the one sangle CTA; "save as draft" is a secondary outlined action.
class NewTripScreen extends StatefulWidget {
  const NewTripScreen({super.key, this.onDone});

  /// Called after a successful draft save or publish so the host can switch tabs.
  final VoidCallback? onDone;

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripService = TripService();

  final _pickupAddressCtrl = TextEditingController();
  final _dropoffAddressCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _packageCountCtrl = TextEditingController();
  final _exceptionalDimsCtrl = TextEditingController();
  final _fixedPriceCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  String? _pickupWilaya;
  String? _dropoffWilaya;
  String? _goodsType;
  String? _vehicleType;
  DateTime? _pickupWindowStart;
  DateTime? _pickupWindowEnd;
  DateTime? _requestedDeliveryDate;
  String _pricingMode = 'fixed';
  final List<XFile> _photos = [];

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pickupAddressCtrl.dispose();
    _dropoffAddressCtrl.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    _packageCountCtrl.dispose();
    _exceptionalDimsCtrl.dispose();
    _fixedPriceCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildBody() {
    return {
      'pickup': {'address': _pickupAddressCtrl.text.trim(), 'wilaya': _pickupWilaya},
      'dropoff': {'address': _dropoffAddressCtrl.text.trim(), 'wilaya': _dropoffWilaya},
      'goodsType': _goodsType,
      'weightKg': double.tryParse(_weightCtrl.text.trim()),
      'volumeM3': double.tryParse(_volumeCtrl.text.trim()),
      'packageCount': int.tryParse(_packageCountCtrl.text.trim()),
      'exceptionalDimensions':
          _exceptionalDimsCtrl.text.trim().isEmpty ? null : _exceptionalDimsCtrl.text.trim(),
      'vehicleTypeRequired': _vehicleType,
      'pickupWindowStart': _pickupWindowStart?.toIso8601String(),
      'pickupWindowEnd': _pickupWindowEnd?.toIso8601String(),
      'requestedDeliveryDate': _requestedDeliveryDate?.toIso8601String(),
      'pricingMode': _pricingMode,
      'fixedPrice': _pricingMode == 'fixed' ? double.tryParse(_fixedPriceCtrl.text.trim()) : null,
      'specialInstructions':
          _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
    };
  }

  Future<void> _submit({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupWilaya == null || _dropoffWilaya == null || _goodsType == null || _vehicleType == null) {
      setState(() => _error = tr(context, 'required_field'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final trip = await _tripService.createTrip(_buildBody());
      Trip finalTrip = trip;
      if (publish) {
        finalTrip = await _tripService.publishTrip(trip.id);
      }
      if (!mounted) return;
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, publish ? 'trip_published' : 'draft_saved'))),
      );
      widget.onDone?.call();
      // Keep the reference to avoid an unused-value lint if analyzers are strict.
      assert(finalTrip.id.isNotEmpty);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _pickupAddressCtrl.clear();
    _dropoffAddressCtrl.clear();
    _weightCtrl.clear();
    _volumeCtrl.clear();
    _packageCountCtrl.clear();
    _exceptionalDimsCtrl.clear();
    _fixedPriceCtrl.clear();
    _instructionsCtrl.clear();
    setState(() {
      _pickupWilaya = null;
      _dropoffWilaya = null;
      _goodsType = null;
      _vehicleType = null;
      _pickupWindowStart = null;
      _pickupWindowEnd = null;
      _requestedDeliveryDate = null;
      _pricingMode = 'fixed';
      _photos.clear();
    });
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _photos.addAll(files));
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return tr(context, 'select_date');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(tr(context, 'pickup_point')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pickupAddressCtrl,
              decoration: InputDecoration(labelText: tr(context, 'address')),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _pickupWilaya,
              decoration: InputDecoration(labelText: tr(context, 'wilaya')),
              items: algeriaWilayas
                  .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                  .toList(),
              onChanged: (v) => setState(() => _pickupWilaya = v),
              validator: (v) => v == null ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 20),
            _SectionTitle(tr(context, 'dropoff_point')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dropoffAddressCtrl,
              decoration: InputDecoration(labelText: tr(context, 'address')),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _dropoffWilaya,
              decoration: InputDecoration(labelText: tr(context, 'wilaya')),
              items: algeriaWilayas
                  .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                  .toList(),
              onChanged: (v) => setState(() => _dropoffWilaya = v),
              validator: (v) => v == null ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 20),
            _SectionTitle(tr(context, 'goods_details')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _goodsType,
              decoration: InputDecoration(labelText: tr(context, 'goods_type')),
              items: goodsTypes
                  .map((g) => DropdownMenuItem(value: g, child: Text(tr(context, 'goods_$g'))))
                  .toList(),
              onChanged: (v) => setState(() => _goodsType = v),
              validator: (v) => v == null ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(context, 'weight_kg')),
                    validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _volumeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(context, 'volume_m3')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _packageCountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'package_count')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _exceptionalDimsCtrl,
              decoration: InputDecoration(labelText: tr(context, 'exceptional_dimensions')),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: InputDecoration(labelText: tr(context, 'vehicle_type')),
              items: vehicleTypes
                  .map((v) => DropdownMenuItem(value: v, child: Text(tr(context, 'vehicle_$v'))))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleType = v),
              validator: (v) => v == null ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 20),
            _SectionTitle(tr(context, 'pickup_window_start')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(
                      initial: _pickupWindowStart,
                      onPicked: (d) => setState(() => _pickupWindowStart = d),
                    ),
                    child: Text(_formatDate(_pickupWindowStart)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(
                      initial: _pickupWindowEnd,
                      onPicked: (d) => setState(() => _pickupWindowEnd = d),
                    ),
                    child: Text(_formatDate(_pickupWindowEnd)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SectionTitle(tr(context, 'requested_delivery_date')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pickDate(
                initial: _requestedDeliveryDate,
                onPicked: (d) => setState(() => _requestedDeliveryDate = d),
              ),
              child: Text(_formatDate(_requestedDeliveryDate)),
            ),
            const SizedBox(height: 20),
            _SectionTitle(tr(context, 'pricing_mode')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PricingModeTile(
                    label: tr(context, 'fixed_price'),
                    selected: _pricingMode == 'fixed',
                    onTap: () => setState(() => _pricingMode = 'fixed'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PricingModeTile(
                    label: tr(context, 'request_offers'),
                    selected: _pricingMode == 'bidding',
                    onTap: () => setState(() => _pricingMode = 'bidding'),
                  ),
                ),
              ],
            ),
            if (_pricingMode == 'fixed') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _fixedPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr(context, 'fixed_price')),
                validator: (v) {
                  if (_pricingMode != 'fixed') return null;
                  return (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null;
                },
              ),
            ],
            const SizedBox(height: 20),
            _SectionTitle(tr(context, 'attach_photos')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in _photos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(photo.path), width: 72, height: 72, fit: BoxFit.cover),
                  ),
                InkWell(
                  onTap: _pickPhotos,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.acier),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: AppColors.acier),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(tr(context, 'special_instructions')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _submitting ? null : () => _submit(publish: false),
              child: Text(tr(context, 'save_draft')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitting ? null : () => _submit(publish: true),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(context, 'publish')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.bitume),
    );
  }
}

class _PricingModeTile extends StatelessWidget {
  const _PricingModeTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sangle.withValues(alpha: 0.15) : AppColors.white,
          border: Border.all(color: selected ? AppColors.sangle : AppColors.acier, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.bitume : AppColors.acier),
        ),
      ),
    );
  }
}
