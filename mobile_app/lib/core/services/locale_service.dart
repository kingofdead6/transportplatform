import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  Locale _locale = const Locale('fr');
  Locale get locale => _locale;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale');
    if (saved != null) _locale = Locale(saved);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    notifyListeners();
  }

  TextDirection get direction => _locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
}
