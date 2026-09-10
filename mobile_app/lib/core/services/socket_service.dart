import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

/// Real-time channel: `notification` events per user, `trip:location` for live tracking
/// (EXP-16, ADM-07). Mirrors backend src/sockets/index.js contract.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  String? _connectedToken;

  /// Handlers are kept here rather than bound directly to the socket so they
  /// survive a reconnect, and so registering one before connecting still works.
  final List<void Function(Map<String, dynamic>)> _locationHandlers = [];
  final List<void Function(Map<String, dynamic>)> _notificationHandlers = [];

  /// Rooms rejoined automatically after a reconnect.
  final Set<String> _trackedTrips = {};

  bool get isConnected => _socket?.connected ?? false;

  /// Idempotent: calling it again with the same token is a no-op, so it is safe
  /// from a widget build. It previously tore down and rebuilt the connection on
  /// every rebuild, which meant the socket was almost never actually up.
  void connect(String token) {
    if (_connectedToken == token && _socket != null) return;

    _socket?.dispose();
    _connectedToken = token;

    final socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(9999)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      // Re-subscribe to any trip rooms we were watching before the drop.
      for (final tripId in _trackedTrips) {
        socket.emit('trip:track', tripId);
      }
    });

    socket.on('trip:location', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (final h in List.of(_locationHandlers)) {
          h(map);
        }
      }
    });

    socket.on('notification', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (final h in List.of(_notificationHandlers)) {
          h(map);
        }
      }
    });

    _socket = socket;
    socket.connect();
  }

  void trackTrip(String tripId) {
    _trackedTrips.add(tripId);
    _socket?.emit('trip:track', tripId);
  }

  void leaveTrip(String tripId) {
    _trackedTrips.remove(tripId);
    _socket?.emit('trip:leave', tripId);
  }

  void sendLocation(String tripId, double lat, double lng) {
    _socket?.emit('trip:location', {'tripId': tripId, 'lat': lat, 'lng': lng});
  }

  void onLocation(void Function(Map<String, dynamic>) handler) {
    _locationHandlers.add(handler);
  }

  void offLocation(void Function(Map<String, dynamic>) handler) {
    _locationHandlers.remove(handler);
  }

  void onNotification(void Function(Map<String, dynamic>) handler) {
    _notificationHandlers.add(handler);
  }

  void offNotification(void Function(Map<String, dynamic>) handler) {
    _notificationHandlers.remove(handler);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
    _trackedTrips.clear();
    _locationHandlers.clear();
    _notificationHandlers.clear();
  }
}
