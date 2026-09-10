import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosim_planat/core/l10n/app_strings.dart';
import 'package:prosim_planat/core/models/trip.dart';
import 'package:prosim_planat/core/services/notification_service.dart';
import 'package:prosim_planat/core/theme/app_theme.dart';
import 'package:prosim_planat/core/widgets/status_badge.dart';
import 'package:prosim_planat/core/widgets/trip_card.dart';

/// Wraps a widget in the same localisation/theme scaffolding the app provides.
Widget host(Widget child, {String locale = 'fr'}) {
  return AppStrings(
    locale: Locale(locale),
    child: MaterialApp(
      theme: AppTheme.light(locale),
      locale: Locale(locale),
      home: Directionality(
        textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    ),
  );
}

Trip tripFrom(Map<String, dynamic> json) => Trip.fromJson(json);

void main() {
  group('Trip model', () {
    test('exposes the shipper phone so the driver can place a call', () {
      final trip = tripFrom({
        '_id': 't1',
        'reference': 'PP-2026-000001',
        'status': 'driver_assigned',
        'shipperId': {'_id': 's1', 'companyName': 'Acme', 'phone': '+213555000111'},
        'pickup': {'wilaya': 'Alger'},
        'dropoff': {'wilaya': 'Oran'},
      });

      expect(trip.shipperPhone, '+213555000111');
      expect(trip.shipperName, 'Acme');
    });

    test('maps incidentReports (backend field) into incidents', () {
      final trip = tripFrom({
        '_id': 't1',
        'reference': 'R',
        'status': 'loaded',
        'pickup': {},
        'dropoff': {},
        'incidentReports': [
          {'type': 'breakdown', 'note': 'Panne moteur', 'reportedAt': '2026-01-01T10:00:00.000Z'},
        ],
      });

      expect(trip.incidents, hasLength(1));
      expect(trip.incidents.first.type, 'breakdown');
      expect(trip.incidents.first.note, 'Panne moteur');
    });

    test('lastKnownLocation is null until a real position exists', () {
      final none = tripFrom({
        '_id': 't', 'reference': 'R', 'status': 'draft',
        'pickup': {}, 'dropoff': {},
      });
      expect(none.lastKnownLocation, isNull);

      final empty = tripFrom({
        '_id': 't', 'reference': 'R', 'status': 'draft',
        'pickup': {}, 'dropoff': {}, 'lastKnownLocation': {},
      });
      expect(empty.lastKnownLocation, isNull,
          reason: 'an empty position object must not read as a real fix');

      final real = tripFrom({
        '_id': 't', 'reference': 'R', 'status': 'en_route_delivery',
        'pickup': {}, 'dropoff': {},
        'lastKnownLocation': {'lat': 36.7, 'lng': 3.1},
      });
      expect(real.lastKnownLocation?.lat, 36.7);
    });

    test('hasReview reflects an existing rating', () {
      final reviewed = tripFrom({
        '_id': 't', 'reference': 'R', 'status': 'pod_confirmed',
        'pickup': {}, 'dropoff': {},
        'review': {'rating': 5, 'createdAt': '2026-01-01T00:00:00.000Z'},
      });
      expect(reviewed.hasReview, isTrue);

      final notReviewed = tripFrom({
        '_id': 't', 'reference': 'R', 'status': 'pod_confirmed',
        'pickup': {}, 'dropoff': {},
      });
      expect(notReviewed.hasReview, isFalse);
    });

    test('reads ids whether populated or raw', () {
      final trip = tripFrom({
        '_id': 't', 'reference': 'R', 'status': 'assigned',
        'pickup': {}, 'dropoff': {},
        'assignedCarrierId': {'_id': 'c1', 'companyName': 'Carrier', 'phone': '+2135'},
        'assignedDriverId': 'd1',
      });
      expect(trip.assignedCarrierId, 'c1');
      expect(trip.carrierPhone, '+2135');
      expect(trip.assignedDriverId, 'd1');
      expect(trip.driverPhone, isNull);
    });
  });

  group('StatusBadge localisation', () {
    testWidgets('renders French labels', (tester) async {
      await tester.pumpWidget(host(const StatusBadge(status: 'delivered')));
      expect(find.text('Livré'), findsOneWidget);
    });

    testWidgets('renders Arabic labels in an RTL locale', (tester) async {
      await tester.pumpWidget(host(const StatusBadge(status: 'delivered'), locale: 'ar'));
      // Previously hardcoded to French, so Arabic users saw "Livré".
      expect(find.text('Livré'), findsNothing);
      expect(find.text('تم التسليم'), findsOneWidget);
    });

    testWidgets('renders English labels', (tester) async {
      await tester.pumpWidget(host(const StatusBadge(status: 'delivered'), locale: 'en'));
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('falls back to the raw code for an unknown status', (tester) async {
      await tester.pumpWidget(host(const StatusBadge(status: 'weird_status')));
      expect(find.text('weird_status'), findsOneWidget);
    });
  });

  group('TripCard', () {
    testWidgets('shows route, reference and price', (tester) async {
      final trip = tripFrom({
        '_id': 't1',
        'reference': 'PP-2026-000042',
        'status': 'published',
        'pickup': {'wilaya': 'Alger'},
        'dropoff': {'wilaya': 'Oran'},
        'weightKg': 12000,
      });

      await tester.pumpWidget(host(TripCard(trip: trip, trailingPrice: '50000 DA')));

      expect(find.textContaining('Alger'), findsOneWidget);
      expect(find.text('PP-2026-000042'), findsOneWidget);
      expect(find.text('12000 kg'), findsOneWidget);
      expect(find.text('50000 DA'), findsOneWidget);
    });

    testWidgets('is tappable', (tester) async {
      var tapped = false;
      final trip = tripFrom({
        '_id': 't1', 'reference': 'R', 'status': 'published',
        'pickup': {'wilaya': 'A'}, 'dropoff': {'wilaya': 'B'},
      });

      await tester.pumpWidget(host(TripCard(trip: trip, onTap: () => tapped = true)));
      await tester.tap(find.byType(TripCard));
      expect(tapped, isTrue);
    });
  });

  group('Notifications', () {
    test('unread count tracks read state', () {
      final service = NotificationService();
      addTearDown(service.dispose);
      expect(service.unreadCount, 0);
    });

    test('parses a notification payload', () {
      final n = AppNotification.fromJson({
        '_id': 'n1',
        'type': 'new_offer',
        'title': 'Nouvelle offre',
        'body': 'Offre reçue',
        'read': false,
        'isCritical': true,
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(n.type, 'new_offer');
      expect(n.isCritical, isTrue);
      expect(n.read, isFalse);
      expect(n.copyWith(read: true).read, isTrue);
    });
  });

  group('Translations', () {
    testWidgets('every language resolves the keys used by new features',
        (tester) async {
      for (final locale in ['fr', 'en', 'ar']) {
        await tester.pumpWidget(host(
          Builder(
            builder: (context) => Column(
              children: [
                for (final key in [
                  'accept_load',
                  'load_accepted',
                  'call',
                  'cancel_trip',
                  'notifications_empty',
                  'password',
                  'change_password',
                  'no_results',
                  'status_suspended',
                ])
                  Text('$key=${tr(context, key)}'),
              ],
            ),
          ),
          locale: locale,
        ));

        // A missing key falls through to the key itself.
        expect(find.textContaining('=accept_load'), findsNothing,
            reason: 'accept_load missing in $locale');
        expect(find.textContaining('=no_results'), findsNothing,
            reason: 'no_results missing in $locale');
        expect(find.textContaining('=status_suspended'), findsNothing,
            reason: 'status_suspended missing in $locale');
      }
    });
  });
}
