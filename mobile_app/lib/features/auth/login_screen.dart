import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';

/// EXP-01 / TRA / CHA-01: phone + SMS OTP login, no password for end-user roles.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { role, phone, otp }

class _LoginScreenState extends State<LoginScreen> {
  _Step step = _Step.role;
  String? selectedRole;
  final phoneController = TextEditingController(text: '+213');
  final otpController = TextEditingController();
  bool loading = false;
  String? error;
  String? devCode;

  Future<void> sendOtp() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final code = await context.read<AuthService>().requestOtp(phoneController.text.trim());
      setState(() {
        step = _Step.otp;
        devCode = code;
      });
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> verify() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await context.read<AuthService>().verifyOtp(
            phone: phoneController.text.trim(),
            code: otpController.text.trim(),
            role: selectedRole,
          );
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bitume,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: AppColors.white,
                    child: const Text(
                      'PP',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.bitume),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'PROSIM PLANAT',
                    style: TextStyle(color: AppColors.white, letterSpacing: 3, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(child: _buildStep(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (step) {
      case _Step.role:
        return _RoleStep(
          onSelected: (role) => setState(() {
            selectedRole = role;
            step = _Step.phone;
          }),
        );
      case _Step.phone:
        return _PhoneStep(
          controller: phoneController,
          loading: loading,
          error: error,
          onSubmit: sendOtp,
          onBack: () => setState(() => step = _Step.role),
        );
      case _Step.otp:
        return _OtpStep(
          controller: otpController,
          loading: loading,
          error: error,
          devCode: devCode,
          onSubmit: verify,
          onBack: () => setState(() => step = _Step.phone),
        );
    }
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final roles = [
      ('shipper', tr(context, 'role_shipper'), Icons.inventory_2_outlined),
      ('carrier', tr(context, 'role_carrier'), Icons.local_shipping_outlined),
      ('driver', tr(context, 'role_driver'), Icons.badge_outlined),
      ('admin', tr(context, 'role_admin'), Icons.admin_panel_settings_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(context, 'select_role'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...roles.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () => onSelected(r.$1),
              icon: Icon(r.$3),
              label: Align(alignment: Alignment.centerLeft, child: Text(r.$2)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.controller,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back), alignment: Alignment.centerLeft),
        Text(tr(context, 'phone'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: '+213 5XX XX XX XX'),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: AppColors.halte)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: loading ? null : onSubmit,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr(context, 'send_code')),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.loading,
    required this.error,
    required this.devCode,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController controller;
  final bool loading;
  final String? error;
  final String? devCode;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back), alignment: Alignment.centerLeft),
        Text(tr(context, 'verify_code'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        if (devCode != null) ...[
          const SizedBox(height: 8),
          Text('Code (dev): $devCode', style: const TextStyle(color: AppColors.acier)),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '000000'),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: AppColors.halte)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: loading ? null : onSubmit,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr(context, 'verify_code')),
        ),
      ],
    );
  }
}
