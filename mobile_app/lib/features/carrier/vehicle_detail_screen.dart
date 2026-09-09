import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import 'models/vehicle.dart';

/// Vehicle detail: status toggle (available/on_mission/broken_down/maintenance)
/// and per-document upload with expiry date. Section 5.2.
class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

const _statusOptions = ['available', 'on_mission', 'broken_down', 'maintenance'];
const _docTypes = ['registration', 'insurance', 'technical_inspection'];

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late String _status;
  bool _savingStatus = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.vehicle.status;
  }

  Future<void> _updateStatus(String next) async {
    setState(() {
      _savingStatus = true;
      _error = null;
    });
    try {
      await ApiClient.instance.put('/vehicles/${widget.vehicle.id}/status', data: {'status': next});
      setState(() => _status = next);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _uploadDoc(String type) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    if (!mounted) return;
    final expiresAt = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (expiresAt == null) return;
    try {
      final form = FormData.fromMap({
        'type': type,
        'expiresAt': expiresAt.toIso8601String(),
        'file': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      await ApiClient.instance.uploadForm('/vehicles/${widget.vehicle.id}/documents', form);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'saved'))));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    return Scaffold(
      appBar: AppBar(title: Text(vehicle.plateNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [vehicle.brand, vehicle.model].where((s) => s != null && s.isNotEmpty).join(' '),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(tr(context, 'vehicle_${vehicle.type}'), style: const TextStyle(color: AppColors.acier)),
                  if (vehicle.payloadCapacityKg != null)
                    Text(
                      '${vehicle.payloadCapacityKg!.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontFamily: 'ArchivoCondensed', fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr(context, 'vehicle_status'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: _statusOptions
                .map((s) => ButtonSegment(value: s, label: Text(tr(context, 'status_$s'))))
                .toList(),
            selected: {_status},
            onSelectionChanged: _savingStatus ? null : (s) => _updateStatus(s.first),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.halte)),
          ],
          const SizedBox(height: 24),
          Text(tr(context, 'documents'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._docTypes.map((type) {
            final doc = vehicle.documents.where((d) => d.type == type).toList();
            final expiresAt = doc.isNotEmpty ? doc.first.expiresAt : null;
            final flagged = isExpiringSoon(expiresAt);
            return Card(
              child: ListTile(
                leading: Icon(
                  doc.isNotEmpty ? Icons.description : Icons.upload_file_outlined,
                  color: flagged ? AppColors.halte : AppColors.acier,
                ),
                title: Text(type),
                subtitle: expiresAt != null
                    ? Text(
                        '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}'
                        '${isExpired(expiresAt) ? ' — ${tr(context, 'expired')}' : flagged ? ' — ${tr(context, 'expires_soon')}' : ''}',
                        style: TextStyle(color: flagged ? AppColors.halte : AppColors.acier, fontSize: 12),
                      )
                    : null,
                trailing: TextButton(
                  onPressed: () => _uploadDoc(type),
                  child: Text(tr(context, 'add')),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
