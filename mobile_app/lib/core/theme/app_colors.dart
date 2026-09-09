import 'package:flutter/widgets.dart';

/// Section 11.2 — palette. One accent color ("Sangle") per screen for the primary action.
/// Never mix Sangle (action) with Convoi/Halte (status) on the same element.
class AppColors {
  AppColors._();

  static const bitume = Color(0xFF16222A); // dark ground, nav, primary text
  static const acier = Color(0xFF3E5261); // secondary text, borders, inactive icons
  static const beton = Color(0xFFF1F3F4); // screen background
  static const sangle = Color(0xFFF2A81D); // action color — one CTA per screen
  static const convoi = Color(0xFF1E7A4F); // delivered / paid / validated / available
  static const halte = Color(0xFFC6382E); // delay / dispute / expired / cancel

  static const white = Color(0xFFFFFFFF);
  static const overlay = Color(0x1416222A);

  static Color statusColor(String status) {
    switch (status) {
      case 'delivered':
      case 'pod_confirmed':
      case 'paid':
      case 'closed':
      case 'available':
      case 'active':
        return convoi;
      case 'cancelled':
      case 'disputed':
      case 'blocked':
      case 'rejected':
      case 'expired':
        return halte;
      case 'en_route_pickup':
      case 'en_route_delivery':
      case 'loaded':
      case 'arrived_delivery':
      case 'on_mission':
        return sangle;
      default:
        return acier;
    }
  }
}
