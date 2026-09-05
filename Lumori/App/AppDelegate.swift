import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

// MARK: - App Delegate

/// Handles Apple Push Notification registration and Firebase Messaging.
///
/// Lumori uses SwiftUI for its app lifecycle, but APNs and FCM still rely
/// on UIApplicationDelegate callbacks for device-token registration.
final class AppDelegate:
    NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate,
    MessagingDelegate {

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        UNUserNotificationCenter.current()
            .delegate = self

        Messaging.messaging()
            .delegate = self

        return true
    }

    // MARK: - APNs Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {

        Messaging.messaging()
            .apnsToken = deviceToken

        print(
            "📲 APNs device token registered"
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {

        print(
            "🔥 APNs registration failed:",
            error.localizedDescription
        )
    }

    // MARK: - Firebase Messaging

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {

        guard let fcmToken else {
            return
        }

        print(
            "📨 FCM token received:"
        )

        print(
            fcmToken
        )

        Task {
            await NotificationManager
                .shared
                .handleFCMToken(
                    fcmToken
                )
        }
    }

    // MARK: - Foreground Notification Presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {

        /*
         Lumori notifications remain quiet while the app is open.

         We show the banner but do not request sound here.
         */
        completionHandler([
            .banner
        ])
    }
}
