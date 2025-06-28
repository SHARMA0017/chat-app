# FCM v1 API Setup Guide

This guide will help you set up Firebase Cloud Messaging (FCM) v1 API for sending push notifications between users in your Flutter app.

## Prerequisites

1. A Firebase project with your Flutter app configured
2. Firebase Admin SDK service account credentials

## Step 1: Generate Service Account Key

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on the gear icon (⚙️) → **Project Settings**
4. Go to the **Service Accounts** tab
5. Click **Generate new private key**
6. Download the JSON file

## Step 2: Configure the Firebase Service

Open `lib/app/services/firebase_service.dart` and update the following constants:

### 1. Update Project ID
```dart
static const String _projectId = 'your-actual-project-id';
```

### 2. Update Service Account JSON
Replace the `_serviceAccountJson` map with your actual service account data:

```dart
static const Map<String, dynamic> _serviceAccountJson = {
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "your-private-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_ACTUAL_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com",
  "client_id": "your-client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs/firebase-adminsdk-xxxxx%40your-project-id.iam.gserviceaccount.com"
};
```

## Step 3: Security Considerations

⚠️ **IMPORTANT**: Never commit service account credentials to version control!

### For Development:
- Keep the credentials in the code temporarily for testing
- Add `lib/app/services/firebase_service.dart` to `.gitignore` if it contains real credentials

### For Production:
- Store credentials in environment variables or secure storage
- Use a backend service to handle FCM messaging
- Consider using Firebase Functions for server-side messaging

## Step 4: How to Use

### Send Notification to Specific User
```dart
final firebaseService = Get.find<FirebaseService>();
final success = await firebaseService.sendNotificationToUser(
  targetUserId: 'user123',
  messageContent: 'Hello! You have a new message.',
  messageId: 'msg_001',
);
```

### Send Notification to Multiple Users
```dart
final success = await firebaseService.sendNotificationToMultipleUsers(
  targetUserIds: ['user1', 'user2', 'user3'],
  messageContent: 'Group announcement!',
);
```

### Send Notification to Topic (Group)
```dart
final success = await firebaseService.sendNotificationToTopic(
  topic: 'general_chat',
  messageContent: 'New message in general chat!',
);
```

## Step 5: Testing

1. Make sure two devices/emulators are running the app
2. Log in with different users on each device
3. Send a message from one user to another
4. The recipient should receive a push notification

## Troubleshooting

### Common Issues:

1. **"Service account not configured"**
   - Make sure you've updated the `_serviceAccountJson` with real values

2. **"Could not get access token"**
   - Check that your service account JSON is valid
   - Ensure the private key is properly formatted with `\n` characters

3. **"Failed to send FCM v1 notification"**
   - Verify the target user has a valid FCM token
   - Check that the project ID matches your Firebase project

4. **Notifications not appearing**
   - Ensure the app has notification permissions
   - Check that FCM tokens are being saved to user profiles
   - Verify the app is properly handling background/foreground messages

## Fallback Behavior

If FCM is not configured or fails, the app will automatically fall back to local notifications using `flutter_local_notifications`. This ensures the app continues to work even without proper FCM setup.

## Next Steps

- Consider implementing a backend service for production use
- Add notification analytics and tracking
- Implement rich notifications with images and actions
- Add notification scheduling and batching