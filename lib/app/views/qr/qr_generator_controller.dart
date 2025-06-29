import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';

class QrGeneratorController extends GetxController {
  final RxString qrData = ''.obs;
  final RxBool isLoading = false.obs;
  
  late AuthService _authService;
  late FirebaseService _firebaseService;
  
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
      _authService = Get.find<AuthService>();
    _firebaseService = Get.find<FirebaseService>();
    _generateQRData();
      }
    );

  }
  
  Future<void> _generateQRData() async {
    try {
      isLoading.value = true;
      
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        Get.snackbar(
          'error'.tr,
          'You must be logged in to generate QR code',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Get device token
      final deviceToken = _firebaseService.deviceToken;
      if (deviceToken == null) {
        Get.snackbar(
          'error'.tr,
          'Device token not available. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Generate QR data with FCM token: "chat_token:{deviceToken}:{userId}:{userName}"
      // This is necessary so other users can send notifications
      qrData.value = 'chat_token:$deviceToken:${currentUser.id}:${currentUser.displayName}';
      print('Generated QR data: ${qrData.value}');
      print('QR data length: ${qrData.value.length} characters');
      print('FCM token length: ${deviceToken.length} characters');
      
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'Failed to generate QR code: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> refreshQRCode() async {
    await _generateQRData();
    Get.snackbar(
      'success'.tr,
      'QR code refreshed successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }
  
  Future<void> copyToClipboard() async {
    if (qrData.value.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: qrData.value));
      Get.snackbar(
        'success'.tr,
        'QR code data copied to clipboard',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }
  
  Future<void> shareQRCode() async {
    if (qrData.value.isNotEmpty) {
      final currentUser = _authService.currentUser;
      await Share.share(
        qrData.value,
        subject: 'Connect with ${currentUser?.displayName ?? 'me'} on Chat App',
      );
    }
  }
  
  String get userDisplayName {
    return _authService.currentUser?.displayName ?? 'Unknown User';
  }
  
  String get userEmail {
    return _authService.currentUser?.email ?? '';
  }
  
  String get deviceTokenPreview {
    final token = _firebaseService.deviceToken;
    if (token == null || token.isEmpty) return 'Not available';
    
    // Show first 10 and last 10 characters
    if (token.length > 20) {
      return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
    }
    return token;
  }
  
  void goBack() {
    Get.back();
  }
}
