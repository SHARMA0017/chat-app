class AppConstants {
  // App Info
  static const String appName = 'ChatApp';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Flutter Multi-Platform Messaging Application';

  // API URLs
  static const String countriesApiUrl = 'https://restcountries.com/v3.1/all?fields=name';

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String languageKey = 'language';
  static const String fcmTokenKey = 'fcm_token';
  static const String isLoggedInKey = 'is_logged_in';

  // Database
  static const String databaseName = 'chat_app.db';
  static const int databaseVersion = 1;

  // Tables
  static const String usersTable = 'users';
  static const String messagesTable = 'messages';
  static const String conversationsTable = 'conversations';
  static const String chatRoomsTable = 'chat_rooms';

  // QR Code
  static const String qrCodePrefix = 'chat_token:';
  static const String qrCodeUserPrefix = 'chat_user:';

  // Maps
  static const double defaultMapZoom = 14.0;
  static const double boundaryRadiusKm = 2.0;
  static const double waterBodyRadiusMeters = 500.0;

  // FCM
  static const int minFcmTokenLength = 100;
  static const String fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxDisplayNameLength = 50;
  static const int maxMessageLength = 1000;

  // Timeouts
  static const int networkTimeoutSeconds = 30;
  static const int locationTimeoutSeconds = 10;
  static const int splashDelaySeconds = 3;

  // UI
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const int animationDurationMs = 300;
  
  // Firebase
  static const String firebaseTopicPrefix = 'user_';

  // Additional UI Constants
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}
