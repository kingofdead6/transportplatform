import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/notifications_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/locale_service.dart';
import 'trip_list_screen.dart';
import 'new_trip_screen.dart';
import 'invoices_screen.dart';
import 'profile_screen.dart';

/// Entry point for the shipper (chargeur) role — section 5.1.
/// Bottom navigation: Trips / New trip / Invoices / Profile.
class ShipperHome extends StatefulWidget {
  const ShipperHome({super.key});

  @override
  State<ShipperHome> createState() => _ShipperHomeState();
}

class _ShipperHomeState extends State<ShipperHome> {
  int _index = 0;
  int _tripListRefreshKey = 0;

  void _goToTrips() {
    setState(() {
      _index = 0;
      _tripListRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TripListScreen(key: ValueKey(_tripListRefreshKey)),
      NewTripScreen(onDone: _goToTrips),
      const InvoicesScreen(),
      const ProfileScreen(),
    ];

    final titles = [
      tr(context, 'trips'),
      tr(context, 'new_trip'),
      tr(context, 'invoices'),
      tr(context, 'profile'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          const NotificationBell(),
          const _LanguageSwitcher(),
          IconButton(
            tooltip: tr(context, 'logout'),
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_shipping_outlined),
            label: tr(context, 'trips'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_box_outlined),
            label: tr(context, 'new_trip'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            label: tr(context, 'invoices'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: tr(context, 'profile'),
          ),
        ],
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleService>().locale.languageCode;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: tr(context, 'language'),
      initialValue: current,
      onSelected: (code) => context.read<LocaleService>().setLocale(code),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'fr', child: Text('Français')),
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'ar', child: Text('العربية')),
      ],
    );
  }
}
