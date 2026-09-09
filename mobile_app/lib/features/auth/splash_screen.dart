import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../shipper/shipper_home.dart';
import '../carrier/carrier_home.dart';
import '../driver/driver_home.dart';
import '../admin/admin_home.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoading) {
      return const _SplashBody();
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    final user = auth.currentUser!;
    if (user.status == 'pending' || user.status == 'rejected') {
      return const PendingApprovalScreen();
    }

    switch (user.role) {
      case 'shipper':
        return const ShipperHome();
      case 'carrier':
        return const CarrierHome();
      case 'driver':
        return const DriverHome();
      case 'admin':
        return const AdminHome();
      default:
        return const LoginScreen();
    }
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bitume,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PP',
              style: TextStyle(
                color: AppColors.sangle,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'PROSIM PLANAT',
              style: TextStyle(color: AppColors.white, fontSize: 12, letterSpacing: 4),
            ),
          ],
        ),
      ),
    );
  }
}
