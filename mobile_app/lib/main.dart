import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_strings.dart';
import 'core/network/offline_queue.dart';
import 'core/services/auth_service.dart';
import 'core/services/locale_service.dart';
import 'core/services/socket_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await OfflineQueue.instance.init();

  runApp(const ProsimPlanatApp());
}

class ProsimPlanatApp extends StatelessWidget {
  const ProsimPlanatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..bootstrap()),
        ChangeNotifierProvider(create: (_) => LocaleService()..bootstrap()),
      ],
      child: Consumer2<AuthService, LocaleService>(
        builder: (context, auth, localeService, _) {
          if (auth.isLoggedIn && auth.token != null) {
            SocketService.instance.connect(auth.token!);
          }
          return AppStrings(
            locale: localeService.locale,
            child: MaterialApp(
              title: 'Prosim Planat',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(localeService.locale.languageCode),
              locale: localeService.locale,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
              builder: (context, child) {
                return Directionality(
                  textDirection: localeService.direction,
                  child: child!,
                );
              },
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
