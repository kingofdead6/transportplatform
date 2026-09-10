import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import 'socket_service.dart';

class AuthService extends ChangeNotifier {
  AppUser? currentUser;
  String? _token;
  bool isLoading = true;

  bool get isLoggedIn => currentUser != null && _token != null;
  String? get token => _token;

  /// True once the account is approved and may use the app for real.
  bool get isApproved => currentUser?.status == 'active';

  Future<void> bootstrap() async {
    // A 401 on any later request means the stored session is dead; drop it and
    // return to the login screen rather than showing empty screens forever.
    ApiClient.instance.onUnauthorized = () {
      if (isLoggedIn) logout();
    };

    _token = await ApiClient.instance.readToken();
    if (_token != null) {
      try {
        final res = await ApiClient.instance.get('/auth/me');
        currentUser = AppUser.fromJson(res.data);
        _connectSocket();
      } on ApiException catch (e) {
        // Keep the session on a transient network failure — only a real
        // rejection from the server should sign the user out.
        if (!e.isNetworkError) {
          await logout();
        }
      } catch (_) {
        await logout();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> requestOtp(String phone) async {
    final res = await ApiClient.instance.post('/auth/request-otp', data: {'phone': phone});
    return res.data['devCode'] as String?;
  }

  Future<void> verifyOtp({required String phone, required String code, String? role}) async {
    final res = await ApiClient.instance.post(
      '/auth/verify-otp',
      data: {'phone': phone, 'code': code, if (role != null) 'role': role},
    );
    await _persistSession(res.data['token'], res.data['user']);
  }

  Future<void> loginWithPassword({required String phone, required String password}) async {
    final res = await ApiClient.instance
        .post('/auth/login', data: {'phone': phone, 'password': password});
    await _persistSession(res.data['token'], res.data['user']);
  }

  Future<void> register({
    required String phone,
    required String password,
    required String role,
    String? fullName,
    String? companyName,
  }) async {
    final res = await ApiClient.instance.post('/auth/register', data: {
      'phone': phone,
      'password': password,
      'role': role,
      if (fullName != null) 'fullName': fullName,
      if (companyName != null) 'companyName': companyName,
    });
    await _persistSession(res.data['token'], res.data['user']);
  }

  Future<void> changePassword({String? currentPassword, required String newPassword}) async {
    await ApiClient.instance.put('/users/me/password', data: {
      if (currentPassword != null) 'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.put('/users/me', data: body);
    currentUser = AppUser.fromJson(res.data);
    notifyListeners();
  }

  Future<void> _persistSession(String token, Map<String, dynamic> userJson) async {
    _token = token;
    currentUser = AppUser.fromJson(userJson);
    await ApiClient.instance.setToken(token);
    _connectSocket();
    notifyListeners();
  }

  void _connectSocket() {
    final token = _token;
    if (token != null) SocketService.instance.connect(token);
  }

  Future<void> refreshMe() async {
    final res = await ApiClient.instance.get('/auth/me');
    currentUser = AppUser.fromJson(res.data);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    currentUser = null;
    // The socket carries the old identity — it must go down with the session.
    SocketService.instance.disconnect();
    await ApiClient.instance.setToken(null);
    notifyListeners();
  }
}
