import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../network/api_client.dart';

class AuthService extends ChangeNotifier {
  AppUser? currentUser;
  String? _token;
  bool isLoading = true;

  bool get isLoggedIn => currentUser != null && _token != null;
  String? get token => _token;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      try {
        final res = await ApiClient.instance.get('/auth/me');
        currentUser = AppUser.fromJson(res.data);
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
    final res = await ApiClient.instance.post('/auth/login', data: {'phone': phone, 'password': password});
    await _persistSession(res.data['token'], res.data['user']);
  }

  Future<void> _persistSession(String token, Map<String, dynamic> userJson) async {
    _token = token;
    currentUser = AppUser.fromJson(userJson);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    notifyListeners();
  }

  Future<void> refreshMe() async {
    final res = await ApiClient.instance.get('/auth/me');
    currentUser = AppUser.fromJson(res.data);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }
}
