import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/notifications_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'trips_screen.dart';
import 'network_screen.dart';
import 'finance_screen.dart';
import 'disputes_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'audit_screen.dart';

/// Entry point for the admin (company command room) role — section 5.4.
/// Denser control-room UI: NavigationRail on wide screens, Drawer + bottom
/// nav on narrow ones, organized into the four spec groups.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminSection {
  const _AdminSection(this.icon, this.labelKey, this.builder);
  final IconData icon;
  final String labelKey;
  final WidgetBuilder builder;
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  static final List<_AdminSection> _sections = [
    _AdminSection(Icons.dashboard_outlined, 'dashboard', (_) => const DashboardScreen()),
    _AdminSection(Icons.local_shipping_outlined, 'admin_pilotage', (_) => const TripsScreen()),
    _AdminSection(Icons.hub_outlined, 'network', (_) => const NetworkScreen()),
    _AdminSection(Icons.account_balance_wallet_outlined, 'finance', (_) => const FinanceScreen()),
    _AdminSection(Icons.gavel_outlined, 'admin_disputes', (_) => const DisputesScreen()),
    _AdminSection(Icons.bar_chart_outlined, 'admin_reports', (_) => const ReportsScreen()),
    _AdminSection(Icons.settings_outlined, 'settings', (_) => const SettingsScreen()),
    _AdminSection(Icons.fact_check_outlined, 'admin_audit', (_) => const AuditScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final body = _sections[_index].builder(context);

    final appBar = AppBar(
      title: Text(tr(context, 'app_name')),
      actions: [
        const NotificationBell(),
        if (user?.adminSubRole == 'lecture')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              label: Text(tr(context, 'read_only_mode')),
              backgroundColor: AppColors.acier.withValues(alpha: 0.15),
            ),
          ),
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
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.white,
              selectedIconTheme: const IconThemeData(color: AppColors.sangle),
              destinations: [
                for (final s in _sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    label: Text(tr(context, s.labelKey)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.bitume),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  user?.displayName ?? '',
                  style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (int i = 0; i < _sections.length; i++)
              ListTile(
                leading: Icon(_sections[i].icon),
                title: Text(tr(context, _sections[i].labelKey)),
                selected: i == _index,
                selectedColor: AppColors.sangle,
                onTap: () {
                  setState(() => _index = i);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, 4),
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.sangle.withValues(alpha: 0.18),
        destinations: [
          for (final s in _sections.take(5))
            NavigationDestination(icon: Icon(s.icon), label: tr(context, s.labelKey)),
        ],
      ),
    );
  }
}
