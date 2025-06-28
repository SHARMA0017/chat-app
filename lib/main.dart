import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/services/firebase_service.dart';
import 'app/services/database_service.dart';
import 'app/services/auth_service.dart';
import 'app/services/localization_service.dart';
import 'app/services/notification_service.dart';
import 'app/services/country_service.dart';
import 'app/services/apns_service.dart';
import 'app/services/unified_messaging_service.dart';
import 'app/utils/app_theme.dart';
import 'app/bindings/initial_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize core services
  await initServices();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MainApp());
}

Future<void> initServices() async {
  // Initialize database
  await Get.putAsync(() => DatabaseService().init());

  // Initialize auth service
  await Get.putAsync(() => AuthService().init());

  // Initialize country service
  await Get.putAsync(() => CountryService().init());

  // Initialize notification service
  await Get.putAsync(() => NotificationService().init());

  // Initialize Firebase service
  await Get.putAsync(() => FirebaseService().init());

  // Initialize APNs service (iOS only)
  await Get.putAsync(() => APNsService().init());

  // Initialize unified messaging service
  await Get.putAsync(() => UnifiedMessagingService().init());

  // Initialize localization
  await Get.putAsync(() => LocalizationService().init());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Chat App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'), // Use default locale initially
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ar', 'SA'),
      ],
    );
  }
}
