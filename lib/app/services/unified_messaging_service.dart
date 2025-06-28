import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../utils/logger.dart';
import 'firebase_service.dart';
import 'apns_service.dart';
import 'auth_service.dart';

/// Unified messaging service that handles both Firebase (Android/Web) and APNs (iOS)
/// This service provides a single interface for push notifications across platforms
class UnifiedMessagingService extends GetxService {
  late AuthService _authService;
  FirebaseService? _firebaseService;
  APNsService? _apnsService;
  
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  String? get deviceToken {
    if (Platform.isIOS) {
      return _apnsService?.deviceToken;
    } else {
      return _firebaseService?.deviceToken;
    }
  }
  
  Future<UnifiedMessagingService> init() async {
    _authService = Get.find<AuthService>();
    await _initializeMessaging();
    return this;
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    // onInit is called automatically by GetX
    // Actual initialization is done in init() method
  }
  
  Future<void> _initializeMessaging() async {
    try {
      AppLogger.info('Initializing unified messaging service');
      
      if (Platform.isIOS) {
        // Use APNs for iOS
        _apnsService = Get.find<APNsService>();
        AppLogger.info('Using APNs for iOS push notifications');
      } else {
        // Use Firebase for Android and Web
        try {
          _firebaseService = Get.find<FirebaseService>();
          AppLogger.info('Using Firebase for Android/Web push notifications');
        } catch (e) {
          AppLogger.warning('Firebase service not available, notifications disabled');
        }
      }
      
      _isInitialized = true;
      AppLogger.info('Unified messaging service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize unified messaging service', 'UnifiedMessaging', e);
    }
  }
  
  /// Send a push notification to a user
  /// Automatically uses the appropriate service based on the target platform
  Future<bool> sendNotificationToUser({
    required String targetUserId,
    required String messageContent,
    String? messageId,
    String? senderName,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No current user for sending notification');
        return false;
      }
      
      // Determine which service to use based on current platform
      if (Platform.isIOS && _apnsService != null) {
        return await _apnsService!.sendNotificationToUser(
          targetUserId: targetUserId,
          messageContent: messageContent,
          messageId: messageId,
          senderName: senderName,
        );
      } else if (_firebaseService != null) {
        return await _firebaseService!.sendNotificationToUser(
          targetUserId: targetUserId,
          messageContent: messageContent,
          messageId: messageId,
        );
      } else {
        AppLogger.warning('No messaging service available for current platform');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error sending notification', 'UnifiedMessaging', e);
      return false;
    }
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS && _apnsService != null) {
        return await _apnsService!.requestPermissions();
      } else if (_firebaseService != null) {
        // Firebase handles permissions automatically
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error requesting permissions', 'UnifiedMessaging', e);
      return false;
    }
  }
  
  /// Get current notification settings
  Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      if (Platform.isIOS && _apnsService != null) {
        return await _apnsService!.getNotificationSettings();
      } else if (_firebaseService != null) {
        // Return Firebase-style settings
        return {
          'authorizationStatus': 'authorized',
          'platform': 'firebase',
        };
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting notification settings', 'UnifiedMessaging', e);
      return null;
    }
  }
  
  /// Subscribe to a topic (Firebase only)
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (_firebaseService != null) {
        await _firebaseService!.subscribeToTopic(topic);
      } else {
        AppLogger.info('Topic subscription not available on iOS APNs');
      }
    } catch (e) {
      AppLogger.error('Error subscribing to topic', 'UnifiedMessaging', e);
    }
  }
  
  /// Unsubscribe from a topic (Firebase only)
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (_firebaseService != null) {
        await _firebaseService!.unsubscribeFromTopic(topic);
      } else {
        AppLogger.info('Topic unsubscription not available on iOS APNs');
      }
    } catch (e) {
      AppLogger.error('Error unsubscribing from topic', 'UnifiedMessaging', e);
    }
  }
  
  /// Get platform-specific information
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': Platform.operatingSystem,
      'isIOS': Platform.isIOS,
      'isAndroid': Platform.isAndroid,
      'isWeb': kIsWeb,
      'messagingService': Platform.isIOS ? 'APNs' : 'Firebase',
      'deviceToken': deviceToken,
      'isInitialized': _isInitialized,
    };
  }
  
  /// Handle incoming messages (called by platform-specific services)
  Future<void> handleIncomingMessage(Map<String, dynamic> messageData) async {
    try {
      AppLogger.info('Handling incoming message: $messageData');
      
      // Common message handling logic can go here
      // This method can be called by both Firebase and APNs services
      
      // Example: Update UI, refresh chat rooms, etc.
      // Get.find<HomeController>().refreshChatRooms();
      
    } catch (e) {
      AppLogger.error('Error handling incoming message', 'UnifiedMessaging', e);
    }
  }
}
