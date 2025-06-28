import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../utils/logger.dart';

class DatabaseService extends GetxService {
  static Database? _database;
  
  Database get database => _database!;
  
  Future<DatabaseService> init() async {
    await _initDatabase();
    return this;
  }
  
  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'chat_app_persistent.db');

    AppLogger.info('Database path: $path');

    _database = await openDatabase(
      path,
      version: 2, // Updated version for persistent storage
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    AppLogger.info('Database initialized successfully');
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        display_name TEXT NOT NULL,
        country TEXT NOT NULL,
        mobile TEXT NOT NULL,
        fcm_token TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Create messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT DEFAULT 'text',
        status TEXT DEFAULT 'sent',
        timestamp INTEGER NOT NULL,
        delivered_at INTEGER,
        read_at INTEGER,
        is_from_current_user INTEGER DEFAULT 0
      )
    ''');

    // Create chat_rooms table for better organization
    await db.execute('''
      CREATE TABLE chat_rooms (
        id TEXT PRIMARY KEY,
        participant1Id TEXT NOT NULL,
        participant2Id TEXT NOT NULL,
        lastMessageId TEXT,
        lastMessageTime INTEGER,
        createdAt INTEGER NOT NULL,
        UNIQUE(participant1Id, participant2Id)
      )
    ''');

    // Create persistent storage tables
    await _createPersistentTables(db);
  }
  
  /// Create persistent storage tables that survive app deletion
  Future<void> _createPersistentTables(Database db) async {
    // Device information table - stores device-specific data
    await db.execute('''
      CREATE TABLE device_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT UNIQUE NOT NULL,
        device_model TEXT,
        device_brand TEXT,
        os_version TEXT,
        app_version TEXT,
        installation_id TEXT,
        first_install_date INTEGER,
        last_access_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Persistent user data table - stores user info that survives app deletion
    await db.execute('''
      CREATE TABLE persistent_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        display_name TEXT NOT NULL,
        country TEXT,
        mobile TEXT,
        fcm_token TEXT,
        password_hash TEXT,
        last_login_date INTEGER,
        auto_login_enabled INTEGER DEFAULT 1,
        user_created_at INTEGER,
        user_updated_at INTEGER,
        stored_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(device_id, user_id)
      )
    ''');

    // User sessions table - tracks login sessions
    await db.execute('''
      CREATE TABLE user_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        session_token TEXT,
        login_timestamp INTEGER NOT NULL,
        logout_timestamp INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    // App settings that persist across installations
    await db.execute('''
      CREATE TABLE persistent_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        setting_key TEXT NOT NULL,
        setting_value TEXT,
        setting_type TEXT DEFAULT 'string',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(device_id, setting_key)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add persistent storage tables for version 2
      await _createPersistentTables(db);
    }
  }
  
  // User operations
  Future<int> insertUser(UserModel user) async {
    return await database.insert('users', user.toDatabase());
  }

  Future<UserModel?> getUserById(String id) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromDatabase(maps.first);
    }
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromDatabase(maps.first);
    }
    return null;
  }

  Future<int> updateUser(UserModel user) async {
    return await database.update(
      'users',
      user.toDatabase(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
  
  // Message operations
  Future<int> insertMessage(MessageModel message) async {
    return await database.insert('messages', message.toDatabase());
  }

  Future<List<MessageModel>> getMessages(String userId1, String userId2) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return MessageModel.fromDatabase(maps[i]);
    });
  }

  Future<MessageModel?> getMessageById(String messageId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MessageModel.fromDatabase(maps.first);
    }
    return null;
  }
  
  Future<int> markMessageAsRead(String messageId) async {
    return await database.update(
      'messages',
      {'status': 'read', 'read_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
  
  Future<int> deleteMessage(String messageId) async {
    return await database.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
  
  // Chat room operations
  Future<int> createChatRoom(String participant1Id, String participant2Id) async {
    // Create a consistent chat room ID regardless of order
    final sortedIds = [participant1Id, participant2Id]..sort();
    final chatRoomId = '${sortedIds[0]}_${sortedIds[1]}';

    final chatRoom = {
      'id': chatRoomId,
      'participant1Id': sortedIds[0],
      'participant2Id': sortedIds[1],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      return await database.insert('chat_rooms', chatRoom);
    } catch (e) {
      // If chat room already exists, return 0 (no error)
      if (e.toString().contains('UNIQUE constraint failed')) {
        print('Chat room already exists: $chatRoomId');
        return 0;
      }
      rethrow;
    }
  }

  Future<void> updateChatRoomLastMessage(String participant1Id, String participant2Id, String messageId) async {
    final sortedIds = [participant1Id, participant2Id]..sort();
    final chatRoomId = '${sortedIds[0]}_${sortedIds[1]}';

    await database.update(
      'chat_rooms',
      {
        'lastMessageId': messageId,
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [chatRoomId],
    );
  }
  
  Future<List<Map<String, dynamic>>> getChatRooms(String userId) async {
    final chatRooms = await database.query(
      'chat_rooms',
      where: 'participant1Id = ? OR participant2Id = ?',
      whereArgs: [userId, userId],
      orderBy: 'lastMessageTime DESC',
    );

    // Enrich chat rooms with user information
    final enrichedChatRooms = <Map<String, dynamic>>[];
    for (final room in chatRooms) {
      final participant1Id = room['participant1Id'] as String;
      final participant2Id = room['participant2Id'] as String;

      // Get the other participant (not the current user)
      final otherUserId = participant1Id == userId ? participant2Id : participant1Id;
      final otherUser = await getUserById(otherUserId);

      final enrichedRoom = Map<String, dynamic>.from(room);
      enrichedRoom['otherUserId'] = otherUserId;
      enrichedRoom['otherUserName'] = otherUser?.displayName ?? 'Unknown User';
      enrichedRoom['otherUserEmail'] = otherUser?.email ?? '';

      // Get last message content if available
      if (room['lastMessageId'] != null) {
        final lastMessage = await getMessageById(room['lastMessageId'] as String);
        enrichedRoom['lastMessageContent'] = lastMessage?.content ?? '';
      }

      enrichedChatRooms.add(enrichedRoom);
    }

    return enrichedChatRooms;
  }
  
  // ============================================================================
  // PERSISTENT STORAGE METHODS (Survive app deletion and reinstallation)
  // ============================================================================

  /// Get or create device ID that persists across app installations
  Future<String> getOrCreateDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceIdentifier;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceIdentifier = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
        AppLogger.info('Android device ID: ${deviceIdentifier.substring(0, 20)}...');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceIdentifier = '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemName}';
        AppLogger.info('iOS device ID: ${deviceIdentifier.substring(0, 20)}...');
      } else {
        deviceIdentifier = 'web_${DateTime.now().millisecondsSinceEpoch}';
        AppLogger.info('Web device ID: $deviceIdentifier');
      }

      // Check if device already exists
      final existingDevice = await _database!.query(
        'device_info',
        where: 'device_id = ?',
        whereArgs: [deviceIdentifier],
        limit: 1,
      );

      if (existingDevice.isEmpty) {
        // Create new device record
        await _database!.insert('device_info', {
          'device_id': deviceIdentifier,
          'device_model': Platform.isAndroid
              ? (await deviceInfo.androidInfo).model
              : Platform.isIOS
                  ? (await deviceInfo.iosInfo).model
                  : 'web',
          'device_brand': Platform.isAndroid
              ? (await deviceInfo.androidInfo).brand
              : Platform.isIOS
                  ? 'Apple'
                  : 'web',
          'os_version': Platform.isAndroid
              ? (await deviceInfo.androidInfo).version.release
              : Platform.isIOS
                  ? (await deviceInfo.iosInfo).systemVersion
                  : 'web',
          'app_version': '1.0.0',
          'installation_id': 'install_${DateTime.now().millisecondsSinceEpoch}',
          'first_install_date': DateTime.now().millisecondsSinceEpoch,
          'last_access_date': DateTime.now().millisecondsSinceEpoch,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        AppLogger.info('Created new device record: ${deviceIdentifier.substring(0, 20)}...');
      } else {
        // Update last access date
        await _database!.update(
          'device_info',
          {
            'last_access_date': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'device_id = ?',
          whereArgs: [deviceIdentifier],
        );
      }

      return deviceIdentifier;
    } catch (e) {
      AppLogger.error('Error getting device ID', 'DB', e);
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Save user data persistently (survives app deletion)
  Future<bool> savePersistentUserData(UserModel user, {String? passwordHash}) async {
    try {
      final deviceId = await getOrCreateDeviceId();

      final userData = {
        'device_id': deviceId,
        'user_id': user.id,
        'email': user.email,
        'display_name': user.displayName,
        'country': user.country,
        'mobile': user.mobile,
        'fcm_token': user.fcmToken,
        'password_hash': passwordHash,
        'last_login_date': DateTime.now().millisecondsSinceEpoch,
        'auto_login_enabled': 1,
        'user_created_at': user.createdAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        'user_updated_at': user.updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        'stored_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _database!.insert(
        'persistent_users',
        userData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      AppLogger.info('User data saved persistently for: ${user.email}');
      return true;
    } catch (e) {
      AppLogger.error('Error saving persistent user data', 'DB', e);
      return false;
    }
  }

  /// Get persistent user data (available after app reinstallation)
  Future<UserModel?> getPersistentUserData() async {
    try {
      final deviceId = await getOrCreateDeviceId();

      final results = await _database!.query(
        'persistent_users',
        where: 'device_id = ? AND auto_login_enabled = 1',
        whereArgs: [deviceId],
        orderBy: 'last_login_date DESC',
        limit: 1,
      );

      if (results.isEmpty) {
        AppLogger.info('No persistent user data found for device');
        return null;
      }

      final userData = results.first;
      final user = UserModel(
        id: userData['user_id'] as String,
        email: userData['email'] as String,
        displayName: userData['display_name'] as String,
        country: userData['country'] as String,
        mobile: userData['mobile'] as String,
        fcmToken: userData['fcm_token'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(userData['user_created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(userData['user_updated_at'] as int),
      );

      AppLogger.info('Retrieved persistent user data for: ${user.email}');
      return user;
    } catch (e) {
      AppLogger.error('Error retrieving persistent user data', 'DB', e);
      return null;
    }
  }

  /// Get stored password hash for auto-login
  Future<String?> getPersistentPasswordHash(String email) async {
    try {
      final deviceId = await getOrCreateDeviceId();

      final results = await _database!.query(
        'persistent_users',
        columns: ['password_hash'],
        where: 'device_id = ? AND email = ?',
        whereArgs: [deviceId, email],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first['password_hash'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error retrieving password hash', 'DB', e);
      return null;
    }
  }

  /// Save user session
  Future<void> savePersistentSession(String userId, String sessionToken) async {
    try {
      final deviceId = await getOrCreateDeviceId();

      await _database!.insert('user_sessions', {
        'device_id': deviceId,
        'user_id': userId,
        'session_token': sessionToken,
        'login_timestamp': DateTime.now().millisecondsSinceEpoch,
        'is_active': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      AppLogger.error('Error saving session', 'DB', e);
    }
  }

  /// Clear persistent user data
  Future<void> clearPersistentUserData() async {
    try {
      final deviceId = await getOrCreateDeviceId();

      await _database!.delete(
        'persistent_users',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      await _database!.delete(
        'user_sessions',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      AppLogger.info('Persistent user data cleared');
    } catch (e) {
      AppLogger.error('Error clearing persistent user data', 'DB', e);
    }
  }

  /// Disable auto-login for current device
  Future<void> disableAutoLogin() async {
    try {
      final deviceId = await getOrCreateDeviceId();

      await _database!.update(
        'persistent_users',
        {'auto_login_enabled': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      AppLogger.info('Auto-login disabled');
    } catch (e) {
      AppLogger.error('Error disabling auto-login', 'DB', e);
    }
  }

  /// Save persistent app setting
  Future<void> savePersistentSetting(String key, String value, {String type = 'string'}) async {
    try {
      final deviceId = await getOrCreateDeviceId();

      await _database!.insert(
        'persistent_settings',
        {
          'device_id': deviceId,
          'setting_key': key,
          'setting_value': value,
          'setting_type': type,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      AppLogger.error('Error saving persistent setting', 'DB', e);
    }
  }

  /// Get persistent app setting
  Future<String?> getPersistentSetting(String key) async {
    try {
      final deviceId = await getOrCreateDeviceId();

      final results = await _database!.query(
        'persistent_settings',
        columns: ['setting_value'],
        where: 'device_id = ? AND setting_key = ?',
        whereArgs: [deviceId, key],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first['setting_value'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error retrieving persistent setting', 'DB', e);
      return null;
    }
  }

  /// Check if persistent user data exists
  Future<bool> hasPersistentUserData() async {
    try {
      final deviceId = await getOrCreateDeviceId();

      final results = await _database!.query(
        'persistent_users',
        where: 'device_id = ?',
        whereArgs: [deviceId],
        limit: 1,
      );

      return results.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> close() async {
    await _database?.close();
  }
}
