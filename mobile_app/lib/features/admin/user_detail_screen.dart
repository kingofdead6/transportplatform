import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';

/// Account detail (GET /api/users/:id) — full profile + vehicle fleet for carriers.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  AppUser? _user;
  List<dynamic> _vehicles = const [];
  bool _loading = true;
  String? _error;

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
      final res = await ApiClient.instance.get('/users/${widget.userId}');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _user = AppUser.fromJson(data['user'] ?? data);
        _vehicles = data['vehicles'] as List? ?? const [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      await ApiClient.instance.put('/users/${widget.userId}/status', data: {'status': status});
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = context.watch<AuthService>().currentUser?.adminSubRole == 'lecture';

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'user_detail'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _user == null
                  ? const SizedBox()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _user!.displayName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ),
                            StatusBadge(status: _user!.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _row(tr(context, 'phone'), _user!.phone),
                                if ((_user!.companyName ?? '').isNotEmpty) _row(tr(context, 'company_name'), _user!.companyName!),
                                if ((_user!.taxId ?? '').isNotEmpty) _row(tr(context, 'tax_id'), _user!.taxId!),
                                if ((_user!.wilaya ?? '').isNotEmpty) _row(tr(context, 'wilaya'), _user!.wilaya!),
                                if (_user!.role == 'carrier' || _user!.role == 'driver')
                                  _row(tr(context, 'rating'), '${_user!.rating.toStringAsFixed(1)} (${_user!.ratingCount} ${tr(context, 'ratings_count')})'),
                                if (_user!.operatingWilayas.isNotEmpty)
                                  _row(tr(context, 'operating_wilayas'), _user!.operatingWilayas.join(', ')),
                                if ((_user!.licenseNumber ?? '').isNotEmpty) _row(tr(context, 'license_number'), _user!.licenseNumber!),
                              ],
                            ),
                          ),
                        ),
                        if (_user!.role == 'carrier' && _vehicles.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(tr(context, 'vehicle_fleet'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          for (final v in _vehicles)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.local_shipping_outlined),
                                title: Text((v['plateNumber'] ?? '').toString()),
                                subtitle: Text('${v['brand'] ?? ''} ${v['model'] ?? ''}'.trim()),
                                trailing: Text(v['status']?.toString() ?? ''),
                              ),
                            ),
                        ],
                        if (!readOnly) ...[
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_user!.status == 'pending') ...[
                                ElevatedButton.icon(
                                  onPressed: () => _setStatus('active'),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(tr(context, 'approve')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _setStatus('rejected'),
                                  icon: const Icon(Icons.cancel_outlined, color: AppColors.halte),
                                  label: Text(tr(context, 'reject')),
                                ),
                              ] else if (_user!.status == 'active')
                                OutlinedButton.icon(
                                  onPressed: () => _setStatus('blocked'),
                                  icon: const Icon(Icons.block, color: AppColors.halte),
                                  label: Text(tr(context, 'block')),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: AppColors.acier, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
