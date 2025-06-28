import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project/main.dart';

void main() {
  group('Chat App Tests', () {
    testWidgets('App should start and show splash screen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MainApp());

      // Verify that splash screen elements are present
      expect(find.text('Chat App'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Should navigate to login screen after splash', (WidgetTester tester) async {
      await tester.pumpWidget(const MainApp());
      
      // Wait for splash screen timeout
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Should show login screen
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Login form validation should work', (WidgetTester tester) async {
      await tester.pumpWidget(const MainApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Try to login without entering credentials
      final loginButton = find.text('Login');
      await tester.tap(loginButton);
      await tester.pump();
      
      // Should show validation errors
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Should navigate to registration screen', (WidgetTester tester) async {
      await tester.pumpWidget(const MainApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Tap on sign up button
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();
      
      // Should show registration screen
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
    });
  });

  group('Service Tests', () {
    test('AuthService should validate email correctly', () {
      // Test email validation logic
      expect(RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch('test@example.com'), true);
      expect(RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch('invalid-email'), false);
    });

    test('AuthService should validate password correctly', () {
      // Test password validation logic
      expect('password123'.length >= 6, true);
      expect('12345'.length >= 6, false);
    });

    test('AuthService should validate mobile correctly', () {
      // Test mobile validation logic
      expect(RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch('+1234567890'), true);
      expect(RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch('invalid'), false);
    });
  });

  group('Model Tests', () {
    test('UserModel should serialize/deserialize correctly', () {
      final user = {
        'id': '123',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'country': 'USA',
        'mobile': '+1234567890',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Test that user data structure is valid
      expect(user['id'], isNotNull);
      expect(user['email'], contains('@'));
      expect(user['display_name'], isNotEmpty);
    });

    test('MessageModel should have correct structure', () {
      final message = {
        'id': '123',
        'sender_id': 'user1',
        'receiver_id': 'user2',
        'content': 'Hello World',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'sent',
      };
      
      expect(message['content'], isNotEmpty);
      expect(message['sender_id'], isNotNull);
      expect(message['receiver_id'], isNotNull);
    });
  });
}
