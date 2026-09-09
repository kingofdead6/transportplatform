import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import 'invoice_detail_screen.dart';

/// Finance tab (ADM-14..18): invoices list, overdue sub-view, margins report.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppColors.bitume,
          indicatorColor: AppColors.sangle,
          isScrollable: true,
          tabs: [
            Tab(text: tr(context, 'invoices')),
            Tab(text: tr(context, 'overdue_invoices')),
            Tab(text: tr(context, 'margins_report')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _InvoicesList(),
              _OverdueInvoicesList(),
              _MarginsReport(),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoicesList extends StatefulWidget {
  const _InvoicesList();

  @override
  State<_InvoicesList> createState() => _InvoicesListState();
}

class _InvoicesListState extends State<_InvoicesList> {
  List<dynamic> _invoices = const [];
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
      final res = await ApiClient.instance.get('/invoices');
      setState(() {
        _invoices = res.data as List;
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
    if (_error != null) return Center(child: Text(_error!));
    if (_invoices.isEmpty) return EmptyState(message: tr(context, 'no_invoices_yet'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final inv = _invoices[i] as Map<String, dynamic>;
          return Card(
            child: ListTile(
              title: Text(inv['number']?.toString() ?? ''),
              subtitle: Text('${(inv['totalAmount'] as num?)?.toStringAsFixed(0) ?? 0} DA'),
              trailing: StatusBadge(status: inv['status']?.toString() ?? ''),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: (inv['_id'] ?? '').toString())),
                );
                _load();
              },
            ),
          );
        },
      ),
    );
  }
}

class _OverdueInvoicesList extends StatefulWidget {
  const _OverdueInvoicesList();

  @override
  State<_OverdueInvoicesList> createState() => _OverdueInvoicesListState();
}

class _OverdueInvoicesListState extends State<_OverdueInvoicesList> {
  List<dynamic> _invoices = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/invoices/overdue');
      setState(() {
        _invoices = res.data as List;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _remind(String id) async {
    try {
      await ApiClient.instance.put('/invoices/$id/remind');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'reminder_sent'))));
        _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_invoices.isEmpty) return EmptyState(message: tr(context, 'no_invoices_yet'), icon: Icons.event_available_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final inv = _invoices[i] as Map<String, dynamic>;
          return Card(
            child: ListTile(
              title: Text(inv['number']?.toString() ?? ''),
              subtitle: Text('${tr(context, 'due_date')}: ${inv['dueDate'] ?? '-'}'),
              trailing: TextButton(
                onPressed: () => _remind((inv['_id'] ?? '').toString()),
                child: Text(tr(context, 'send_reminder')),
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: (inv['_id'] ?? '').toString())),
                );
                _load();
              },
            ),
          );
        },
      ),
    );
  }
}

class _MarginsReport extends StatefulWidget {
  const _MarginsReport();

  @override
  State<_MarginsReport> createState() => _MarginsReportState();
}

class _MarginsReportState extends State<_MarginsReport> {
  List<dynamic> _rows = const [];
  Map<String, dynamic> _totals = const {};
  bool _loading = true;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final query = <String, dynamic>{};
      if (_from != null) query['from'] = _from!.toIso8601String();
      if (_to != null) query['to'] = _to!.toIso8601String();
      final res = await ApiClient.instance.get('/reports/margins', query: query);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _rows = data['rows'] as List? ?? const [];
        _totals = (data['totals'] as Map<String, dynamic>?) ?? const {};
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _pickDate(isFrom: true),
                child: Text('${tr(context, 'from_date')}: ${_from != null ? _from!.toIso8601String().split('T').first : '-'}'),
              ),
              OutlinedButton(
                onPressed: () => _pickDate(isFrom: false),
                child: Text('${tr(context, 'to_date')}: ${_to != null ? _to!.toIso8601String().split('T').first : '-'}'),
              ),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'export_note'))));
                },
                icon: const Icon(Icons.file_download_outlined),
                label: Text(tr(context, 'export')),
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: _rows.isEmpty
                ? EmptyState(message: tr(context, 'no_trips_found'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(tr(context, 'mission_reference'))),
                          const DataColumn(label: Text('Shipper')),
                          DataColumn(label: Text(tr(context, 'carrier'))),
                          const DataColumn(label: Text('Corridor')),
                          DataColumn(label: Text(tr(context, 'agreed_price'))),
                          DataColumn(label: Text(tr(context, 'commission'))),
                        ],
                        rows: [
                          for (final r in _rows)
                            DataRow(cells: [
                              DataCell(Text(r['reference']?.toString() ?? '')),
                              DataCell(Text(r['shipper']?.toString() ?? '')),
                              DataCell(Text(r['carrier']?.toString() ?? '')),
                              DataCell(Text(r['corridor']?.toString() ?? '')),
                              DataCell(Text('${(r['agreedPrice'] as num?)?.toStringAsFixed(0) ?? 0}')),
                              DataCell(Text('${(r['commission'] as num?)?.toStringAsFixed(0) ?? 0}')),
                            ]),
                        ],
                      ),
                    ),
                  ),
          ),
        if (!_loading && _totals.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.white,
            child: Wrap(
              spacing: 24,
              children: [
                Text(
                  '${tr(context, 'total_revenue')}: ${(_totals['totalRevenue'] as num?)?.toStringAsFixed(0) ?? 0} DA',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${tr(context, 'stat_total_commission')}: ${(_totals['totalCommission'] as num?)?.toStringAsFixed(0) ?? 0} DA',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
