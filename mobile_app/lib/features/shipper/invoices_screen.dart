import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';

/// Section 5.1: shipper's invoices — GET /api/invoices auto-filtered server-side.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];
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
      final data = res.data;
      setState(() => _invoices = data is List ? data : (data['invoices'] as List? ?? []));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.halte)),
        ),
      );
    }
    if (_invoices.isEmpty) {
      return EmptyState(message: tr(context, 'no_invoices_yet'), icon: Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final inv = _invoices[i] as Map;
          final number = inv['number']?.toString() ?? '-';
          final total = (inv['totalAmount'] as num?)?.toDouble();
          final status = inv['status']?.toString() ?? 'draft';
          final pdfUrl = inv['pdfUrl']?.toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr(context, 'invoice_number')} $number',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        if (total != null)
                          Text(
                            '${total.toStringAsFixed(0)} DA',
                            style: const TextStyle(
                              fontFamily: 'ArchivoCondensed',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusBadge(status: status),
                  if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.acier),
                      tooltip: tr(context, 'view_pdf'),
                      onPressed: () async {
                        final uri = Uri.tryParse(pdfUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
