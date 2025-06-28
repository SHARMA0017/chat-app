import 'package:flutter/foundation.dart';

/// Simple logging utility for the app
/// In production, this can be replaced with a more sophisticated logging solution
class AppLogger {
  static const String _tag = 'ChatApp';

  /// Log debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      print('[$_tag${tag != null ? ':$tag' : ''}] DEBUG: $message');
    }
  }

  /// Log information (always shown)
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      print('[$_tag${tag != null ? ':$tag' : ''}] INFO: $message');
    }
  }

  /// Log warnings (always shown)
  static void warning(String message, [String? tag]) {
    print('[$_tag${tag != null ? ':$tag' : ''}] WARNING: $message');
  }

  /// Log errors (always shown)
  static void error(String message, [String? tag, Object? error]) {
    print('[$_tag${tag != null ? ':$tag' : ''}] ERROR: $message');
    if (error != null) {
      print('[$_tag${tag != null ? ':$tag' : ''}] ERROR DETAILS: $error');
    }
  }

  /// Log FCM related messages
  static void fcm(String message) {
    debug(message, 'FCM');
  }

  /// Log database related messages
  static void database(String message) {
    debug(message, 'DB');
  }

  /// Log authentication related messages
  static void auth(String message) {
    debug(message, 'AUTH');
  }

  /// Log QR code related messages
  static void qr(String message) {
    debug(message, 'QR');
  }

  /// Log maps related messages
  static void maps(String message) {
    debug(message, 'MAPS');
  }
}
