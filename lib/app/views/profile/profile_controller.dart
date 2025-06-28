import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class ProfileController extends GetxController {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  
  final RxBool isEditing = false.obs;
  final RxBool isLoading = false.obs;
  
  late AuthService _authService;
  late LocalizationService _localizationService;
  late FirebaseService _firebaseService;
  
  UserModel? get currentUser => _authService.currentUser;
  
  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
    _localizationService = Get.find<LocalizationService>();
    _firebaseService = Get.find<FirebaseService>();
    
    _loadUserData();
  }
  
  @override
  void onClose() {
    displayNameController.dispose();
    mobileController.dispose();
    super.onClose();
  }
  
  void _loadUserData() {
    if (currentUser != null) {
      displayNameController.text = currentUser!.displayName;
      mobileController.text = currentUser!.mobile;
    }
  }
  
  void toggleEdit() {
    isEditing.value = !isEditing.value;
    if (!isEditing.value) {
      // Reset to original values if canceling edit
      _loadUserData();
    }
  }
  
  Future<void> saveProfile() async {
    if (currentUser == null) return;
    
    try {
      isLoading.value = true;
      
      final updatedUser = currentUser!.copyWith(
        displayName: displayNameController.text.trim(),
        mobile: mobileController.text.trim(),
        updatedAt: DateTime.now(),
      );
      
      await _authService.updateUser(updatedUser);
      
      isEditing.value = false;
      
      Get.snackbar(
        'success'.tr,
        'Profile updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'Failed to update profile: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  void changeLanguage() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'change_language'.tr,
              style: Get.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: _localizationService.getCurrentLanguageCode() == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                _localizationService.changeLanguage('en');
                Get.back();
              },
            ),
            ListTile(
              leading: const Text('🇸🇦', style: TextStyle(fontSize: 24)),
              title: const Text('العربية'),
              trailing: _localizationService.getCurrentLanguageCode() == 'ar'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                _localizationService.changeLanguage('ar');
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void showDeviceInfo() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: Get.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('User ID', currentUser?.id ?? 'N/A'),
            _buildInfoRow('Email', currentUser?.email ?? 'N/A'),
            _buildInfoRow('Country', currentUser?.country ?? 'N/A'),
            _buildInfoRow('Device Token', _getDeviceTokenPreview()),
            _buildInfoRow('Created', _formatDate(currentUser?.createdAt)),
            _buildInfoRow('Updated', _formatDate(currentUser?.updatedAt)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDeviceTokenPreview() {
    final token = _firebaseService.deviceToken;
    if (token == null || token.isEmpty) return 'Not available';
    
    if (token.length > 20) {
      return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
    }
    return token;
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Future<void> logout() async {
    Get.dialog(
      AlertDialog(
        title: Text('logout'.tr),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _authService.logout();
              Get.offAllNamed(Routes.LOGIN);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('logout'.tr),
          ),
        ],
      ),
    );
  }
  
  void goToQRGenerator() {
    Get.toNamed(Routes.QR_GENERATOR);
  }
  
  void goBack() {
    Get.back();
  }
}
