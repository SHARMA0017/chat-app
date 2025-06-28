# Chat App - Deployment Guide

> **📝 Documentation**: Created with assistance from Claude AI for comprehensive deployment coverage.

## Overview
This is a comprehensive Flutter chat application with Firebase integration, supporting Android, iOS, and Web platforms.

## Features Implemented
✅ **Authentication System**
- Login and registration with email/password
- Local storage persistence using SharedPreferences
- Automatic login state management

✅ **Database Layer**
- SQLite database for local message storage
- User data persistence
- Chat room management

✅ **Firebase Integration**
- Firebase Cloud Messaging for push notifications
- Real-time message delivery
- Device token management

✅ **QR Code System**
- QR code generation for device token sharing
- QR code scanning for user connection
- Seamless user pairing

✅ **Multi-language Support**
- English and Arabic language support
- RTL layout support for Arabic
- Dynamic language switching

✅ **Country API Integration**
- REST Countries API integration
- Country selection during registration
- Fallback countries for offline use

✅ **Maps Integration**
- Google Maps with current location
- 2km rectangular boundary visualization
- Water body highlighting (simulated)
- Real-time location tracking

✅ **Responsive UI/UX**
- Material Design 3 components
- Dark/Light theme support
- Responsive layouts for all screen sizes
- Smooth animations and transitions

## 🆕 Latest Updates (2024)

### ✅ **Enhanced Messaging System**
- **FCM v1 API**: Updated to latest Firebase Cloud Messaging API
- **Bidirectional Communication**: Automatic token exchange via QR codes
- **Unified Messaging**: Platform-aware service (Firebase for Android/Web, APNs for iOS)
- **Message Persistence**: SQLite database with comprehensive error handling

### ✅ **Advanced Camera & QR Integration**
- **Permission Handling**: Robust camera permission management with retry mechanisms
- **Error Recovery**: Graceful handling of permission denied states
- **QR Code Parsing**: Enhanced parsing with support for complex FCM tokens
- **Camera States**: Loading, error, and ready states with user feedback

### ✅ **Persistent Storage System**
- **Device-Specific Storage**: SQLite database with device ID verification
- **Auto-Login**: Automatic user login for returning users
- **Password Security**: Secure password hashing and storage
- **Session Management**: Comprehensive user session tracking

### ✅ **iOS Integration**
- **APNs Implementation**: Native Apple Push Notification Service integration
- **iOS-Specific Handling**: Platform-aware notification system
- **Firebase Workaround**: APNs used instead of Firebase for iOS due to build conflicts

### ⚠️ **Known Issues & Limitations**
- **iOS Firebase**: Firebase messaging disabled on iOS (APNs implemented instead)
- **Android Storage**: Local data cleared on app uninstall (normal Android behavior)
- **External Storage**: Limited reliability on Android 11+ due to scoped storage policies

## Prerequisites

### Development Environment
- Flutter SDK 3.22.2 or higher
- Dart SDK 3.4.3 or higher
- Android Studio / VS Code
- Git

### Platform-Specific Requirements

#### Android
- Android SDK 33 or higher
- Java 8 or higher
- Android device/emulator with API level 21+

#### iOS
- Xcode 14 or higher
- iOS 12.0 or higher
- macOS for development

#### Web
- Chrome browser for testing
- Web server for deployment

## Setup Instructions

### 1. Clone and Setup
```bash
git clone <repository-url>
cd project
flutter pub get
```

### 2. Firebase Configuration

#### Android
1. Create a Firebase project at https://console.firebase.google.com
2. Add Android app with package name: `com.app.task`
3. Download `google-services.json` and place in `android/app/`
4. Replace the placeholder file with your actual configuration

#### iOS
1. Add iOS app to your Firebase project
2. Download `GoogleService-Info.plist` and add to `ios/Runner/`
3. Configure in Xcode

#### Web
1. Add Web app to your Firebase project
2. Update `web/index.html` with Firebase config

### 3. Google Maps Setup
1. Get Google Maps API key from Google Cloud Console
2. Enable Maps SDK for Android/iOS/JavaScript
3. Update API key in:
   - `android/app/src/main/AndroidManifest.xml`
   - `ios/Runner/AppDelegate.swift`
   - `web/index.html`

## Building for Production

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS
```bash
flutter build ios --release
```
Then archive in Xcode for App Store submission

### Web
```bash
flutter build web --release
```
Output: `build/web/` directory

## Testing

### Run Tests
```bash
flutter test
```

### Widget Tests
```bash
flutter test test/widget_test.dart
```

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

## Deployment

### Android Play Store
1. Build app bundle: `flutter build appbundle --release`
2. Sign the bundle with your keystore
3. Upload to Google Play Console
4. Complete store listing and publish

### iOS App Store
1. Build for iOS: `flutter build ios --release`
2. Archive in Xcode
3. Upload to App Store Connect
4. Submit for review

### Web Hosting
1. Build web version: `flutter build web --release`
2. Deploy `build/web/` to your web server
3. Configure HTTPS and domain
4. Update Firebase hosting rules if using Firebase Hosting

## Configuration Files

### Important Files to Configure
- `android/app/google-services.json` - Firebase Android config
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS config
- `android/app/src/main/AndroidManifest.xml` - Google Maps API key
- `web/index.html` - Firebase web config and Maps API key

### Environment Variables
Create `.env` file for sensitive data:
```
GOOGLE_MAPS_API_KEY=your_api_key_here
FIREBASE_WEB_API_KEY=your_firebase_api_key
```

## Performance Optimization

### Recommended Settings
- Enable R8/ProGuard for Android release builds
- Use `--split-per-abi` for smaller APK sizes
- Optimize images and assets
- Enable web renderers for better web performance

### Build Optimizations
```bash
# Android with optimizations
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=debug-info/

# Web with optimizations
flutter build web --release --web-renderer canvaskit
```

## Troubleshooting

### Common Issues
1. **Firebase not working**: Check google-services.json/GoogleService-Info.plist
2. **Maps not showing**: Verify API key and enable required APIs
3. **Build failures**: Run `flutter clean && flutter pub get`
4. **Permission issues**: Check AndroidManifest.xml and Info.plist

### Debug Commands
```bash
flutter doctor -v
flutter analyze
flutter pub deps
```

## Support
For issues and questions, please check:
1. Flutter documentation: https://flutter.dev/docs
2. Firebase documentation: https://firebase.google.com/docs
3. Google Maps documentation: https://developers.google.com/maps

## License
This project is licensed under the MIT License.
