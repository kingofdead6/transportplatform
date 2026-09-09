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
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.sangle.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, size: 40, color: AppColors.sangle),
                ),
                const SizedBox(height: 24),
                Text(
                  tr(context, 'pending_approval'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.bitume),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  tr(context, 'pending_approval_body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.acier, fontSize: 14.5, height: 1.45),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.read<AuthService>().logout(),
                    child: Text(tr(context, 'logout')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
