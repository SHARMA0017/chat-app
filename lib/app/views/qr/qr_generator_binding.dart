import 'package:get/get.dart';
import 'qr_generator_controller.dart';

class QrGeneratorBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<QrGeneratorController>(QrGeneratorController());
  }
}
