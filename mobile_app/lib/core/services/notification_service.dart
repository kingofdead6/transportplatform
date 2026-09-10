import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import 'socket_service.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    this.title,
    this.body,
    this.tripId,
    this.isCritical = false,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String type;
  final String? title;
  final String? body;
  final String? tripId;
  final bool isCritical;
  final bool read;
  final DateTime? createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        tripId: tripId,
        isCritical: isCritical,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['_id'] ?? '',
        type: json['type'] ?? 'message',
        title: json['title'],
        body: json['body'],
        tripId: json['tripId'] is Map ? json['tripId']['_id'] : json['tripId'] as String?,
        isCritical: json['isCritical'] ?? false,
        read: json['read'] ?? false,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );
}

/// Backs the notification centre. The backend has emitted `notification` socket
/// events and exposed /api/notifications all along, but the app had no screen or
/// service consuming them, so users never saw an offer, assignment or incident
/// alert.
class NotificationService extends ChangeNotifier {
  NotificationService() {
    SocketService.instance.onNotification(_handleIncoming);
  }

  final List<AppNotification> _items = [];
  bool _loading = false;
  String? _error;

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.read).length;

  void _handleIncoming(Map<String, dynamic> data) {
    try {
      final notif = AppNotification.fromJson(data);
      // A socket echo of something already listed must not duplicate the row.
      if (_items.any((n) => n.id == notif.id)) return;
      _items.insert(0, notif);
      notifyListeners();
    } catch (_) {
      // A malformed payload should never take the screen down.
    }
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.get('/notifications');
      _items
        ..clear()
        ..addAll((res.data as List).map((e) => AppNotification.fromJson(e)));
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].read) return;
    // Optimistic: the badge should drop immediately.
    _items[i] = _items[i].copyWith(read: true);
    notifyListeners();
    try {
      await ApiClient.instance.put('/notifications/$id/read');
    } on ApiException {
      _items[i] = _items[i].copyWith(read: false);
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    final previous = List.of(_items);
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(read: true);
    }
    notifyListeners();
    try {
      await ApiClient.instance.put('/notifications/read-all');
    } on ApiException {
      _items
        ..clear()
        ..addAll(previous);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    SocketService.instance.offNotification(_handleIncoming);
    super.dispose();
  }
}
