import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

/// Real-time channel: `notification` events per user, `trip:location` for live tracking
/// (EXP-16, ADM-07). Mirrors backend src/sockets/index.js contract.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;

  void connect(String token) {
    _socket?.dispose();
    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void trackTrip(String tripId) => _socket?.emit('trip:track', tripId);

  void leaveTrip(String tripId) => _socket?.emit('trip:leave', tripId);

  void sendLocation(String tripId, double lat, double lng) {
    _socket?.emit('trip:location', {'tripId': tripId, 'lat': lat, 'lng': lng});
  }

  void onLocation(void Function(Map<String, dynamic>) handler) {
    _socket?.on('trip:location', (data) => handler(Map<String, dynamic>.from(data)));
  }

  void onNotification(void Function(Map<String, dynamic>) handler) {
    _socket?.on('notification', (data) => handler(Map<String, dynamic>.from(data)));
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
