import 'package:get/get.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Core services are already initialized in main.dart
    // This binding ensures they are available throughout the app
    // Using lazyPut here is fine since these services are already created
    // and we're just creating aliases for them
  }
}
