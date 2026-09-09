import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import 'incident_screen.dart';
import 'mission_action_button.dart';
import 'mission_history_screen.dart';
import 'mission_timeline.dart';
import 'offline_indicator.dart';
import 'pod_screen.dart';

/// CHA-02: the driver's single "mission of the day" screen. Deliberately minimalist —
/// one route line, contacts, instructions, and exactly ONE 64px full-width action button
/// whose label/behavior is driven by the current mission's trip.status.
class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

/// Statuses considered part of an "active" driver mission, in order.
const List<String> _activeDriverStatuses = [
  'driver_assigned',
  'en_route_pickup',
  'loaded',
  'en_route_delivery',
  'arrived_delivery',
];

class _DriverHomeState extends State<DriverHome> {
  final _tripService = TripService();

  Trip? _trip;
  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;

  Timer? _locationTimer;
  String? _trackedTripId;

  @override
  void initState() {
    super.initState();
    _loadMission();
  }

  @override
  void dispose() {
    _stopLocationTimer();
    super.dispose();
  }

  Future<void> _loadMission() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await _tripService.listTrips();
      Trip? current;
      for (final t in trips) {
        if (_activeDriverStatuses.contains(t.status)) {
          current = t;
          break;
        }
      }
      // Also consider "just delivered" so the driver briefly sees the completion state.
      current ??= trips
          .where((t) => t.status == 'delivered' || t.status == 'pod_confirmed')
          .fold<Trip?>(null, (best, t) {
        if (best == null) return t;
        final bestDate = best.createdAt ?? DateTime(0);
        final tDate = t.createdAt ?? DateTime(0);
        return tDate.isAfter(bestDate) ? t : best;
      });

      if (!mounted) return;
      setState(() {
        _trip = current;
        _loading = false;
      });
      _syncLocationTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr(context, 'error_generic');
      });
    }
  }

  void _syncLocationTimer() {
    final trip = _trip;
    final shouldTrack = trip != null &&
        (trip.status == 'en_route_pickup' || trip.status == 'en_route_delivery');

    if (!shouldTrack) {
      _stopLocationTimer();
      return;
    }
    if (_trackedTripId == trip.id && _locationTimer != null) return;

    _stopLocationTimer();
    _trackedTripId = trip.id;
    SocketService.instance.trackTrip(trip.id);
    _locationTimer = Timer.periodic(const Duration(seconds: 45), (_) => _pingLocation(trip.id));
  }

  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (_trackedTripId != null) {
      SocketService.instance.leaveTrip(_trackedTripId!);
      _trackedTripId = null;
    }
  }

  Future<void> _pingLocation(String tripId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      await _tripService.pingLocation(tripId, pos.latitude, pos.longitude);
      SocketService.instance.sendLocation(tripId, pos.latitude, pos.longitude);
    } catch (_) {
      // best-effort; ignore GPS failures during background pings
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _advanceStatus(String newStatus) async {
    final trip = _trip;
    if (trip == null || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final pos = await _getCurrentPosition();
      await _tripService.updateStatus(trip.id, newStatus, lat: pos?.latitude, lng: pos?.longitude);
      if (pos != null) {
        SocketService.instance.sendLocation(trip.id, pos.latitude, pos.longitude);
      }
      await _loadMission();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'error_generic'))),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleLoadingDone() async {
    final trip = _trip;
    if (trip == null || _actionInProgress) return;

    final picker = ImagePicker();
    final photos = <XFile>[];
    final firstPhoto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (firstPhoto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'photos_required'))),
        );
      }
      return;
    }
    photos.add(firstPhoto);

    setState(() => _actionInProgress = true);
    try {
      final form = FormData();
      for (var i = 0; i < photos.length; i++) {
        form.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(photos[i].path, filename: 'load_photo_$i.jpg'),
        ));
      }
      await ApiClient.instance.uploadForm('/trips/${trip.id}/documents/photos', form);

      final pos = await _getCurrentPosition();
      await _tripService.updateStatus(trip.id, 'loaded', lat: pos?.latitude, lng: pos?.longitude);
      if (pos != null) {
        SocketService.instance.sendLocation(trip.id, pos.latitude, pos.longitude);
      }
      await _loadMission();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'error_generic'))),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _openPod() async {
    final trip = _trip;
    if (trip == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PodScreen(tripId: trip.id)),
    );
    if (result == true) {
      await _loadMission();
    }
  }

  Future<void> _callShipper(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openIncident() {
    final trip = _trip;
    if (trip == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => IncidentScreen(tripId: trip.id)),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MissionHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.beton,
      appBar: AppBar(
        title: Text(tr(context, 'today_mission')),
        actions: [
          if (_trip != null)
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded),
              tooltip: tr(context, 'report_incident'),
              onPressed: _openIncident,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: tr(context, 'mission_history'),
            onPressed: _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: tr(context, 'logout'),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMission,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(message: _error!, icon: Icons.error_outline),
        ],
      );
    }
    final trip = _trip;
    if (trip == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(message: tr(context, 'no_active_trip')),
        ],
      );
    }

    final isDone = trip.status == 'delivered' || trip.status == 'pod_confirmed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OfflineIndicator(),
          _RouteHeader(trip: trip),
          const SizedBox(height: 16),
          _ContactCard(trip: trip, onCall: _callShipper),
          const SizedBox(height: 16),
          _InstructionsCard(trip: trip),
          const SizedBox(height: 24),
          Text(
            tr(context, 'progress'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          MissionTimeline(currentStatus: trip.status),
          const SizedBox(height: 12),
          if (isDone)
            _CompletionCard(onBackHome: () => setState(() => _trip = null))
          else
            MissionActionButton(
              label: _actionLabel(context, trip.status),
              loading: _actionInProgress,
              onPressed: () => _handleAction(trip.status),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _actionLabel(BuildContext context, String status) {
    switch (status) {
      case 'driver_assigned':
        return tr(context, 'departed_pickup');
      case 'en_route_pickup':
        return tr(context, 'loading_done');
      case 'loaded':
        return tr(context, 'en_route');
      case 'en_route_delivery':
        return tr(context, 'arrived_dropoff');
      case 'arrived_delivery':
        return tr(context, 'delivery_done');
      default:
        return tr(context, 'confirm');
    }
  }

  Future<void> _handleAction(String status) async {
    switch (status) {
      case 'driver_assigned':
        await _advanceStatus('en_route_pickup');
        break;
      case 'en_route_pickup':
        await _handleLoadingDone();
        break;
      case 'loaded':
        await _advanceStatus('en_route_delivery');
        break;
      case 'en_route_delivery':
        await _advanceStatus('arrived_delivery');
        break;
      case 'arrived_delivery':
        await _openPod();
        break;
    }
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bitume,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.pickup.wilaya ?? '-'}  →  ${trip.dropoff.wilaya ?? '-'}',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${tr(context, 'mission_reference')}: ${trip.reference}',
            style: TextStyle(color: AppColors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.trip, required this.onCall});

  final Trip trip;
  final void Function(String phone) onCall;

  // NOTE: the Trip model (lib/core/models/trip.dart) does not currently expose a
  // shipper phone number field (only shipperName, populated from shipperId). The call
  // button is wired up and ready — pass a real number here once the backend/Trip model
  // surfaces one (e.g. trip.shipperPhone) so `onCall` can launch the tel: intent.
  String? get _shipperPhone => null;

  @override
  Widget build(BuildContext context) {
    final shipperName = trip.shipperName ?? tr(context, 'role_shipper');
    final phone = _shipperPhone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E6E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.acier),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shipperName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (phone != null)
            OutlinedButton.icon(
              onPressed: () => onCall(phone),
              icon: const Icon(Icons.call, size: 18),
              label: Text(tr(context, 'call_shipper')),
            ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = (trip.specialInstructions?.trim().isNotEmpty ?? false)
        ? trip.specialInstructions!.trim()
        : tr(context, 'special_instructions_none');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E6E8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.acier),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.onBackHome});

  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.convoi.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.convoi.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.convoi, size: 40),
          const SizedBox(height: 10),
          Text(
            tr(context, 'mission_completed'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.convoi),
          ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'mission_completed_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.acier),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onBackHome,
            child: Text(tr(context, 'back_to_home')),
          ),
        ],
      ),
    );
  }
}
