import 'package:get/get.dart';

import '../views/splash/splash_view.dart';
import '../views/splash/splash_binding.dart';
import '../views/auth/login/login_view.dart';
import '../views/auth/login/login_binding.dart';
import '../views/auth/register/register_view.dart';
import '../views/auth/register/register_binding.dart';
import '../views/home/home_view.dart';
import '../views/home/home_binding.dart';
import '../views/chat/chat_view.dart';
import '../views/chat/chat_binding.dart';
import '../views/map/map_view.dart';
import '../views/map/map_binding.dart';
import '../views/qr/qr_scanner_view.dart';
import '../views/qr/qr_scanner_binding.dart';
import '../views/qr/qr_generator_view.dart';
import '../views/qr/qr_generator_binding.dart';
import '../views/profile/profile_view.dart';
import '../views/profile/profile_binding.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.REGISTER,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.CHAT,
      page: () => const ChatView(),
      binding: ChatBinding(),
    ),
    GetPage(
      name: Routes.MAP,
      page: () => const MapView(),
      binding: MapBinding(),
    ),
    GetPage(
      name: Routes.QR_SCANNER,
      page: () => const QrScannerView(),
      binding: QrScannerBinding(),
    ),
    GetPage(
      name: Routes.QR_GENERATOR,
      page: () => const QrGeneratorView(),
      binding: QrGeneratorBinding(),
    ),
    GetPage(
      name: Routes.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
    ),
  ];
}
