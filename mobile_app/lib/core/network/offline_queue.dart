import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_client.dart';

/// Section 6/CHA-12: "العمل دون اتصال بالإنترنت: تُحفظ العمليات وتُرسل تلقائيًا عند عودة الشبكة"
/// (works offline; operations are saved and sent automatically once the network returns).
/// Used by the driver app for status updates, POD uploads, and incident reports.
class QueuedAction {
  QueuedAction({required this.method, required this.path, required this.body, required this.createdAt});

  final String method; // 'POST' | 'PUT'
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
        method: json['method'],
        path: json['path'],
        body: Map<String, dynamic>.from(json['body']),
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _boxName = 'offline_queue';
  Box<String>? _box;
  bool _flushing = false;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
  }

  Future<void> enqueue(QueuedAction action) async {
    await _box?.add(jsonEncode(action.toJson()));
  }

  int get pendingCount => _box?.length ?? 0;

  Future<void> flush() async {
    if (_flushing || _box == null || _box!.isEmpty) return;
    _flushing = true;
    try {
      final keys = _box!.keys.toList();
      for (final key in keys) {
        final raw = _box!.get(key);
        if (raw == null) continue;
        final action = QueuedAction.fromJson(jsonDecode(raw));
        try {
          if (action.method == 'POST') {
            await ApiClient.instance.post(action.path, data: action.body);
          } else if (action.method == 'PUT') {
            await ApiClient.instance.put(action.path, data: action.body);
          }
          await _box!.delete(key);
        } catch (_) {
          // stop on first failure — keep order, retry next connectivity event
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
