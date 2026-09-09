import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';

/// Audit tab (ADM-20): read-only trail from GET /api/audit, newest first
/// (API already sorted).
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<dynamic> _entries = const [];
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
      final res = await ApiClient.instance.get('/audit');
      setState(() {
        _entries = res.data as List;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
    if (_entries.isEmpty) return EmptyState(message: tr(context, 'no_audit_entries'), icon: Icons.fact_check_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = _entries[i] as Map<String, dynamic>;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: AppColors.acier),
            title: Text('${e['actorRole'] ?? ''} · ${e['action'] ?? ''}'),
            subtitle: Text([
              if (e['tripId'] != null) 'Trip: ${e['tripId']}',
              if (e['targetType'] != null) '${e['targetType']}: ${e['targetId'] ?? ''}',
            ].join('  ')),
            trailing: Text(
              e['createdAt']?.toString().replaceFirst('T', ' ').split('.').first ?? '',
              style: const TextStyle(fontSize: 11, color: AppColors.acier),
            ),
          );
        },
      ),
    );
  }
}
