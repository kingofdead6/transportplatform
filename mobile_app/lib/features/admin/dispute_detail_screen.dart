import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';

/// Dispute thread view (ADM-13): messages + post message + admin resolve action.
class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({super.key, required this.disputeId});
  final String disputeId;

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  Map<String, dynamic>? _dispute;
  bool _loading = true;
  String? _error;
  final _messageCtrl = TextEditingController();
  bool _sending = false;

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
      // No single-dispute GET is specified in the contract; fetch the list
      // (unfiltered, admin sees all) and locate this dispute by id.
      final res = await ApiClient.instance.get('/disputes');
      final list = res.data as List;
      final found = list.cast<Map<String, dynamic>>().firstWhere(
            (e) => (e['_id'] ?? '').toString() == widget.disputeId,
            orElse: () => <String, dynamic>{'_id': widget.disputeId, 'messages': []},
          );
      setState(() {
        _dispute = found;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post('/disputes/${widget.disputeId}/messages', data: {'text': text});
      _messageCtrl.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openResolveDialog() async {
    await showDialog(context: context, builder: (_) => _ResolveDialog(disputeId: widget.disputeId));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = context.watch<AuthService>().currentUser?.adminSubRole == 'lecture';
    final dispute = _dispute ?? const {};
    final messages = (dispute['messages'] as List?) ?? const [];
    final status = dispute['status']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'dispute_thread')),
        actions: [
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: StatusBadge(status: status)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (!readOnly && status != 'resolved' && status != 'closed')
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _openResolveDialog,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(tr(context, 'resolve_dispute')),
                          ),
                        ),
                      ),
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Text(tr(context, 'no_disputes'), style: const TextStyle(color: AppColors.acier)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (context, i) {
                                final m = messages[i] as Map<String, dynamic>;
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    constraints: const BoxConstraints(maxWidth: 420),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      border: Border.all(color: const Color(0xFFE2E6E8)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (m['senderRole'] ?? m['senderId'] ?? '').toString(),
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.acier),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(m['text']?.toString() ?? ''),
                                        const SizedBox(height: 4),
                                        Text(
                                          m['createdAt']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 10, color: AppColors.acier),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageCtrl,
                                decoration: InputDecoration(labelText: tr(context, 'write_message')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _sendMessage,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.disputeId});
  final String disputeId;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _resolutionCtrl = TextEditingController();
  String? _newStatus;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'resolve_dispute')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _resolutionCtrl,
              maxLines: 3,
              decoration: InputDecoration(labelText: tr(context, 'resolution')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _newStatus,
              decoration: InputDecoration(labelText: tr(context, 'new_trip_status_optional')),
              items: [
                for (final s in tripLifecycleOrder) DropdownMenuItem(value: s, child: Text(tr(context, 'status_$s'))),
              ],
              onChanged: (v) => setState(() => _newStatus = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr(context, 'cancel'))),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await ApiClient.instance.put('/disputes/${widget.disputeId}/resolve', data: {
                      'resolution': _resolutionCtrl.text.trim(),
                      if (_newStatus != null) 'newTripStatus': _newStatus,
                    });
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    setState(() {
                      _error = tr(context, 'error_generic');
                      _saving = false;
                    });
                  }
                },
          child: Text(tr(context, 'confirm')),
        ),
      ],
    );
  }
}
