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
  // Replace with your Firebase project ID
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
    // Check if Firebase Messaging is supported on this platform
    if (Platform.isIOS) {
      AppLogger.warning('Firebase Messaging disabled on iOS due to build issues. Using APNs instead.');
      return;
    }

    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      AppLogger.info('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      AppLogger.info('User granted provisional notification permission');
    } else {
      AppLogger.warning('User declined or has not accepted notification permission');
    }
    
    // Get the device token
    _deviceToken = await _messaging.getToken();
    AppLogger.fcm('Device Token obtained: ${_deviceToken?.substring(0, 20)}...');
    
    // Update user's device token
    if (_deviceToken != null && _authService.currentUser != null) {
      await _authService.updateDeviceToken(_deviceToken!);
    }
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle initial message if app was opened from notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
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
        // Don't show local notification as it would appear on sender's device
        // In a real app, you might want to store the message for later delivery
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
    await _messaging.subscribeToTopic(topic);
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
  
  Future<String?> getDeviceToken() async {
    // Return null for iOS due to Firebase build issues
    if (Platform.isIOS) {
      AppLogger.warning('Device token not available on iOS due to Firebase build issues. Use APNs instead.');
      return null;
    }
    return await _messaging.getToken();
  }
  
  Future<void> refreshToken() async {
    _deviceToken = await _messaging.getToken();
    if (_deviceToken != null && _authService.currentUser != null) {
      await _authService.updateDeviceToken(_deviceToken!);
    }
  }
  
  // Listen to token refresh
  void listenToTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      _deviceToken = newToken;
      if (_authService.currentUser != null) {
        _authService.updateDeviceToken(newToken);
      }
    });
  }

  /// Get a valid FCM token for the target user
  Future<String?> _getValidFCMToken(UserModel targetUser, String targetUserId) async {
    // Check if target user has a valid stored FCM token
    // FCM tokens should be 140+ characters long
    if (targetUser.fcmToken != null &&
        targetUser.fcmToken!.isNotEmpty &&
        !targetUser.fcmToken!.startsWith('placeholder_token_') &&
        targetUser.fcmToken!.length > 100) { // Valid FCM tokens are much longer than 100 chars
      print('Using stored FCM token for user $targetUserId: ${targetUser.fcmToken!.length} chars');
      return targetUser.fcmToken;
    }

    print('Target user has no valid FCM token (length: ${targetUser.fcmToken?.length ?? 0}), checking if they are current user...');

    // If the target user is the current user, use the current device token
    if (targetUserId == _authService.currentUser?.id) {
      print('Using current device token for target user: ${deviceToken?.length ?? 0} chars');
      return deviceToken;
    }

    // For other users, we can't get their FCM token directly
    // In a real app, this would be handled server-side with proper token exchange
    print('Cannot get FCM token for user $targetUserId - not current user and no valid stored token');
    print('Note: User needs to scan your QR code for bidirectional notifications');
    return null;
  }

  /// Send notification to a specific user by their user ID
  /// This method looks up the user's FCM token and sends the notification
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
        senderToken: deviceToken, // Include sender's FCM token
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

  @override
  void onClose() {
    _messageStreamController.close();
    super.onClose();
  }
}
