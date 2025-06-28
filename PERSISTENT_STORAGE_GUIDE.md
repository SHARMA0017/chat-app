# Persistent User Storage Guide

> **📝 Documentation**: Comprehensive persistent storage guide created with Claude AI assistance.

## Overview
This guide explains how user information is stored persistently in the chat app, ensuring data survives app deletion and reinstallation.

## Implementation Details

### **Storage Method: SQLite Database**
The app uses SQLite database with specialized persistent storage tables that survive app deletion and reinstallation.

### **Key Features**
- ✅ **Survives App Deletion**: User data persists even after uninstalling the app
- ✅ **Device-Specific**: Data is tied to specific devices for security
- ✅ **Auto-Login**: Users are automatically logged in after app reinstallation
- ✅ **Secure Storage**: Password hashes and sensitive data are stored securely
- ✅ **Cross-Platform**: Works on Android, iOS, and Web

## Database Schema

### **Device Information Table**
```sql
CREATE TABLE device_info (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT UNIQUE NOT NULL,           -- Unique device identifier
  device_model TEXT,                        -- Device model (e.g., "iPhone 14")
  device_brand TEXT,                        -- Device brand (e.g., "Apple")
  os_version TEXT,                          -- OS version (e.g., "iOS 16.0")
  app_version TEXT,                         -- App version
  installation_id TEXT,                     -- Unique per app installation
  first_install_date INTEGER,               -- First installation timestamp
  last_access_date INTEGER,                 -- Last app access timestamp
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### **Persistent Users Table**
```sql
CREATE TABLE persistent_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,                  -- Links to device_info
  user_id TEXT NOT NULL,                    -- User's unique ID
  email TEXT NOT NULL,                      -- User's email
  display_name TEXT NOT NULL,               -- User's display name
  country TEXT,                             -- User's country
  mobile TEXT,                              -- User's mobile number
  fcm_token TEXT,                           -- Firebase/APNs token
  password_hash TEXT,                       -- Hashed password for auto-login
  last_login_date INTEGER,                  -- Last login timestamp
  auto_login_enabled INTEGER DEFAULT 1,     -- Auto-login preference
  user_created_at INTEGER,                  -- User account creation date
  user_updated_at INTEGER,                  -- User account last update
  stored_at INTEGER NOT NULL,               -- When data was stored
  updated_at INTEGER NOT NULL,
  UNIQUE(device_id, user_id)
);
```

### **User Sessions Table**
```sql
CREATE TABLE user_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  session_token TEXT,
  login_timestamp INTEGER NOT NULL,
  logout_timestamp INTEGER,
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL
);
```

### **Persistent Settings Table**
```sql
CREATE TABLE persistent_settings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  setting_key TEXT NOT NULL,
  setting_value TEXT,
  setting_type TEXT DEFAULT 'string',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(device_id, setting_key)
);
```

## How It Works

### **1. Device Identification**
```dart
// Generate unique device ID based on device characteristics
String deviceId = await databaseService.getOrCreateDeviceId();

// Device ID format: "device_model_brand_timestamp"
// Example: "SM-G973F_samsung_1703123456789"
```

### **2. User Registration**
```dart
// When user registers
await databaseService.savePersistentUserData(user, passwordHash: hashedPassword);

// Data is stored with device ID for security
```

### **3. Auto-Login After Reinstallation**
```dart
// On app startup
final persistentUser = await databaseService.getPersistentUserData();
if (persistentUser != null) {
  // User found - auto login
  currentUser = persistentUser;
  isLoggedIn = true;
}
```

### **4. Security Verification**
```dart
// Device ID verification prevents unauthorized access
if (storedDeviceId != currentDeviceId) {
  // Clear data if device doesn't match
  await databaseService.clearPersistentUserData();
}
```

## API Reference

### **DatabaseService Methods**

#### **Device Management**
```dart
// Get or create device ID
Future<String> getOrCreateDeviceId()

// Device ID is generated from:
// - Android: device.id + model + brand
// - iOS: identifierForVendor + model + systemName
// - Web: 'web' + timestamp
```

#### **User Data Persistence**
```dart
// Save user data persistently
Future<bool> savePersistentUserData(
  UserModel user, 
  {String? passwordHash}
)

// Retrieve persistent user data
Future<UserModel?> getPersistentUserData()

// Get stored password hash
Future<String?> getPersistentPasswordHash(String email)

// Check if persistent data exists
Future<bool> hasPersistentUserData()
```

#### **Session Management**
```dart
// Save user session
Future<void> savePersistentSession(String userId, String sessionToken)

// Clear all persistent data
Future<void> clearPersistentUserData()

// Disable auto-login
Future<void> disableAutoLogin()
```

#### **Settings Storage**
```dart
// Save persistent setting
Future<void> savePersistentSetting(
  String key, 
  String value, 
  {String type = 'string'}
)

// Get persistent setting
Future<String?> getPersistentSetting(String key)
```

### **AuthService Methods**

#### **Auto-Login Management**
```dart
// Enable/disable auto-login
Future<void> setAutoLogin(bool enabled)

// Check for persistent login on startup
Future<void> _checkPersistentLogin()

// Clear all persistent data
Future<void> clearPersistentData()

// Check if persistent data exists
Future<bool> hasPersistentData()
```

## Usage Examples

### **1. Register User with Persistent Storage**
```dart
final authService = Get.find<AuthService>();

final success = await authService.register(
  email: 'user@example.com',
  displayName: 'John Doe',
  country: 'United States',
  mobile: '+1234567890',
  password: 'securePassword',
  confirmPassword: 'securePassword',
);

// User data is automatically saved persistently
```

### **2. Check for Existing User on App Start**
```dart
final authService = Get.find<AuthService>();

// This is called automatically in AuthService.init()
await authService._checkPersistentLogin();

if (authService.isLoggedIn) {
  // User was automatically logged in from persistent storage
  print('Welcome back, ${authService.currentUser?.displayName}!');
}
```

### **3. Manage Auto-Login Preference**
```dart
final authService = Get.find<AuthService>();

// Disable auto-login
await authService.setAutoLogin(false);

// Enable auto-login
await authService.setAutoLogin(true);
```

### **4. Clear Persistent Data (Logout)**
```dart
final authService = Get.find<AuthService>();

// Clear all persistent data
await authService.clearPersistentData();
await authService.logout();
```

### **5. Store App Settings Persistently**
```dart
final databaseService = Get.find<DatabaseService>();

// Save setting
await databaseService.savePersistentSetting('theme', 'dark');
await databaseService.savePersistentSetting('language', 'en');

// Retrieve setting
final theme = await databaseService.getPersistentSetting('theme');
final language = await databaseService.getPersistentSetting('language');
```

## Platform-Specific Behavior

### **Android**
- Uses device ID, model, and brand for device identification
- SQLite database survives app deletion if device has sufficient storage
- Works with Android backup and restore

### **iOS**
- Uses `identifierForVendor` for device identification
- SQLite database survives app deletion in most cases
- Compatible with iOS app backup and restore

### **Web**
- Uses browser-specific storage
- Data persists across browser sessions
- Limited by browser storage policies

## Security Considerations

### **1. Device Verification**
- All persistent data is tied to specific device IDs
- Data is automatically cleared if accessed from different device
- Prevents unauthorized access to user data

### **2. Password Security**
- Passwords are hashed before storage
- Simple hash implementation for demo (use bcrypt in production)
- Password hashes are device-specific

### **3. Data Encryption**
- SQLite database can be encrypted (not implemented in demo)
- Consider using SQLCipher for production apps
- Sensitive data should be encrypted at rest

## Testing the Implementation

### **1. Test Persistent Storage**
```bash
# 1. Install and register a user
flutter run

# 2. Uninstall the app
adb uninstall com.app.task

# 3. Reinstall the app
flutter run

# 4. User should be automatically logged in
```

### **2. Test Device Security**
```bash
# 1. Register user on Device A
# 2. Copy database to Device B
# 3. Install app on Device B
# 4. Data should be cleared due to device ID mismatch
```

## Troubleshooting

### **Common Issues**

#### **Auto-login not working**
- Check if `auto_login_enabled` is set to 1
- Verify device ID matches stored device ID
- Check if persistent user data exists

#### **Data not persisting**
- Ensure database version is updated
- Check if device has sufficient storage
- Verify database permissions

#### **Device ID conflicts**
- Clear app data and reinstall
- Check device info generation logic
- Verify unique device characteristics

## Production Recommendations

### **1. Enhanced Security**
- Use SQLCipher for database encryption
- Implement proper password hashing (bcrypt)
- Add biometric authentication
- Use secure key storage

### **2. Data Management**
- Implement data expiration policies
- Add data compression for large datasets
- Monitor storage usage
- Implement data migration strategies

### **3. Privacy Compliance**
- Add user consent for data storage
- Implement data deletion on request
- Provide data export functionality
- Follow GDPR/CCPA guidelines

This implementation provides a robust foundation for persistent user storage that survives app deletion and reinstallation while maintaining security and user experience.
