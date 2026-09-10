import '../models/trip.dart';
import '../network/api_client.dart';
import '../network/offline_queue.dart';

class TripService {
  final _api = ApiClient.instance;

  Future<List<Trip>> listTrips({Map<String, dynamic>? query}) async {
    final res = await _api.get('/trips', query: query);
    return (res.data as List).map((e) => Trip.fromJson(e)).toList();
  }

  Future<Trip> getTrip(String id) async {
    final res = await _api.get('/trips/$id');
    return Trip.fromJson(res.data);
  }

  Future<Trip> createTrip(Map<String, dynamic> body) async {
    final res = await _api.post('/trips', data: body);
    return Trip.fromJson(res.data);
  }

  Future<Trip> publishTrip(String id) async {
    final res = await _api.put('/trips/$id/publish');
    return Trip.fromJson(res.data);
  }

  Future<Trip> submitOffer(String tripId, Map<String, dynamic> body) async {
    final res = await _api.post('/trips/$tripId/offers', data: body);
    return Trip.fromJson(res.data);
  }

  /// Carrier takes a fixed-price load directly (no bidding round).
  Future<Trip> acceptFixedPrice(String tripId) async {
    final res = await _api.put('/trips/$tripId/accept');
    return Trip.fromJson(res.data);
  }

  Future<Trip> assignCarrier(String tripId, Map<String, dynamic> body) async {
    final res = await _api.put('/trips/$tripId/assign', data: body);
    return Trip.fromJson(res.data);
  }

  Future<Trip> assignDriver(String tripId, {required String driverId, String? vehicleId}) async {
    final res = await _api.put(
      '/trips/$tripId/assign-driver',
      data: {'driverId': driverId, if (vehicleId != null) 'vehicleId': vehicleId},
    );
    return Trip.fromJson(res.data);
  }

  Future<Trip> cancelTrip(String tripId, {String? reason}) async {
    final res = await _api.put('/trips/$tripId/cancel', data: {if (reason != null) 'reason': reason});
    return Trip.fromJson(res.data);
  }

  /// Queues the status update if offline (CHA-12), sends immediately otherwise.
  /// Returns null when the update was queued rather than sent.
  Future<Trip?> updateStatus(
    String tripId,
    String status, {
    double? lat,
    double? lng,
    String? note,
  }) async {
    final body = {
      'status': status,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (note != null) 'note': note,
    };
    try {
      final res = await _api.put('/trips/$tripId/status', data: body);
      return Trip.fromJson(res.data);
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        await OfflineQueue.instance.enqueue(
          QueuedAction(
            method: 'PUT',
            path: '/trips/$tripId/status',
            body: body,
            createdAt: DateTime.now(),
          ),
        );
        return null;
      }
      rethrow;
    }
  }

  Future<void> pingLocation(String tripId, double lat, double lng) async {
    try {
      await _api.post('/trips/$tripId/ping', data: {'lat': lat, 'lng': lng});
    } on ApiException catch (e) {
      // Only a genuine connectivity failure is worth replaying; a rejected ping
      // would just fail again later.
      if (e.isNetworkError) {
        await OfflineQueue.instance.enqueue(
          QueuedAction(
            method: 'POST',
            path: '/trips/$tripId/ping',
            body: {'lat': lat, 'lng': lng},
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<Trip> confirmPod(String tripId) async {
    final res = await _api.put('/trips/$tripId/confirm-pod');
    return Trip.fromJson(res.data);
  }

  Future<void> reviewTrip(String tripId, Map<String, dynamic> body) async {
    await _api.post('/trips/$tripId/review', data: body);
  }

  Future<void> reportIncident(String tripId, Map<String, dynamic> body) async {
    try {
      await _api.post('/trips/$tripId/incidents', data: body);
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        await OfflineQueue.instance.enqueue(
          QueuedAction(
            method: 'POST',
            path: '/trips/$tripId/incidents',
            body: body,
            createdAt: DateTime.now(),
          ),
        );
        return;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> listDocuments(String tripId) async {
    final res = await _api.get('/trips/$tripId/documents');
    return res.data is List ? res.data as List : const [];
  }

  Future<List<Trip>> getReturnLoads() async {
    final res = await _api.get('/trips/return-loads');
    return (res.data['matches'] as List? ?? []).map((e) => Trip.fromJson(e)).toList();
  }
}
