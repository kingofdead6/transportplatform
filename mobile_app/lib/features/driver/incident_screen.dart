import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import 'mission_action_button.dart';

/// CHA-10: secondary/low-weight flow reached via a small icon, not the main CTA.
/// Reports via TripService.reportIncident, which auto-queues offline.
class IncidentScreen extends StatefulWidget {
  const IncidentScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  static const _types = [
    'breakdown',
    'accident',
    'road_blocked',
    'goods_refused',
    'excessive_wait',
  ];

  final _tripService = TripService();
  final _noteController = TextEditingController();
  String _type = _types.first;
  XFile? _photo;
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _typeLabel(BuildContext context, String type) => tr(context, 'incident_$type');

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _tripService.reportIncident(widget.tripId, {
        'type': _type,
        'note': _noteController.text.trim(),
        if (_photo != null) 'photos': [_photo!.path],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'incident_sent'))),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'error_generic'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'report_incident'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'incident_type'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E6E8)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(context, t))))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'incident_note'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_photo == null ? tr(context, 'take_photo') : '1 ${tr(context, 'photo_taken')}'),
              ),
              if (_photo != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(_photo!.path), height: 140, fit: BoxFit.cover),
                ),
              ],
              const Spacer(),
              MissionActionButton(
                label: tr(context, 'submit_incident'),
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
