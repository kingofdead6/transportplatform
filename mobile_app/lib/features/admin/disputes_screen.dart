import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import 'dispute_detail_screen.dart';

/// Disputes tab (ADM-13): list, filter by status, tap -> thread view.
class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<dynamic> _disputes = const [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const _statuses = ['open', 'in_review', 'resolved', 'closed'];

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
      final query = _statusFilter != null ? {'status': _statusFilter} : null;
      final res = await ApiClient.instance.get('/disputes', query: query);
      setState(() {
        _disputes = res.data as List;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  String _statusKey(String s) => s == 'closed' ? 'status_closed_dispute' : 'status_$s';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: Text(tr(context, 'all_statuses')),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    _load();
                  },
                ),
                for (final s in _statuses)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(tr(context, _statusKey(s))),
                      selected: _statusFilter == s,
                      onSelected: (_) {
                        setState(() => _statusFilter = s);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _disputes.isEmpty
                      ? EmptyState(message: tr(context, 'no_disputes'), icon: Icons.gavel_outlined)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _disputes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final d = _disputes[i] as Map<String, dynamic>;
                              final status = d['status']?.toString() ?? '';
                              return Card(
                                child: ListTile(
                                  leading: Container(width: 4, height: 40, color: AppColors.statusColor(status)),
                                  title: Text(d['tripId']?.toString() ?? d['_id']?.toString() ?? ''),
                                  subtitle: Text(d['reason']?.toString() ?? ''),
                                  trailing: StatusBadge(status: status),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DisputeDetailScreen(disputeId: (d['_id'] ?? '').toString()),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
