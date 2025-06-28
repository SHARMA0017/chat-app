# APNs Backend Integration Guide

> **📝 Documentation**: Comprehensive APNs integration guide created with Claude AI assistance.

## Overview
This guide shows how to implement Apple Push Notification Service (APNs) on your backend server to send push notifications to iOS devices.

## Prerequisites

### 1. Apple Developer Account Setup
1. **APNs Key**: Create an APNs authentication key in Apple Developer Console
   - Go to Certificates, Identifiers & Profiles
   - Keys → Create a new key
   - Enable Apple Push Notifications service (APNs)
   - Download the `.p8` key file
   - Note the Key ID and Team ID

2. **App ID Configuration**:
   - Ensure your App ID has Push Notifications capability enabled
   - Configure for both Development and Production

### 2. Required Information
- **Key ID**: From the APNs key
- **Team ID**: Your Apple Developer Team ID
- **Bundle ID**: Your app's bundle identifier (e.g., `com.app.task`)
- **APNs Key File**: The `.p8` file downloaded from Apple

## Backend Implementation

### Node.js Example

#### Install Dependencies
```bash
npm install node-apn jsonwebtoken
```

#### APNs Service Implementation
```javascript
const apn = require('node-apn');
const jwt = require('jsonwebtoken');
const fs = require('fs');

class APNsService {
  constructor() {
    this.keyId = 'YOUR_KEY_ID';
    this.teamId = 'YOUR_TEAM_ID';
    this.bundleId = 'com.app.task';
    this.keyPath = './path/to/AuthKey_KEYID.p8';
    
    this.provider = new apn.Provider({
      token: {
        key: fs.readFileSync(this.keyPath),
        keyId: this.keyId,
        teamId: this.teamId,
      },
      production: false, // Set to true for production
    });
  }

  async sendNotification(deviceToken, payload) {
    try {
      const notification = new apn.Notification();
      
      // APNs payload
      notification.alert = {
        title: payload.title,
        body: payload.body,
      };
      notification.badge = payload.badge || 1;
      notification.sound = 'default';
      notification.topic = this.bundleId;
      
      // Custom data
      notification.payload = {
        messageId: payload.messageId,
        senderId: payload.senderId,
        receiverId: payload.receiverId,
        senderName: payload.senderName,
        messageContent: payload.messageContent,
        type: 'chat_message',
      };

      const result = await this.provider.send(notification, deviceToken);
      
      if (result.sent.length > 0) {
        console.log('APNs notification sent successfully');
        return { success: true, result };
      } else {
        console.error('APNs notification failed:', result.failed);
        return { success: false, error: result.failed };
      }
    } catch (error) {
      console.error('APNs error:', error);
      return { success: false, error: error.message };
    }
  }

  async sendChatMessage(deviceToken, messageData) {
    const payload = {
      title: messageData.senderName,
      body: messageData.messageContent,
      badge: 1,
      messageId: messageData.messageId,
      senderId: messageData.senderId,
      receiverId: messageData.receiverId,
      senderName: messageData.senderName,
      messageContent: messageData.messageContent,
    };

    return await this.sendNotification(deviceToken, payload);
  }
}

module.exports = APNsService;
```

#### Express.js API Endpoint
```javascript
const express = require('express');
const APNsService = require('./apns-service');

const app = express();
const apnsService = new APNsService();

app.use(express.json());

app.post('/send-apns', async (req, res) => {
  try {
    const { deviceToken, payload } = req.body;
    
    if (!deviceToken || !payload) {
      return res.status(400).json({ 
        error: 'Device token and payload are required' 
      });
    }

    const result = await apnsService.sendNotification(deviceToken, payload);
    
    if (result.success) {
      res.json({ success: true, message: 'Notification sent' });
    } else {
      res.status(500).json({ success: false, error: result.error });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/send-chat-message', async (req, res) => {
  try {
    const { deviceToken, messageData } = req.body;
    
    const result = await apnsService.sendChatMessage(deviceToken, messageData);
    
    if (result.success) {
      res.json({ success: true, message: 'Chat notification sent' });
    } else {
      res.status(500).json({ success: false, error: result.error });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.listen(3000, () => {
  console.log('APNs server running on port 3000');
});
```

### Python Example (using PyAPNs2)

#### Install Dependencies
```bash
pip install pyapns2 pyjwt cryptography
```

#### Python Implementation
```python
from apns2.client import APNsClient
from apns2.payload import Payload
from apns2.credentials import TokenCredentials
import json

class APNsService:
    def __init__(self):
        self.key_id = 'YOUR_KEY_ID'
        self.team_id = 'YOUR_TEAM_ID'
        self.bundle_id = 'com.app.task'
        self.key_path = './path/to/AuthKey_KEYID.p8'
        
        credentials = TokenCredentials(
            auth_key_path=self.key_path,
            auth_key_id=self.key_id,
            team_id=self.team_id
        )
        
        self.client = APNsClient(credentials, use_sandbox=True)  # False for production

    def send_notification(self, device_token, payload_data):
        try:
            payload = Payload(
                alert={
                    'title': payload_data['title'],
                    'body': payload_data['body']
                },
                badge=payload_data.get('badge', 1),
                sound='default',
                custom=payload_data.get('custom', {})
            )
            
            self.client.send_notification(device_token, payload, self.bundle_id)
            return {'success': True}
            
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def send_chat_message(self, device_token, message_data):
        payload_data = {
            'title': message_data['senderName'],
            'body': message_data['messageContent'],
            'badge': 1,
            'custom': {
                'messageId': message_data['messageId'],
                'senderId': message_data['senderId'],
                'receiverId': message_data['receiverId'],
                'senderName': message_data['senderName'],
                'messageContent': message_data['messageContent'],
                'type': 'chat_message'
            }
        }
        
        return self.send_notification(device_token, payload_data)
```

## Flutter Integration

### Update Flutter App to Use Backend
```dart
// In your UnifiedMessagingService or APNsService
Future<bool> sendNotificationToUser({
  required String targetUserId,
  required String messageContent,
  String? messageId,
  String? senderName,
}) async {
  try {
    // Get target user's device token
    final targetUser = await _databaseService.getUserById(targetUserId);
    if (targetUser?.fcmToken == null) {
      return false;
    }

    // Prepare payload for backend
    final payload = {
      'deviceToken': targetUser!.fcmToken!,
      'messageData': {
        'messageId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': _authService.currentUser!.id,
        'receiverId': targetUserId,
        'senderName': senderName ?? _authService.currentUser!.displayName,
        'messageContent': messageContent,
      }
    };

    // Send to your backend
    final response = await http.post(
      Uri.parse('YOUR_BACKEND_URL/send-chat-message'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    return response.statusCode == 200;
  } catch (e) {
    AppLogger.error('Error sending APNs notification', 'APNs', e);
    return false;
  }
}
```

## Testing

### 1. Development Testing
- Use sandbox APNs environment
- Test with development provisioning profile
- Use device tokens from development builds

### 2. Production Testing
- Switch to production APNs environment
- Use production provisioning profile
- Test with App Store or TestFlight builds

### 3. Payload Testing
```json
{
  "aps": {
    "alert": {
      "title": "John Doe",
      "body": "Hello! How are you?"
    },
    "badge": 1,
    "sound": "default"
  },
  "messageId": "1234567890",
  "senderId": "user123",
  "receiverId": "user456",
  "senderName": "John Doe",
  "messageContent": "Hello! How are you?",
  "type": "chat_message"
}
```

## Security Considerations

1. **Secure Key Storage**: Store APNs keys securely on your server
2. **Token Validation**: Validate device tokens before sending
3. **Rate Limiting**: Implement rate limiting for notification sending
4. **Authentication**: Secure your notification endpoints
5. **Encryption**: Use HTTPS for all communication

## Monitoring and Analytics

1. **Delivery Tracking**: Monitor notification delivery rates
2. **Error Handling**: Log and handle APNs errors appropriately
3. **Metrics**: Track notification performance and user engagement
4. **Feedback Service**: Handle invalid device tokens

## Next Steps

1. Set up your backend server with APNs integration
2. Configure your Apple Developer account
3. Update your Flutter app to use the backend API
4. Test thoroughly in development environment
5. Deploy to production with production APNs certificates

This implementation provides a robust, scalable solution for iOS push notifications that works alongside your existing Firebase setup for Android.
