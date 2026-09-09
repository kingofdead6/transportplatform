import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';

/// EXP-04: "مصادقة الإدارة يدويًا على الحساب قبل أول طلب" — shipper/carrier accounts
/// need manual admin approval before their first request.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 56, color: AppColors.sangle),
              const SizedBox(height: 16),
              Text(
                tr(context, 'pending_approval'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre compte sera activé après vérification de vos documents par Prosim Planat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.acier),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.read<AuthService>().logout(),
                child: Text(tr(context, 'logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
