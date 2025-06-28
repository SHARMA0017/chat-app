import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../../../services/auth_service.dart';
import '../../../services/country_service.dart';
import '../../../models/country_model.dart';
import '../../../routes/app_routes.dart';


class RegisterController extends GetxController {
  final emailController = TextEditingController();
  final displayNameController = TextEditingController();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final Rx<CountryModel?> selectedCountry = Rx<CountryModel?>(null);
  
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  
  late AuthService _authService;
  late CountryService _countryService;
  
  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
    _countryService = Get.find<CountryService>();
    _loadCountries();
    _preFillRandomData();
  }
  
  @override
  void onClose() {
    emailController.dispose();
    displayNameController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
  
  Future<void> _loadCountries() async {
    await _countryService.fetchCountries();
  }

  void _preFillRandomData() {
    final random = Random();

    // Random first names
    final firstNames = [
      'Alex', 'Jordan', 'Taylor', 'Casey', 'Morgan', 'Riley', 'Avery', 'Quinn',
      'Blake', 'Cameron', 'Drew', 'Emery', 'Finley', 'Harper', 'Hayden', 'Jamie',
      'Kendall', 'Logan', 'Parker', 'Peyton', 'Reese', 'Sage', 'Skylar', 'Tatum'
    ];

    // Random last names
    final lastNames = [
      'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
      'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
      'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson'
    ];

    // Generate random name
    final firstName = firstNames[random.nextInt(firstNames.length)];
    final lastName = lastNames[random.nextInt(lastNames.length)];
    final displayName = '$firstName $lastName';

    // Generate unique email with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}.$timestamp@example.com';

    // Generate random mobile number
    final mobileNumber = '${random.nextInt(900) + 100}${random.nextInt(900) + 100}${random.nextInt(9000) + 1000}';

    // Pre-fill the form fields
    emailController.text = email;
    displayNameController.text = displayName;
    mobileController.text = mobileNumber;
    passwordController.text = '123456'; // Development default
    confirmPasswordController.text = '123456';

    // Select a random country after countries are loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_countryService.countries.isNotEmpty) {
        final randomCountry = _countryService.countries[random.nextInt(_countryService.countries.length)];
        selectedCountry.value = randomCountry;
      }
    });

    print('Pre-filled registration form with:');
    print('Email: $email');
    print('Name: $displayName');
    print('Mobile: $mobileNumber');
    print('Password: 123456');
  }
  
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }
  
  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }
  
  void selectCountry(CountryModel country) {
    selectedCountry.value = country;
  }
  
  void showCountryPicker() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'country'.tr,
                style: Get.textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: Obx(() {
                if (_countryService.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                return ListView.builder(
                  itemCount: _countryService.countries.length,
                  itemBuilder: (context, index) {
                    final country = _countryService.countries[index];
                    return ListTile(
                      leading: Text(
                        country.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(country.name),
                      subtitle: Text(country.dialCode),
                      onTap: () {
                        selectCountry(country);
                        Get.back();
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> register() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    
    if (selectedCountry.value == null) {
      Get.snackbar(
        'error'.tr,
        'country_required'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    try {
      isLoading.value = true;
      
      final success = await _authService.register(
        email: emailController.text.trim(),
        displayName: displayNameController.text.trim(),
        country: selectedCountry.value!.name,
        mobile: mobileController.text.trim(),
        password: passwordController.text,
        confirmPassword: confirmPasswordController.text,
      );
      
      if (success) {
        Get.snackbar(
          'success'.tr,
          'registration_success'.tr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.snackbar(
          'error'.tr,
          'registration_failed'.tr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'registration_failed'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  void goToLogin() {
    Get.back();
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
  
  String? validateDisplayName(String? value) {
    if (value == null || value.isEmpty) {
      return 'display_name_required'.tr;
    }
    return null;
  }
  
  String? validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'mobile_required'.tr;
    }
    if (!_authService.isValidMobile(value)) {
      return 'mobile_invalid'.tr;
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
  
  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'password_required'.tr;
    }
    if (value != passwordController.text) {
      return 'passwords_dont_match'.tr;
    }
    return null;
  }
}
