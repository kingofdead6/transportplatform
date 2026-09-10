import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Thin Dio wrapper: attaches JWT, exposes typed helpers, and normalises every
/// failure into an [ApiException] carrying the server's message, so screens can
/// show what actually went wrong instead of a generic error.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // A rejected/expired session must not leave a stale token behind,
          // otherwise every later request fails silently.
          if (error.response?.statusCode == 401) {
            await _clearToken();
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  /// Invoked when the server rejects the stored session, so the app can return
  /// the user to the login screen instead of showing empty lists forever.
  void Function()? _onUnauthorized;
  set onUnauthorized(void Function()? handler) => _onUnauthorized = handler;

  Dio get dio => _dio;

  String? _cachedToken;

  /// Public accessor so session restore reads the same cached value the
  /// request interceptor uses.
  Future<String?> readToken() => _readToken();

  Future<String?> _readToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  Future<void> setToken(String? token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('auth_token');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<void> _clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _guard(() => _dio.get(path, queryParameters: query));
  }

  Future<Response<dynamic>> post(String path, {dynamic data}) {
    return _guard(() => _dio.post(path, data: data));
  }

  Future<Response<dynamic>> put(String path, {dynamic data}) {
    return _guard(() => _dio.put(path, data: data));
  }

  Future<Response<dynamic>> delete(String path, {dynamic data}) {
    return _guard(() => _dio.delete(path, data: data));
  }

  Future<Response<dynamic>> uploadForm(String path, FormData form) {
    return _guard(() => _dio.post(path, data: form));
  }

  /// Every call funnels through here so callers only ever catch [ApiException].
  Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() send) async {
    try {
      return await send();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  final String message;
  final int? statusCode;

  /// True when the request never reached the server, so the caller can decide
  /// to queue the action for later instead of surfacing a failure.
  final bool isNetworkError;

  factory ApiException.fromDioError(DioException e) {
    const offlineTypes = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    final offline = offlineTypes.contains(e.type);

    final data = e.response?.data;
    String msg;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    } else if (offline) {
      msg = 'No connection. Check your network and try again.';
    } else {
      msg = e.message ?? 'Network error';
    }

    return ApiException(msg, statusCode: e.response?.statusCode, isNetworkError: offline);
  }

  @override
  String toString() => message;
}
