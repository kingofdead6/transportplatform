import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/algeria_wilayas.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';

/// Section 5.1: shipper company profile — editable via PUT /api/users/me.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _statisticalIdCtrl;
  late TextEditingController _tradeRegisterCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _contactPersonCtrl;
  late TextEditingController _bankAccountCtrl;
  String? _wilaya;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthService>().currentUser;
    _companyNameCtrl = TextEditingController(text: user?.companyName ?? '');
    _taxIdCtrl = TextEditingController(text: user?.taxId ?? '');
    _statisticalIdCtrl = TextEditingController(text: user?.statisticalId ?? '');
    _tradeRegisterCtrl = TextEditingController(text: user?.tradeRegister ?? '');
    _addressCtrl = TextEditingController(text: user?.address ?? '');
    _contactPersonCtrl = TextEditingController(text: user?.contactPerson ?? '');
    _bankAccountCtrl = TextEditingController(text: user?.bankAccount ?? '');
    _wilaya = user?.wilaya;
    _initialized = true;
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _taxIdCtrl.dispose();
    _statisticalIdCtrl.dispose();
    _tradeRegisterCtrl.dispose();
    _addressCtrl.dispose();
    _contactPersonCtrl.dispose();
    _bankAccountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.put('/users/me', data: {
        'companyName': _companyNameCtrl.text.trim(),
        'taxId': _taxIdCtrl.text.trim(),
        'statisticalId': _statisticalIdCtrl.text.trim(),
        'tradeRegister': _tradeRegisterCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'wilaya': _wilaya,
        'contactPerson': _contactPersonCtrl.text.trim(),
        'bankAccount': _bankAccountCtrl.text.trim(),
      });
      if (!mounted) return;
      await context.read<AuthService>().refreshMe();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'profile_updated'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(tr(context, 'account_status'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                StatusBadge(status: user?.status ?? 'pending'),
              ],
            ),
            const SizedBox(height: 20),
            Text(tr(context, 'company_profile'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _companyNameCtrl,
              decoration: InputDecoration(labelText: tr(context, 'company_name')),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _taxIdCtrl,
              decoration: InputDecoration(labelText: tr(context, 'tax_id')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _statisticalIdCtrl,
              decoration: InputDecoration(labelText: tr(context, 'statistical_id')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tradeRegisterCtrl,
              decoration: InputDecoration(labelText: tr(context, 'trade_register')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: InputDecoration(labelText: tr(context, 'address')),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _wilaya,
              decoration: InputDecoration(labelText: tr(context, 'wilaya')),
              items: algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (v) => setState(() => _wilaya = v),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _contactPersonCtrl,
              decoration: InputDecoration(labelText: tr(context, 'contact_person')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bankAccountCtrl,
              decoration: InputDecoration(labelText: tr(context, 'bank_account')),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(context, 'save')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
