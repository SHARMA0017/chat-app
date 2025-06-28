import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';

import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../home/home_controller.dart';
import '../../utils/logger.dart';

class QrScannerController extends GetxController {
  late MobileScannerController scannerController;

  final RxBool isFlashOn = false.obs;
  final RxBool isScanning = true.obs;
  final RxString scannedData = ''.obs;
  final RxBool isCameraReady = false.obs;
  final RxBool hasPermission = false.obs;
  final RxString permissionStatus = 'checking'.obs;

  late AuthService _authService;
  late DatabaseService _databaseService;

  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
    _databaseService = Get.find<DatabaseService>();
    _initializeCamera();
  }

  /// Initialize camera with proper permission handling
  Future<void> _initializeCamera() async {
    try {
      AppLogger.info('Initializing QR scanner camera');
      permissionStatus.value = 'checking';

      // Check and request camera permission
      final permission = await _requestCameraPermission();

      if (permission) {
        // Wait a bit for permission to be fully processed
        await Future.delayed(const Duration(milliseconds: 500));

        // Initialize scanner controller
        scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
          torchEnabled: false,
        );

        // Wait for camera to be ready
        await Future.delayed(const Duration(milliseconds: 1000));

        isCameraReady.value = true;
        hasPermission.value = true;
        permissionStatus.value = 'granted';

        AppLogger.info('QR scanner camera initialized successfully');
      } else {
        hasPermission.value = false;
        permissionStatus.value = 'denied';
        AppLogger.warning('Camera permission denied for QR scanner');
      }
    } catch (e) {
      AppLogger.error('Error initializing QR scanner camera', 'QR', e);
      hasPermission.value = false;
      permissionStatus.value = 'error';
    }
  }

  /// Retry camera initialization (useful when permission is granted after initial failure)
  Future<void> retryCameraInitialization() async {
    AppLogger.info('Retrying camera initialization');
    isCameraReady.value = false;
    hasPermission.value = false;
    permissionStatus.value = 'checking';

    // Dispose existing controller if it exists
    try {
      if (isCameraReady.value) {
        await scannerController.dispose();
      }
    } catch (e) {
      AppLogger.warning('Error disposing scanner controller: $e');
    }

    // Reinitialize camera
    await _initializeCamera();
  }

  @override
  void onClose() {
    try {
      if (isCameraReady.value) {
        scannerController.dispose();
      }
    } catch (e) {
      AppLogger.warning('Error disposing scanner controller in onClose: $e');
    }
    super.onClose();
  }
  
  Future<bool> _requestCameraPermission() async {
    try {
      // Check current permission status
      final currentStatus = await Permission.camera.status;

      if (currentStatus.isGranted) {
        AppLogger.info('Camera permission already granted');
        return true;
      }

      if (currentStatus.isPermanentlyDenied) {
        AppLogger.warning('Camera permission permanently denied');
        _showPermissionDeniedDialog();
        return false;
      }

      // Request permission
      AppLogger.info('Requesting camera permission');
      final status = await Permission.camera.request();

      if (status.isGranted) {
        AppLogger.info('Camera permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        AppLogger.warning('Camera permission permanently denied');
        _showPermissionDeniedDialog();
        return false;
      } else {
        AppLogger.warning('Camera permission denied');
        Get.snackbar(
          'Permission Required',
          'Camera permission is required to scan QR codes',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return false;
      }
    } catch (e) {
      AppLogger.error('Error requesting camera permission', 'QR', e);
      return false;
    }
  }

  void _showPermissionDeniedDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'Camera permission is permanently denied. Please enable it in app settings to scan QR codes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  void onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (isScanning.value && barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        _handleScannedData(barcode.rawValue!);
      }
    }
  }
  
  Future<void> _handleScannedData(String data) async {
    isScanning.value = false;
    scannedData.value = data;





    try {
      print('Scanned QR data: $data');

      // Parse the scanned QR code data
      // Preferred format: "chat_token:{deviceToken}:{userId}:{userName}"
      if (data.startsWith('chat_token:')) {
        // Remove the prefix
        final withoutPrefix = data.substring('chat_token:'.length);

        // Find the last two colons to separate userId and userName
        final lastColonIndex = withoutPrefix.lastIndexOf(':');
        if (lastColonIndex == -1) {
          _showError('Invalid QR code format - missing userName');
          return;
        }

        final secondLastColonIndex = withoutPrefix.lastIndexOf(':', lastColonIndex - 1);
        if (secondLastColonIndex == -1) {
          _showError('Invalid QR code format - missing userId');
          return;
        }

        // Extract parts: everything before second-last colon is the token
        final deviceToken = withoutPrefix.substring(0, secondLastColonIndex);
        final userId = withoutPrefix.substring(secondLastColonIndex + 1, lastColonIndex);
        final userName = withoutPrefix.substring(lastColonIndex + 1);

        print('Parsed QR with token: deviceToken=$deviceToken, userId=$userId, userName=$userName');
        print('Device Token Length: ${deviceToken.length}');

        await _connectWithUserWithToken(deviceToken, userId, userName);
      } else if (data.startsWith('chat_user:')) {
        // Fallback format without token: "chat_user:{userId}:{userName}"
        final parts = data.split(':');
        if (parts.length >= 3) {
          final userId = parts[1];
          final userName = parts[2];

          print('Parsed QR without token: userId=$userId, userName=$userName');

          await _connectWithUserWithoutToken(userId, userName);
        } else {
          _showError('Invalid QR code format');
        }
      } else {
        _showError('This is not a valid chat QR code');
      }
    } catch (e) {
      _showError('Error processing QR code: $e');
      print('Error in _handleScannedData: $e');
    }
    
    // Resume scanning after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (!Get.isRegistered<QrScannerController>()) return;
      isScanning.value = true;
    });
  }
  
  Future<void> _connectWithUserWithoutToken(String userId, String userName) async {
    try {
      // Create a chat room between current user and scanned user
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _showError('You must be logged in to connect with other users');
        return;
      }

      // Check if trying to connect with yourself
      if (currentUser.id == userId) {
        _showError('You cannot connect with yourself!');
        return;
      }

      // Check if user already exists in database
      final existingUser = await _databaseService.getUserById(userId);
      if (existingUser == null) {
        // Create the scanned user in the database
        // Note: We can't get their actual FCM token, so we'll use a placeholder
        // In a real app, this would be handled server-side
        final scannedUser = UserModel(
          id: userId,
          email: '$userId@scanned.user', // Placeholder email
          displayName: userName,
          country: 'Unknown',
          mobile: 'Unknown',
          fcmToken: 'placeholder_token_$userId', // Placeholder for now
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _databaseService.insertUser(scannedUser);
        print('Added scanned user to database: $userName ($userId)');

        // Show a warning about FCM limitations
        Get.snackbar(
          'warning'.tr,
          'Connected with $userName! ⚠️ Notifications may not work - they need to scan your QR code too.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      } else {
        // Update the existing user's display name if needed
        final updatedUser = existingUser.copyWith(
          displayName: userName,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateUser(updatedUser);
        print('Updated existing user info: $userName ($userId)');
      }

      // Create chat room in database
      await _databaseService.createChatRoom(currentUser.id!, userId);

      // Show success message
      Get.snackbar(
        'success'.tr,
        'Connected with $userName! You can now start chatting.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Refresh home controller to show new chat room
      try {
        final homeController = Get.find<HomeController>();
        homeController.refreshChatRooms();
      } catch (e) {
        print('Home controller not found, skipping refresh');
      }

      // Navigate to chat screen
      Get.offNamed(Routes.CHAT, arguments: {
        'userId': userId,
        'userName': userName,
      });

    } catch (e) {
      _showError('Failed to connect with user: $e');
      print('Error in _connectWithUser: $e');
    }
  }

  // Primary method for QR codes with FCM tokens
  Future<void> _connectWithUserWithToken(String deviceToken, String userId, String userName) async {
    try {
      // Create a chat room between current user and scanned user
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _showError('You must be logged in to connect with other users');
        return;
      }

      // Check if trying to connect with yourself
      if (currentUser.id == userId) {
        _showError('You cannot connect with yourself!');
        return;
      }

      // Check if user already exists in database
      final existingUser = await _databaseService.getUserById(userId);
      if (existingUser == null) {
        // Create the scanned user in the database with the FCM token from QR
        final scannedUser = UserModel(
          id: userId,
          email: '$userId@scanned.user', // Placeholder email
          displayName: userName,
          country: 'Unknown',
          mobile: 'Unknown',
          fcmToken: deviceToken,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _databaseService.insertUser(scannedUser);
        print('Added scanned user to database with token: $userName ($userId)');
        print('Stored FCM token length: ${scannedUser.fcmToken?.length ?? 0}');
      } else {
        // Update the existing user's FCM token
        final updatedUser = existingUser.copyWith(
          fcmToken: deviceToken,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateUser(updatedUser);
        print('Updated existing user FCM token: $userName ($userId)');
      }

      // Create chat room in database
      await _databaseService.createChatRoom(currentUser.id!, userId);

      // Refresh home controller to show new chat room
      try {
        final homeController = Get.find<HomeController>();
        homeController.refreshChatRooms();
      } catch (e) {
        print('Home controller not found, skipping refresh');
      }

      // Show success message
      Get.snackbar(
        'success'.tr,
        'Connected with $userName! You can now start chatting.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Navigate to chat screen
      Get.offNamed(Routes.CHAT, arguments: {
        'userId': userId,
        'userName': userName,
        'deviceToken': deviceToken,
      });

    } catch (e) {
      _showError('Failed to connect with user: $e');
      print('Error in _connectWithUserWithToken: $e');
    }
  }
  
  void _showError(String message) {
    Get.snackbar(
      'error'.tr,
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
  
  void toggleFlash() async {
    await scannerController.toggleTorch();
    isFlashOn.value = !isFlashOn.value;
  }

  void flipCamera() async {
    await scannerController.switchCamera();
  }

  void pauseCamera() async {
    await scannerController.stop();
  }

  void resumeCamera() async {
    await scannerController.start();
  }
  
  void goBack() {
    Get.back();
  }
  
  void goToQRGenerator() {
    Get.toNamed(Routes.QR_GENERATOR);
  }
}
