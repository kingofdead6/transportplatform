import 'package:flutter/widgets.dart';

/// Clean, light, minimal palette. One accent color ("Sangle") per screen for the
/// primary action — status colors (Convoi/Halte) are reserved for state, never actions.
class AppColors {
  AppColors._();

  // Ink — primary text, headings, nav bar. A soft near-black, not pure black.
  static const bitume = Color(0xFF1A2027);
  // Secondary text, borders, inactive icons.
  static const acier = Color(0xFF8A93A0);
  // Screen background — warm off-white, not stark white.
  static const beton = Color(0xFFF7F8FA);
  // Accent — the one CTA color per screen.
  static const sangle = Color(0xFFFF8A34);
  // Success / delivered / paid / available.
  static const convoi = Color(0xFF17A673);
  // Delay / dispute / expired / cancel.
  static const halte = Color(0xFFE5484D);

  static const white = Color(0xFFFFFFFF);
  static const overlay = Color(0x0A1A2027);
  static const border = Color(0xFFE9EBEF);
  static const surfaceAlt = Color(0xFFEFF1F4);

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
