import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/change_password_sheet.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'wilayas.dart';

/// Section 5.2 carrier profile: company/legal fields + operating wilayas
/// (multi-select) + read-only rating. KYC document upload/approval status is
/// handled by PendingApprovalScreen and admin review, not re-implemented here.
class CarrierProfileScreen extends StatefulWidget {
  const CarrierProfileScreen({super.key});

  @override
  State<CarrierProfileScreen> createState() => _CarrierProfileScreenState();
}

class _CarrierProfileScreenState extends State<CarrierProfileScreen> {
  late TextEditingController _companyNameController;
  late TextEditingController _taxIdController;
  late TextEditingController _statisticalIdController;
  late TextEditingController _tradeRegisterController;
  late TextEditingController _addressController;
  late Set<String> _operatingWilayas;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _companyNameController = TextEditingController(text: user?.companyName ?? '');
    _taxIdController = TextEditingController(text: user?.taxId ?? '');
    _statisticalIdController = TextEditingController(text: user?.statisticalId ?? '');
    _tradeRegisterController = TextEditingController(text: user?.tradeRegister ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _operatingWilayas = {...(user?.operatingWilayas ?? const [])};
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxIdController.dispose();
    _statisticalIdController.dispose();
    _tradeRegisterController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.put('/users/me', data: {
        'companyName': _companyNameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'statisticalId': _statisticalIdController.text.trim(),
        'tradeRegister': _tradeRegisterController.text.trim(),
        'address': _addressController.text.trim(),
        'operatingWilayas': _operatingWilayas.toList(),
      });
      if (!mounted) return;
      await context.read<AuthService>().refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'saved'))));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user != null) _RatingCard(rating: user.rating, count: user.ratingCount),
        const SizedBox(height: 20),
        Text(tr(context, 'company_profile'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          controller: _companyNameController,
          decoration: InputDecoration(labelText: tr(context, 'company_name')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taxIdController,
          decoration: InputDecoration(labelText: tr(context, 'tax_id')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _statisticalIdController,
          decoration: InputDecoration(labelText: tr(context, 'statistical_id')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tradeRegisterController,
          decoration: InputDecoration(labelText: tr(context, 'trade_register')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(labelText: tr(context, 'address')),
        ),
        const SizedBox(height: 20),
        Text(tr(context, 'operating_wilayas'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: algeriaWilayas.map((w) {
            final selected = _operatingWilayas.contains(w);
            return FilterChip(
              label: Text(w),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _operatingWilayas.add(w);
                } else {
                  _operatingWilayas.remove(w);
                }
              }),
            );
          }).toList(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.halte)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr(context, 'save')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ChangePasswordSheet.show(context),
          icon: const Icon(Icons.lock_outline_rounded, size: 18),
          label: Text(tr(context, 'change_password')),
        ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.round().clamp(0, 5);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < fullStars ? Icons.star : Icons.star_border,
                  color: AppColors.sangle,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontFamily: 'ArchivoCondensed', fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text('($count ${tr(context, 'ratings_count')})', style: const TextStyle(color: AppColors.acier)),
          ],
        ),
      ),
    );
  }
}
