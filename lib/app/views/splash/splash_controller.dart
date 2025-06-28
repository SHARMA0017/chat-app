import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../routes/app_routes.dart';

class SplashController extends GetxController {
  late AuthService _authService;
  late LocalizationService _localizationService;

  @override
  void onInit() {
    super.onInit();

    print('here in splash controller');
    _authService = Get.find<AuthService>();
    _localizationService = Get.find<LocalizationService>();
    _navigateToNextScreen();
  }
  
  void _navigateToNextScreen() async {
      print('here in navigate to next screen');
    try {
      // Wait for 2 seconds to show splash screen
      await Future.delayed(const Duration(seconds: 2));

      // Update locale from saved preferences
      Get.updateLocale(_localizationService.locale);

      // Check if user is logged in
      if (_authService.isLoggedIn) {
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.offAllNamed(Routes.LOGIN);
      }
    } catch (e) {
      // If there's an error, navigate to login as fallback
      print('Error in splash navigation: $e');
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}
