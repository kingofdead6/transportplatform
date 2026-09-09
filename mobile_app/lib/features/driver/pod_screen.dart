import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import 'mission_action_button.dart';

/// CHA-08: proof-of-delivery — photo of the signed slip + on-screen signature +
/// recipient name. Uploads multipart via ApiClient.dio directly (this endpoint has
/// no offline-queue support), then transitions the trip to 'delivered'.
class PodScreen extends StatefulWidget {
  const PodScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<PodScreen> createState() => _PodScreenState();
}

class _PodScreenState extends State<PodScreen> {
  final _tripService = TripService();
  final _nameController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.bitume,
    exportBackgroundColor: AppColors.white,
  );

  final List<XFile> _photos = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 6) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) setState(() => _photos.add(file));
  }

  bool get _canSubmit =>
      _photos.isNotEmpty && !_signatureController.isEmpty && _nameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _error = tr(context, 'photos_required'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final signatureBytes = await _signatureController.toPngBytes();

      final form = FormData();
      for (var i = 0; i < _photos.length; i++) {
        form.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(_photos[i].path, filename: 'pod_photo_$i.jpg'),
        ));
      }
      if (signatureBytes != null) {
        form.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(signatureBytes, filename: 'signature.png'),
        ));
      }
      form.fields.add(MapEntry('signedByName', _nameController.text.trim()));

      await ApiClient.instance.uploadForm('/trips/${widget.tripId}/documents/pod', form);

      double? lat;
      double? lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // location best-effort only
      }

      await _tripService.updateStatus(widget.tripId, 'delivered', lat: lat, lng: lng);
      if (lat != null && lng != null) {
        SocketService.instance.sendLocation(widget.tripId, lat, lng);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = tr(context, 'error_generic'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'delivery_done'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'pod_step_photo'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(p.path), width: 84, height: 84, fit: BoxFit.cover),
                    ),
                  InkWell(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.acier),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: AppColors.acier, size: 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, 'signed_by_name'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, 'sign_here'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.acier),
                ),
                child: Stack(
                  children: [
                    Signature(controller: _signatureController, backgroundColor: AppColors.white),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.acier),
                        onPressed: () {
                          _signatureController.clear();
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.halte, fontSize: 13)),
              ],
              const SizedBox(height: 28),
              MissionActionButton(
                label: tr(context, 'confirm_delivery'),
                loading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
