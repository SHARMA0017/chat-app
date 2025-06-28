import 'package:get/get.dart';
import 'register_controller.dart';
import '../../../services/country_service.dart';

class RegisterBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CountryService>(CountryService());
    Get.put<RegisterController>(RegisterController());
  }
}
