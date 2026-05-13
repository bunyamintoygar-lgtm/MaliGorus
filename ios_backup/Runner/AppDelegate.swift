import Flutter
import UIKit
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Push notification izni
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions
    ) { granted, error in
      print(">>> APNs Permission granted: \(granted), error: \(String(describing: error))")
    }

    // APNs'e kayıt ol — ARKA PLAN PUSH İÇİN ZORUNLU
    application.registerForRemoteNotifications()

    // Firebase Messaging delegate
    Messaging.messaging().delegate = self

    // PLUGIN KAYDI
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs device token → Firebase'e aktar (ARKA PLAN İÇİN KRİTİK)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print(">>> APNs Device Token RECEIVED: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs kayıt başarısız olursa logla
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print(">>> APNs REGISTRATION FAILED: \(error.localizedDescription)")
  }

  // Arka planda gelen push bildirimi
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print(">>> BACKGROUND PUSH RECEIVED: \(userInfo)")
    completionHandler(.newData)
  }

  // Firebase FCM token
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print(">>> Firebase FCM Token: \(fcmToken ?? "nil")")
  }
}
