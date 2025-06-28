import Flutter
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TODO: Add your Google Maps API key here
    // GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

    // Configure APNs
    configureAPNs(application)

    GeneratedPluginRegistrant.register(with: self)

    // Firebase will be initialized by the Flutter plugin
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAPNs(_ application: UIApplication) {
    // Request notification permissions
    UNUserNotificationCenter.current().delegate = self

    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        if granted {
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
          }
        }
      }
    )
  }

  // Handle successful APNs registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()

    // Send token to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.app.task/apns", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onTokenReceived", arguments: token)
    }
  }

  // Handle APNs registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error)")

    // Send error to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.app.task/apns", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onTokenError", arguments: error.localizedDescription)
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
  // Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo

    // Send to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.app.task/apns", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onMessageReceived", arguments: userInfo)
    }

    // Show notification even when app is in foreground
    completionHandler([.alert, .badge, .sound])
  }

  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    // Send to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.app.task/apns", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onNotificationTapped", arguments: userInfo)
    }

    completionHandler()
  }
}
