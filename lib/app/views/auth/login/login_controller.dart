import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;
  
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  
  late AuthService _authService;
  
  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
  }
  
  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
  
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }
  
  Future<void> login() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    
    try {
      isLoading.value = true;
      
      final success = await _authService.login(
        emailController.text.trim(),
        passwordController.text,
      );
      
      if (success) {
        Get.snackbar(
          'success'.tr,
          'login_success'.tr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.snackbar(
          'error'.tr,
          'login_failed'.tr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'login_failed'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  void goToRegister() {
    Get.toNamed(Routes.REGISTER);
  }
  
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'email_required'.tr;
    }
    if (!_authService.isValidEmail(value)) {
      return 'email_invalid'.tr;
    }
    return null;
  }
  
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'password_required'.tr;
    }
    if (!_authService.isValidPassword(value)) {
      return 'password_min_length'.tr;
    }
    return null;
  }
}
