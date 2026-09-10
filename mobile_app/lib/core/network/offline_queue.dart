import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_client.dart';

/// Section 6/CHA-12: "العمل دون اتصال بالإنترنت: تُحفظ العمليات وتُرسل تلقائيًا عند عودة الشبكة"
/// (works offline; operations are saved and sent automatically once the network returns).
/// Used by the driver app for status updates, POD uploads, and incident reports.
class QueuedAction {
  QueuedAction({
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    this.attempts = 0,
  });

  final String method; // 'POST' | 'PUT'
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final int attempts;

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
        method: json['method'],
        path: json['path'],
        body: Map<String, dynamic>.from(json['body']),
        createdAt: DateTime.parse(json['createdAt']),
        attempts: json['attempts'] ?? 0,
      );

  QueuedAction copyWith({int? attempts}) => QueuedAction(
        method: method,
        path: path,
        body: body,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
      );
}

/// A [ChangeNotifier] so the driver's offline banner actually refreshes when the
/// queue grows or drains — previously the count was read once and never updated.
class OfflineQueue extends ChangeNotifier {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _boxName = 'offline_queue';
  /// After this many failed sends an action is dropped rather than blocking the
  /// queue forever (e.g. a status the server will always reject).
  static const _maxAttempts = 5;

  Box<String>? _box;
  bool _flushing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    if (pendingCount > 0) notifyListeners();
  }

  Future<void> enqueue(QueuedAction action) async {
    await _box?.add(jsonEncode(action.toJson()));
    notifyListeners();
  }

  int get pendingCount => _box?.length ?? 0;

  Future<void> flush() async {
    if (_flushing || _box == null || _box!.isEmpty) return;
    _flushing = true;
    var changed = false;
    try {
      final keys = _box!.keys.toList();
      for (final key in keys) {
        final raw = _box!.get(key);
        if (raw == null) continue;

        QueuedAction action;
        try {
          action = QueuedAction.fromJson(jsonDecode(raw));
        } catch (_) {
          // Undecodable entry would otherwise wedge the queue permanently.
          await _box!.delete(key);
          changed = true;
          continue;
        }

        try {
          if (action.method == 'POST') {
            await ApiClient.instance.post(action.path, data: action.body);
          } else if (action.method == 'PUT') {
            await ApiClient.instance.put(action.path, data: action.body);
          }
          await _box!.delete(key);
          changed = true;
        } on ApiException catch (e) {
          // The server rejected it (e.g. an already-applied status change).
          // Retrying will never help, so drop it instead of blocking the queue.
          final status = e.statusCode ?? 0;
          if (status >= 400 && status < 500) {
            await _box!.delete(key);
            changed = true;
            continue;
          }
          await _bumpAttempts(key, action);
          changed = true;
          break;
        } catch (_) {
          // Still offline — keep order and retry on the next connectivity event.
          await _bumpAttempts(key, action);
          changed = true;
          break;
        }
      }
    } finally {
      _flushing = false;
      if (changed) notifyListeners();
    }
  }

  Future<void> _bumpAttempts(dynamic key, QueuedAction action) async {
    final next = action.copyWith(attempts: action.attempts + 1);
    if (next.attempts >= _maxAttempts) {
      await _box!.delete(key);
    } else {
      await _box!.put(key, jsonEncode(next.toJson()));
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
