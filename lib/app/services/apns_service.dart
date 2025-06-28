import 'dart:io';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../utils/logger.dart';
import '../models/message_model.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// Apple Push Notification Service (APNs) implementation for iOS
/// This service handles iOS-specific push notifications using native APNs
class APNsService extends GetxService {
  static const MethodChannel _channel = MethodChannel('com.app.task/apns');
  
  late AuthService _authService;
  late DatabaseService _databaseService;
  late NotificationService _notificationService;
  
  String? _deviceToken;
  bool _isInitialized = false;
  
  String? get deviceToken => _deviceToken;
  bool get isInitialized => _isInitialized;
  
  Future<APNsService> init() async {
    _authService = Get.find<AuthService>();
    _databaseService = Get.find<DatabaseService>();
    _notificationService = Get.find<NotificationService>();

    if (Platform.isIOS) {
      await _initializeAPNs();
    }
    return this;
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    // onInit is called automatically by GetX
    // Actual initialization is done in init() method
  }
  
  Future<void> _initializeAPNs() async {
    try {
      AppLogger.info('Initializing APNs service for iOS');
      
      // Set up method channel handlers
      _channel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      AppLogger.info('APNs service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize APNs service', 'APNs', e);
    }
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTokenReceived':
        await _handleTokenReceived(call.arguments as String);
        break;
      case 'onTokenError':
        _handleTokenError(call.arguments as String);
        break;
      case 'onMessageReceived':
        await _handleMessageReceived(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onNotificationTapped':
        await _handleNotificationTapped(call.arguments as Map<dynamic, dynamic>);
        break;
      default:
        AppLogger.warning('Unknown method call: ${call.method}');
    }
  }
  
  Future<void> _handleTokenReceived(String token) async {
    _deviceToken = token;
    AppLogger.info('APNs device token received: ${token.substring(0, 20)}...');
    
    // Update user's APNs token in database
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final updatedUser = currentUser.copyWith(
        fcmToken: token, // Reuse fcmToken field for APNs token
        updatedAt: DateTime.now(),
      );
      await _databaseService.updateUser(updatedUser);
      AppLogger.info('User APNs token updated in database');
    }
  }
  
  void _handleTokenError(String error) {
    AppLogger.error('APNs token registration failed', 'APNs', error);
  }
  
  Future<void> _handleMessageReceived(Map<dynamic, dynamic> userInfo) async {
    try {
      AppLogger.info('APNs message received: $userInfo');
      
      // Extract message data from APNs payload
      final aps = userInfo['aps'] as Map<dynamic, dynamic>?;
      final customData = Map<String, dynamic>.from(userInfo);
      customData.remove('aps'); // Remove APNs-specific data
      
      if (customData.containsKey('messageId') && 
          customData.containsKey('senderId') && 
          customData.containsKey('messageContent')) {
        
        // Create message model
        final messageModel = MessageModel(
          id: customData['messageId'] as String,
          senderId: customData['senderId'] as String,
          receiverId: customData['receiverId'] as String,
          content: customData['messageContent'] as String,
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
        );
        
        // Save to database
        await _databaseService.insertMessage(messageModel);
        
        // Show local notification if needed
        if (aps != null) {
          final alert = aps['alert'];
          String title = 'New Message';
          String body = customData['messageContent'] as String;
          
          if (alert is Map) {
            title = alert['title'] as String? ?? title;
            body = alert['body'] as String? ?? body;
          } else if (alert is String) {
            body = alert;
          }
          
          await _notificationService.showLocalNotification(
            title: title,
            body: body,
            senderId: customData['senderId'] as String,
            senderName: customData['senderName'] as String? ?? 'Unknown',
            messageId: customData['messageId'] as String,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error handling APNs message', 'APNs', e);
    }
  }
  
  Future<void> _handleNotificationTapped(Map<dynamic, dynamic> userInfo) async {
    try {
      AppLogger.info('APNs notification tapped: $userInfo');
      
      // Navigate to chat if message data is available
      if (userInfo.containsKey('senderId')) {
        final senderId = userInfo['senderId'] as String;
        // You can add navigation logic here
        AppLogger.info('Should navigate to chat with user: $senderId');
      }
    } catch (e) {
      AppLogger.error('Error handling notification tap', 'APNs', e);
    }
  }
  
  /// Send push notification via APNs
  /// This would typically be called from your backend server
  Future<bool> sendNotificationToUser({
    required String targetUserId,
    required String messageContent,
    String? messageId,
    String? senderName,
  }) async {
    try {
      if (!Platform.isIOS) {
        AppLogger.warning('APNs is only available on iOS');
        return false;
      }
      
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No current user for sending APNs notification');
        return false;
      }
      
      // Get target user's APNs token
      final targetUser = await _databaseService.getUserById(targetUserId);
      if (targetUser?.fcmToken == null) {
        AppLogger.warning('Target user has no APNs token');
        return false;
      }
      
      // In a real app, you would send this to your backend server
      // which would then send the push notification via APNs
      final payload = {
        'deviceToken': targetUser!.fcmToken!,
        'payload': {
          'aps': {
            'alert': {
              'title': senderName ?? currentUser.displayName,
              'body': messageContent,
            },
            'badge': 1,
            'sound': 'default',
          },
          'messageId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'senderId': currentUser.id,
          'receiverId': targetUserId,
          'senderName': senderName ?? currentUser.displayName,
          'messageContent': messageContent,
          'type': 'chat_message',
        }
      };
      
      AppLogger.info('APNs notification payload prepared: ${payload['payload']}');
      
      // TODO: Send to your backend server
      // final response = await http.post(
      //   Uri.parse('YOUR_BACKEND_URL/send-apns'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json.encode(payload),
      // );
      
      // For now, just log success
      AppLogger.info('APNs notification would be sent to backend server');
      return true;
      
    } catch (e) {
      AppLogger.error('Error sending APNs notification', 'APNs', e);
      return false;
    }
  }
  
  /// Request notification permissions (called from iOS native code)
  Future<bool> requestPermissions() async {
    if (!Platform.isIOS) return false;
    
    try {
      // Permissions are requested in native iOS code
      // This method can be used to check current permission status
      return true;
    } catch (e) {
      AppLogger.error('Error requesting APNs permissions', 'APNs', e);
      return false;
    }
  }
  
  /// Get current notification settings
  Future<Map<String, dynamic>?> getNotificationSettings() async {
    if (!Platform.isIOS) return null;
    
    try {
      // This would typically call native iOS code to get current settings
      return {
        'authorizationStatus': 'authorized', // authorized, denied, notDetermined
        'alertSetting': 'enabled',
        'badgeSetting': 'enabled',
        'soundSetting': 'enabled',
      };
    } catch (e) {
      AppLogger.error('Error getting notification settings', 'APNs', e);
      return null;
    }
  }
}
