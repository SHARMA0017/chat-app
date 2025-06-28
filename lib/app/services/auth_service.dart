import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import 'database_service.dart';

import '../utils/logger.dart';

class AuthService extends GetxService {
  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';
  
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  final RxBool _isLoggedIn = false.obs;
  
  UserModel? get currentUser => _currentUser.value;
  bool get isLoggedIn => _isLoggedIn.value;
  
  late SharedPreferences _prefs;
  late DatabaseService _databaseService;
  
  Future<AuthService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _databaseService = Get.find<DatabaseService>();
    await _loadUserFromStorage(); // This now handles persistent login
    return this;
  }
  
  Future<void> _loadUserFromStorage() async {
    // First try to load from persistent storage (survives app deletion)
    final persistentUser = await _databaseService.getPersistentUserData();
    if (persistentUser != null) {
      _currentUser.value = persistentUser;
      _isLoggedIn.value = true;
      AppLogger.info('User loaded from persistent storage: ${persistentUser.email}');

      // Also save to SharedPreferences for quick access
      await _saveUserToStorage(persistentUser);
      return;
    }

    // Fallback to SharedPreferences (for backward compatibility)
    final isLoggedIn = _prefs.getBool(_isLoggedInKey) ?? false;
    if (isLoggedIn) {
      final userJson = _prefs.getString(_userKey);
      if (userJson != null) {
        final userMap = jsonDecode(userJson);
        final user = UserModel.fromJson(userMap);
        _currentUser.value = user;
        _isLoggedIn.value = true;
        AppLogger.info('User loaded from SharedPreferences: ${user.email}');

        // Migrate to persistent storage
        await _databaseService.savePersistentUserData(user);
      }
    }
  }
  
  Future<bool> login(String email, String password) async {
    try {
      // In a real app, you would hash and verify the password
      // final hashedPassword = _hashPassword(password);
      
      // Check if user exists in database
      final user = await _databaseService.getUserByEmail(email);
      if (user == null) {
        return false;
      }
      
      // In a real app, you would verify the password hash
      // For this demo, we'll assume the login is successful if user exists
      
      // Save user to storage
      await _saveUserToStorage(user);
      _currentUser.value = user;
      _isLoggedIn.value = true;
      
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }
  
  Future<bool> register({
    required String email,
    required String displayName,
    required String country,
    required String mobile,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      // Validate passwords match
      if (password != confirmPassword) {
        return false;
      }
      
      // Check if user already exists
      final existingUser = await _databaseService.getUserByEmail(email);
      if (existingUser != null) {
        return false;
      }
      
      // Create new user
      final user = UserModel(
        id: _generateUserId(),
        email: email,
        displayName: displayName,
        country: country,
        mobile: mobile,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Save to database
      await _databaseService.insertUser(user);

      // Save user data persistently (survives app deletion)
      final hashedPassword = _hashPassword(password);
      await _databaseService.savePersistentUserData(user, passwordHash: hashedPassword);

      // Save to storage
      await _saveUserToStorage(user);
      _currentUser.value = user;
      _isLoggedIn.value = true;

      AppLogger.info('User registered successfully: ${user.email}');
      return true;
    } catch (e) {
      AppLogger.error('Registration error', 'Auth', e);
      return false;
    }
  }
  
  Future<void> logout() async {
    // Clear SharedPreferences
    await _prefs.remove(_userKey);
    await _prefs.setBool(_isLoggedInKey, false);

    // Clear persistent storage (optional - user might want to keep data)
    // await _databaseService.clearPersistentUserData();

    // Clear current session
    _currentUser.value = null;
    _isLoggedIn.value = false;

    AppLogger.info('User logged out successfully');
  }
  
  Future<void> updateUser(UserModel user) async {
    try {
      await _databaseService.updateUser(user);
      await _saveUserToStorage(user);
      _currentUser.value = user;
    } catch (e) {
      print('Update user error: $e');
    }
  }
  
  Future<void> updateDeviceToken(String token) async {
    if (_currentUser.value != null) {
      final updatedUser = _currentUser.value!.copyWith(
        fcmToken: token,
        updatedAt: DateTime.now(),
      );
      await updateUser(updatedUser);
    }
  }
  
  Future<void> _saveUserToStorage(UserModel user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
    await _prefs.setBool(_isLoggedInKey, true);
  }
  
  // Password hashing method removed - implement proper authentication in production
  
  String _generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  // Email validation
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  // Password validation
  bool isValidPassword(String password) {
    return password.length >= 6;
  }
  
  // Mobile validation
  bool isValidMobile(String mobile) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(mobile);
  }



  /// Hash password for storage (simple implementation for demo)
  String _hashPassword(String password) {
    // In production, use a proper hashing library like bcrypt
    return 'hash_${password.length}_${password.hashCode}';
  }



  /// Enable/disable auto-login for current user
  Future<void> setAutoLogin(bool enabled) async {
    try {
      if (!enabled) {
        await _databaseService.disableAutoLogin();
        AppLogger.info('Auto-login disabled');
      } else if (_currentUser.value != null) {
        // Re-enable by saving current user data
        final hashedPassword = await _databaseService.getPersistentPasswordHash(_currentUser.value!.email);
        if (hashedPassword != null) {
          await _databaseService.savePersistentUserData(_currentUser.value!, passwordHash: hashedPassword);
          AppLogger.info('Auto-login enabled');
        }
      }
    } catch (e) {
      AppLogger.error('Error setting auto-login', 'Auth', e);
    }
  }

  /// Clear all persistent data (for logout)
  Future<void> clearPersistentData() async {
    try {
      await _databaseService.clearPersistentUserData();
      AppLogger.info('Persistent data cleared');
    } catch (e) {
      AppLogger.error('Error clearing persistent data', 'Auth', e);
    }
  }

  /// Check if persistent user data exists
  Future<bool> hasPersistentData() async {
    try {
      return await _databaseService.hasPersistentUserData();
    } catch (e) {
      return false;
    }
  }
}
