import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';

/// Section 11.6: 2px radius status chips, color = status only, never used for actions.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static const Map<String, String> _labelsFr = {
    'draft': 'Brouillon',
    'published': 'Publiée',
    'offers_received': 'Offres reçues',
    'assigned': 'Attribuée',
    'driver_assigned': 'Chauffeur assigné',
    'en_route_pickup': 'Vers chargement',
    'loaded': 'Chargé',
    'en_route_delivery': 'En route',
    'arrived_delivery': 'Arrivé',
    'delivered': 'Livré',
    'pod_confirmed': 'Confirmé',
    'invoiced': 'Facturée',
    'paid': 'Payée',
    'closed': 'Clôturée',
    'cancelled': 'Annulée',
    'disputed': 'Litige',
    'suspended': 'Suspendue',
  };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _labelsFr[status] ?? status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
