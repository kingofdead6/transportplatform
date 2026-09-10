import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

/// Section 5.2: carrier adds a driver to their roster. POST /api/users/drivers.
class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '+213');
  final _nameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _licenseCategoryController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  DateTime? _licenseExpiresAt;
  bool _loading = false;
  String? _error;

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 15)),
    );
    if (picked != null) setState(() => _licenseExpiresAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/users/drivers', data: {
        'phone': _phoneController.text.trim(),
        'fullName': _nameController.text.trim(),
        'password': _passwordController.text,
        if (_licenseNumberController.text.trim().isNotEmpty)
          'licenseNumber': _licenseNumberController.text.trim(),
        if (_licenseCategoryController.text.trim().isNotEmpty)
          'licenseCategory': _licenseCategoryController.text.trim(),
        if (_licenseExpiresAt != null) 'licenseExpiresAt': _licenseExpiresAt!.toIso8601String(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _licenseNumberController.dispose();
    _licenseCategoryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'add_driver'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: tr(context, 'full_name')),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr(context, 'phone')),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr(context, 'required_field') : null,
            ),
            const SizedBox(height: 12),
            // Drivers sign in with phone + password like every other role. The
            // account used to be created without one, so it could never log in.
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: tr(context, 'password'),
                helperText: tr(context, 'driver_password_hint'),
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.acier,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return tr(context, 'required_field');
                if (v.length < 6) return tr(context, 'password_too_short');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _licenseNumberController,
              decoration: InputDecoration(labelText: tr(context, 'license_number')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _licenseCategoryController,
              decoration: InputDecoration(labelText: tr(context, 'license_category')),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickExpiry,
              child: InputDecorator(
                decoration: InputDecoration(labelText: tr(context, 'license_expiry')),
                child: Text(
                  _licenseExpiresAt == null
                      ? tr(context, 'select_date')
                      : '${_licenseExpiresAt!.day}/${_licenseExpiresAt!.month}/${_licenseExpiresAt!.year}',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.halte)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}
