import 'package:get/get.dart';
import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    print('here adding splash binding');
    Get.put<SplashController>(SplashController());
  }
}
