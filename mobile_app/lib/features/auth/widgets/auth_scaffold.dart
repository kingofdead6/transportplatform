import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Shared layout for login/register: brand mark + headline up top, form card below,
/// scrollable so it works on small screens with the keyboard open.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.showBrand = true,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final bool showBrand;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leading != null) leading!,
                    SizedBox(height: showBrand ? 24 : 12),
                    if (showBrand) ...[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.sangle,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sangle.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: AppColors.white, size: 30),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.bitume,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14.5, color: AppColors.acier, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    form,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
