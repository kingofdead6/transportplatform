import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/notifications_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/theme/app_colors.dart';
import 'marketplace_screen.dart';
import 'my_trips_screen.dart';
import 'fleet_screen.dart';
import 'profile_screen.dart';

/// Entry point for the carrier (transporteur) role. Section 5.2 — bottom nav:
/// Marketplace, My trips, Fleet (vehicles+drivers), Profile.
class CarrierHome extends StatefulWidget {
  const CarrierHome({super.key});

  @override
  State<CarrierHome> createState() => _CarrierHomeState();
}

class _CarrierHomeState extends State<CarrierHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      MarketplaceScreen(),
      MyTripsScreen(),
      FleetScreen(),
      CarrierProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'app_name')),
        actions: [
          const NotificationBell(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: tr(context, 'language'),
            onSelected: (code) => context.read<LocaleService>().setLocale(code),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'fr', child: Text('Français')),
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'ar', child: Text('العربية')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: tr(context, 'logout'),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.sangle.withValues(alpha: 0.18),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront, color: AppColors.bitume),
            label: tr(context, 'marketplace'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping, color: AppColors.bitume),
            label: tr(context, 'my_trips'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.garage_outlined),
            selectedIcon: const Icon(Icons.garage, color: AppColors.bitume),
            label: tr(context, 'fleet'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppColors.bitume),
            label: tr(context, 'profile'),
          ),
        ],
      ),
    );
  }
}
