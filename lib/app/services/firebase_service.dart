import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

import '../utils/logger.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../views/home/home_controller.dart';
import '../views/chat/chat_controller.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'notification_service.dart';

class FirebaseService extends GetxService {
  late FirebaseMessaging _messaging;
  late AuthService _authService;
  late DatabaseService _databaseService;
  late NotificationService _notificationService;

  String? _deviceToken;
  String? get deviceToken => _deviceToken;

  // Stream controller for real-time message updates
  final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageStreamController.stream;

  // FCM v1 API Configuration
  static const String _projectId = 'task-4dccc';
  static const String _fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';

  // Service Account JSON - In production, store this securely
  // You can get this from Firebase Console > Project Settings > Service Accounts > Generate new private key
  static const Map<String, dynamic> _serviceAccountJson = {
  // ADD YOUR FIREBASE Service Account JSON

};
  
  Future<FirebaseService> init() async {
    _messaging = FirebaseMessaging.instance;
    _authService = Get.find<AuthService>();
    _databaseService = Get.find<DatabaseService>();
    _notificationService = Get.find<NotificationService>();

    await _initializeMessaging();
    return this;
  }
  
  Future<void> _initializeMessaging() async {
    try {
      // Request permission for notifications (especially important for iOS)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      AppLogger.info('Notification permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.info('User granted provisional notification permission');
      } else {
        AppLogger.warning('User declined or has not accepted notification permission');
        if (Platform.isIOS) {
          AppLogger.warning('On iOS, notifications require explicit permission. Please enable in Settings.');
        }
      }
      
      // Get the device token with retry mechanism for iOS
      await _getDeviceTokenWithRetry();
      
      // Update user's device token if available
      if (_deviceToken != null && _authService.currentUser != null) {
        await _authService.updateDeviceToken(_deviceToken!);
      }
      
      // Setup message handlers
      _setupMessageHandlers();
      
      // Listen to token refresh
      _setupTokenRefreshListener();
      
    } catch (e) {
      AppLogger.error('Error initializing messaging', 'FCM', e);
      if (Platform.isIOS) {
        AppLogger.error('iOS FCM initialization failed. Check APNs configuration.', 'FCM', e);
      }
    }
  }

  Future<void> _getDeviceTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        _deviceToken = await _messaging.getToken();
        if (_deviceToken != null) {
          AppLogger.fcm('Device Token obtained (attempt ${i + 1}): ${_deviceToken!.substring(0, 20)}...');
          return;
        } else {
          AppLogger.warning('Device token is null (attempt ${i + 1})');
          if (Platform.isIOS) {
            AppLogger.warning('iOS token retrieval failed. Check APNs setup and app permissions.');
          }
        }
      } catch (e) {
        AppLogger.error('Error getting device token (attempt ${i + 1})', 'FCM', e);
      }
      
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(seconds: 2)); // Wait 2 seconds before retry
      }
    }
    
    if (_deviceToken == null) {
      AppLogger.error('Failed to get device token after $maxRetries attempts', 'FCM');
      if (Platform.isIOS) {
        AppLogger.error('iOS troubleshooting: 1) Check APNs key/certificate in Firebase Console, 2) Verify push notifications capability in Xcode, 3) Check app permissions', 'FCM');
      }
    }
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle initial message if app was opened from notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      AppLogger.info('FCM Token refreshed: ${newToken.substring(0, 20)}...');
      _deviceToken = newToken;
      if (_authService.currentUser != null) {
        _authService.updateDeviceToken(newToken);
      }
    }, onError: (error) {
      AppLogger.error('Error in token refresh listener', 'FCM', error);
    });
  }
  
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');

    // Only show notification if the message is NOT from the current user
    final currentUserId = _authService.currentUser?.id;
    final senderId = message.data['senderId'];

    if (currentUserId != null && senderId != null && senderId != currentUserId) {
      // Process the incoming message to store sender's FCM token and save message
      await _processIncomingMessage(message);

      // Show in-app notification when app is in foreground
      if (message.data.containsKey('senderName') && message.data.containsKey('messageContent')) {
        _notificationService.showInAppNotification(
          title: message.data['senderName'] ?? 'New Message',
          message: message.data['messageContent'] ?? '',
          onTap: () {
            if (message.data.containsKey('senderId')) {
              Get.toNamed('/chat', arguments: {
                'userId': message.data['senderId'],
                'userName': message.data['senderName'] ?? 'Unknown',
              });
            }
          },
        );
      }
    } else {
      print('Skipping notification - message from current user or invalid sender');
    }
  }
  
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');
    // Handle background message processing here
  }
  
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.messageId}');
    // Navigate to chat screen or handle notification tap
    if (message.data.containsKey('senderId')) {
      // Navigate to chat with sender
      Get.toNamed('/chat', arguments: {
        'userId': message.data['senderId'],
        'userName': message.data['senderName'] ?? 'Unknown',
      });
    }
  }
  
  Future<void> _processIncomingMessage(RemoteMessage message) async {
    try {
      final data = message.data;
      final currentUserId = _authService.currentUser?.id;

      if (data.containsKey('messageContent') &&
          data.containsKey('senderId') &&
          data.containsKey('receiverId')) {

        // Only process messages that are sent TO the current user (not FROM the current user)
        if (currentUserId != null && data['receiverId'] == currentUserId && data['senderId'] != currentUserId) {

          final messageId = data['messageId'] ?? DateTime.now().millisecondsSinceEpoch.toString();

          // Check if message already exists to prevent duplicates
          final existingMessage = await _databaseService.getMessageById(messageId);
          if (existingMessage != null) {
            print('Message already exists, skipping: $messageId');
            return;
          }

          // Ensure chat room exists for the receiver
          await _databaseService.createChatRoom(data['senderId'], currentUserId);

          // Ensure sender user exists in database and update their FCM token
          final senderUser = await _databaseService.getUserById(data['senderId']);
          final senderToken = data['senderToken'] ?? '';

          if (senderUser == null && data.containsKey('senderName')) {
            // Create a new user for the sender with their FCM token
            final newSenderUser = UserModel(
              id: data['senderId'],
              email: '${data['senderId']}@placeholder.com',
              displayName: data['senderName'] ?? 'Unknown User',
              country: 'Unknown',
              mobile: 'Unknown',
              fcmToken: senderToken.isNotEmpty ? senderToken : null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _databaseService.insertUser(newSenderUser);
            print('Created new user for sender ${data['senderId']} with FCM token length: ${senderToken.length}');
          } else if (senderUser != null && senderToken.isNotEmpty) {
            // Update existing user's FCM token if we have a new one
            if (senderUser.fcmToken != senderToken) {
              final updatedUser = senderUser.copyWith(
                fcmToken: senderToken,
                updatedAt: DateTime.now(),
              );
              await _databaseService.updateUser(updatedUser);
              print('Updated FCM token for user ${data['senderId']}, token length: ${senderToken.length}');
            }
          }

          final messageModel = MessageModel(
            id: messageId,
            senderId: data['senderId'],
            receiverId: data['receiverId'],
            content: data['messageContent'],
            timestamp: DateTime.now(),
            status: MessageStatus.delivered,
            isFromCurrentUser: false, // This is an incoming message
          );

          // Save message to local database
          await _databaseService.insertMessage(messageModel);

          // Update chat room with last message
          await _databaseService.updateChatRoomLastMessage(
            data['senderId'],
            currentUserId,
            messageId
          );

          // Refresh home controller if it exists
          try {
            final homeController = Get.find<HomeController>();
            homeController.refreshChatRooms();
          } catch (e) {
            print('Home controller not found, skipping refresh');
          }

          // Notify chat controllers about new message
          _messageStreamController.add(data['senderId']);

          // Also try to directly notify active chat controller
          try {
            final chatController = Get.find<ChatController>();
            chatController.onNewMessageReceived(data['senderId']);
          } catch (e) {
            print('Chat controller not found or not active');
          }

          print('Processed incoming message from ${data['senderId']} to ${data['receiverId']}');
        } else {
          print('Skipping message processing - not for current user or from current user');
        }
      }
    } catch (e) {
      print('Error processing incoming message: $e');
    }
  }

  /// Get OAuth 2.0 access token for FCM v1 API
  Future<String?> _getAccessToken() async {
    try {
      // Check if service account is configured
      if (_serviceAccountJson['project_id'] == 'YOUR_PROJECT_ID') {
        AppLogger.warning('Service account not configured. Please add your service account JSON.');
        return null;
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(_serviceAccountJson);
      final scopes = [_fcmScope];

      final authClient = await clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = authClient.credentials.accessToken.data;
      authClient.close();

      return accessToken;
    } catch (e) {
      AppLogger.error('Error getting access token', 'FCM', e);
      return null;
    }
  }

  Future<bool> sendPushNotification({
    required String targetToken,
    required String senderName,
    required String messageContent,
    required String senderId,
    required String receiverId,
    String? messageId,
    String? senderToken,
  }) async {
    try {
      // Get OAuth 2.0 access token
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('Could not get access token. FCM not configured properly.');
        print('Message would be sent to: $senderName');
        print('Content: $messageContent');
        return false;
      }

      // FCM v1 API message format
      final message = {
        'message': {
          'token': targetToken,
          'notification': {
            'title': senderName,
            'body': messageContent,
          },
          'data': {
            'messageId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'senderId': senderId,
            'receiverId': receiverId,
            'senderName': senderName,
            'messageContent': messageContent,
            'senderToken': senderToken ?? '',
            'type': 'chat_message',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'content-available': 1,
                'alert': {
                  'title': senderName,
                  'body': messageContent,
                },
              },
            },
          },
        },
      };

      final fcmUrl = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('FCM v1 notification sent successfully: $responseData');
        return true;
      } else {
        print('Failed to send FCM v1 notification: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending push notification: $e');
      return false;
    }
  }
  
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      AppLogger.info('Subscribed to topic: $topic');
    } catch (e) {
      AppLogger.error('Error subscribing to topic: $topic', 'FCM', e);
    }
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      AppLogger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      AppLogger.error('Error unsubscribing from topic: $topic', 'FCM', e);
    }
  }
  
  Future<String?> getDeviceToken() async {
    if (_deviceToken != null) {
      return _deviceToken;
    }
    
    // Try to get token again if not available
    await _getDeviceTokenWithRetry();
    return _deviceToken;
  }
  
  Future<void> refreshToken() async {
    await _getDeviceTokenWithRetry();
    if (_deviceToken != null && _authService.currentUser != null) {
      await _authService.updateDeviceToken(_deviceToken!);
    }
  }

  /// Get a valid FCM token for the target user
  Future<String?> _getValidFCMToken(UserModel targetUser, String targetUserId) async {
    // Check if target user has a valid stored FCM token
    if (targetUser.fcmToken != null &&
        targetUser.fcmToken!.isNotEmpty &&
        !targetUser.fcmToken!.startsWith('placeholder_token_') &&
        targetUser.fcmToken!.length > 100) {
      print('Using stored FCM token for user $targetUserId: ${targetUser.fcmToken!.length} chars');
      return targetUser.fcmToken;
    }

    print('Target user has no valid FCM token (length: ${targetUser.fcmToken?.length ?? 0}), checking if they are current user...');

    // If the target user is the current user, use the current device token
    if (targetUserId == _authService.currentUser?.id) {
      print('Using current device token for target user: ${deviceToken?.length ?? 0} chars');
      return deviceToken;
    }

    print('Cannot get FCM token for user $targetUserId - not current user and no valid stored token');
    print('Note: User needs to scan your QR code for bidirectional notifications');
    return null;
  }

  /// Send notification to a specific user by their user ID
  Future<bool> sendNotificationToUser({
    required String targetUserId,
    required String messageContent,
    String? messageId,
  }) async {
    try {
      // Get the target user's information including FCM token
      final targetUser = await _databaseService.getUserById(targetUserId);
      if (targetUser == null) {
        print('Target user not found: $targetUserId');
        return false;
      }

      // Get FCM token for target user
      String? fcmToken = await _getValidFCMToken(targetUser, targetUserId);

      if (fcmToken == null || fcmToken.isEmpty) {
        print('No valid FCM token available for target user: $targetUserId');
        print('Suggestion: Ask the user to generate a new QR code with their current FCM token');
        return false;
      }

      // Additional validation: Check if token looks like a valid FCM token
      if (fcmToken.length < 100) {
        print('FCM token appears to be truncated (${fcmToken.length} chars). This may be from an old QR code.');
        print('Suggestion: Ask the user to generate a new QR code with their current FCM token');
        return false;
      }

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('Current user not found');
        return false;
      }

      // Debug logging
      print('Sending notification:');
      print('  From: ${currentUser.displayName} (${currentUser.id})');
      print('  To: ${targetUser.displayName} (${targetUser.id})');
      print('  Token: $fcmToken');
      print('  Token Length: ${fcmToken.length}');
      print('  Message: $messageContent');

      // Send the notification
      return await sendPushNotification(
        targetToken: fcmToken,
        senderName: currentUser.displayName,
        messageContent: messageContent,
        senderId: currentUser.id!,
        receiverId: targetUserId,
        messageId: messageId,
        senderToken: deviceToken,
      );
    } catch (e) {
      print('Error sending notification to user: $e');
      return false;
    }
  }

  /// Send notification to multiple users
  Future<List<bool>> sendNotificationToMultipleUsers({
    required List<String> targetUserIds,
    required String messageContent,
    String? messageId,
  }) async {
    final results = <bool>[];

    for (final userId in targetUserIds) {
      final result = await sendNotificationToUser(
        targetUserId: userId,
        messageContent: messageContent,
        messageId: messageId,
      );
      results.add(result);
    }

    return results;
  }

  /// Send notification to all users in a group/topic
  Future<bool> sendNotificationToTopic({
    required String topic,
    required String messageContent,
    String? messageId,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('Current user not found');
        return false;
      }

      // Get OAuth 2.0 access token
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('Could not get access token for topic messaging.');
        return false;
      }

      // FCM v1 API message format for topics
      final message = {
        'message': {
          'topic': topic,
          'notification': {
            'title': currentUser.displayName,
            'body': messageContent,
          },
          'data': {
            'messageId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'senderId': currentUser.id!,
            'senderName': currentUser.displayName,
            'messageContent': messageContent,
            'type': 'group_message',
            'topic': topic,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'content-available': 1,
                'alert': {
                  'title': currentUser.displayName,
                  'body': messageContent,
                },
              },
            },
          },
        },
      };

      final fcmUrl = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('FCM v1 topic notification sent successfully: $responseData');
        return true;
      } else {
        print('Failed to send FCM v1 topic notification: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending topic notification: $e');
      return false;
    }
  }

  /// Check if FCM is properly configured and working
  Future<bool> checkFCMStatus() async {
    try {
      final token = await getDeviceToken();
      final hasPermission = await _checkNotificationPermission();
      
      print('FCM Status Check:');
      print('  Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
      print('  Token available: ${token != null}');
      print('  Token length: ${token?.length ?? 0}');
      print('  Permission granted: $hasPermission');
      
      if (Platform.isIOS) {
        print('  iOS specific checks:');
        print('    - Ensure APNs key/certificate is configured in Firebase Console');
        print('    - Verify Push Notifications capability is enabled in Xcode');
        print('    - Check app notification permissions in iOS Settings');
      }
      
      return token != null && hasPermission;
    } catch (e) {
      print('Error checking FCM status: $e');
      return false;
    }
  }

  Future<bool> _checkNotificationPermission() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  @override
  void onClose() {
    _messageStreamController.close();
    super.onClose();
  }
}