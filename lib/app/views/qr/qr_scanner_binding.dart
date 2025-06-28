import 'package:get/get.dart';
import 'qr_scanner_controller.dart';

class QrScannerBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<QrScannerController>(QrScannerController());
  }
}
