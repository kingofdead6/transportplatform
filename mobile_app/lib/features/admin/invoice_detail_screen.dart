import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';

/// Invoice detail + "record payment" form (PUT /api/invoices/:id/pay), ADM-15.
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _invoice;
  bool _loading = true;
  String? _error;

  final _amountCtrl = TextEditingController();
  String _method = 'bank_transfer';
  bool _saving = false;

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
      // No single-invoice GET is specified; fetch the list and locate it,
      // which also works if the backend later adds GET /invoices/:id.
      final res = await ApiClient.instance.get('/invoices');
      final list = res.data as List;
      final found = list.cast<Map<String, dynamic>>().firstWhere(
            (e) => (e['_id'] ?? '').toString() == widget.invoiceId,
            orElse: () => <String, dynamic>{},
          );
      setState(() {
        _invoice = found.isNotEmpty ? found : {'_id': widget.invoiceId};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  Future<void> _recordPayment() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.put('/invoices/${widget.invoiceId}/pay', data: {
        'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'method': _method,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'payment_recorded'))));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = context.watch<AuthService>().currentUser?.adminSubRole == 'lecture';
    final inv = _invoice ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(inv['number']?.toString() ?? tr(context, 'invoice_number'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${(inv['totalAmount'] as num?)?.toStringAsFixed(0) ?? 0} DA',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'ArchivoCondensed'),
                          ),
                        ),
                        if ((inv['status'] ?? '').toString().isNotEmpty) StatusBadge(status: inv['status'].toString()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row(tr(context, 'agreed_price'), '${(inv['agreedAmount'] as num?)?.toStringAsFixed(0) ?? 0} DA'),
                            _row(tr(context, 'commission'), '${(inv['commissionAmount'] as num?)?.toStringAsFixed(0) ?? 0} DA'),
                            _row(tr(context, 'vat_percent'), '${(inv['vatPercent'] as num?)?.toStringAsFixed(0) ?? 0}%'),
                            _row(tr(context, 'total_ttc'), '${(inv['totalAmount'] as num?)?.toStringAsFixed(0) ?? 0} DA'),
                          ],
                        ),
                      ),
                    ),
                    if (!readOnly) ...[
                      const SizedBox(height: 24),
                      Text(tr(context, 'record_payment'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tr(context, 'payment_amount')),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: InputDecoration(labelText: tr(context, 'payment_method')),
                        items: [
                          DropdownMenuItem(value: 'cash', child: Text(tr(context, 'method_cash'))),
                          DropdownMenuItem(value: 'bank_transfer', child: Text(tr(context, 'method_bank_transfer'))),
                          DropdownMenuItem(value: 'check', child: Text(tr(context, 'method_check'))),
                          DropdownMenuItem(value: 'cod', child: Text(tr(context, 'method_cod'))),
                        ],
                        onChanged: (v) => setState(() => _method = v ?? 'bank_transfer'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saving ? null : _recordPayment,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(tr(context, 'confirm')),
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
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: AppColors.acier, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
