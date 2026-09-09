import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';

/// Soft pill status chip — color communicates state only, never used for actions.
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _labelsFr[status] ?? status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
