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

/// Routes to the right screen based on session + role, once the splash animation is done.
/// Also covers the (rare) case where session restore is still running when the
/// splash's fixed timer fires, so we never flash the login screen incorrectly.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.sangle)),
      );
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
