import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/firebase_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';

class ChatController extends GetxController {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  
  final RxList<MessageModel> _messages = <MessageModel>[].obs;
  final RxBool _isLoading = true.obs;
  final RxBool _isSending = false.obs;
  final RxBool _isTyping = false.obs;
  final RxString _otherUserStatus = 'offline'.obs;
  
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading.value;
  bool get isSending => _isSending.value;
  bool get isTyping => _isTyping.value;
  String get otherUserStatus => _otherUserStatus.value;
  
  late AuthService _authService;
  late DatabaseService _databaseService;
  late FirebaseService _firebaseService;
  
  String? otherUserId;
  String? otherUserName;
  String? otherUserDeviceToken;
  UserModel? currentUser;

  // Stream subscription for real-time message updates
  StreamSubscription<String>? _messageSubscription;
  
  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
    _databaseService = Get.find<DatabaseService>();
    _firebaseService = Get.find<FirebaseService>();
    
    currentUser = _authService.currentUser;
    
    // Get arguments from navigation
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      otherUserId = arguments['userId'];
      otherUserName = arguments['userName'];
      otherUserDeviceToken = arguments['deviceToken'];
    }
    
    if (otherUserId != null && currentUser != null) {
      _loadMessages();
      _setupMessageListener();
    }
  }
  
  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    _messageSubscription?.cancel();
    super.onClose();
  }
  
  Future<void> _loadMessages() async {
    try {
      _isLoading.value = true;
      
      final messages = await _databaseService.getMessages(
        currentUser!.id!,
        otherUserId!,
      );
      
      // Mark messages as from current user
      final updatedMessages = messages.map((message) {
        return message.copyWith(
          isFromCurrentUser: message.senderId == currentUser!.id,
        );
      }).toList();
      
      _messages.value = updatedMessages;
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'Failed to load messages: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void _setupMessageListener() {
    if (currentUser?.id == null || otherUserId == null) return;

    // Listen for new message notifications from Firebase service
    _messageSubscription = _firebaseService.messageStream.listen((senderId) {
      // Only refresh if the message is from the other user we're chatting with
      if (senderId == otherUserId) {
        print('Received new message from $otherUserId, refreshing chat...');
        _loadMessages();
      }
    });
  }

  // Method to be called when a new message is received
  void onNewMessageReceived(String senderId) {
    if (senderId == otherUserId) {
      print('Chat controller: Refreshing messages for new message from $senderId');
      _loadMessages();
    }
  }

  // Public method to refresh messages (can be called from outside)
  void refreshMessages() {
    _loadMessages();
  }

  Future<void> sendMessage() async {
    final content = messageController.text.trim();
    if (content.isEmpty || _isSending.value) return;

    try {
      _isSending.value = true;

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final message = MessageModel(
        id: messageId,
        senderId: currentUser!.id!,
        receiverId: otherUserId!,
        content: content,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        isFromCurrentUser: true,
      );

      // Add message to UI immediately
      _messages.add(message);
      messageController.clear();
      _scrollToBottom();

      // Save to database
      await _databaseService.insertMessage(message);

      // Update chat room with last message
      await _databaseService.updateChatRoomLastMessage(
        currentUser!.id!,
        otherUserId!,
        messageId
      );

      // Update message status to sent
      final sentMessage = message.copyWith(status: MessageStatus.sent);
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = sentMessage;
      }

      // Send push notification to the other user
      if (otherUserId != null) {
        final notificationSent = await _firebaseService.sendNotificationToUser(
          targetUserId: otherUserId!,
          messageContent: content,
          messageId: messageId,
        );

        if (notificationSent) {
          // Update message status to delivered
          final deliveredMessage = sentMessage.copyWith(
            status: MessageStatus.delivered,
            deliveredAt: DateTime.now(),
          );
          if (index != -1) {
            _messages[index] = deliveredMessage;
          }
        }else {
          print('Failed to send notification to user: $otherUserId');
        }
      }else {
        print('Other user ID is null, cannot send notification');
      }

    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'message_failed'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      // Update message status to failed
      final messageId = _messages.last.id;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
      }
    } finally {
      _isSending.value = false;
    }
  }
  
  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void onMessageTap(MessageModel message) {
    // Handle message tap (e.g., show message details)
  }
  
  void onMessageLongPress(MessageModel message) {
    // Handle message long press (e.g., show context menu)
    if (message.isFromCurrentUser) {
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
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  // Copy message to clipboard
                  Get.back();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  _deleteMessage(message);
                  Get.back();
                },
              ),
            ],
          ),
        ),
      );
    }
  }
  
  Future<void> _deleteMessage(MessageModel message) async {
    try {
      await _databaseService.deleteMessage(message.id!);
      _messages.removeWhere((m) => m.id == message.id);
      
      Get.snackbar(
        'success'.tr,
        'Message deleted',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'Failed to delete message',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  void goBack() {
    Get.back();
  }
  
  String formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  Color getMessageStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.blue;
      case MessageStatus.delivered:
        return Colors.green;
      case MessageStatus.read:
        return Colors.blue;
      case MessageStatus.failed:
        return Colors.red;
    }
  }
  
  IconData getMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
    }
  }
}
