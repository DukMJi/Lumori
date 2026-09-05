import Foundation
import Combine
import UserNotifications
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Notification Manager

/// Manages Lumori's notification preference, iOS permission,
/// Firebase Messaging token, and device registration.
///
/// Lumori keeps beacon notifications off by default.
/// Permission is requested only after the user explicitly enables them.
@MainActor
final class NotificationManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared =
        NotificationManager()

    // MARK: - Published Properties

    @Published private(set)
    var isEnabled: Bool

    @Published private(set)
    var authorizationStatus:
        UNAuthorizationStatus = .notDetermined

    @Published private(set)
    var errorMessage: String?

    // MARK: - Storage

    private let preferenceKey =
        "lumori.beaconNotificationsEnabled"

    private let deviceIDKey =
        "lumori.notificationDeviceID"

    // MARK: - Firebase

    private let db =
        Firestore.firestore()

    // MARK: - Token State

    private var latestFCMToken: String?

    // MARK: - Initialization

    init() {

        isEnabled =
            UserDefaults.standard
                .bool(
                    forKey:
                        preferenceKey
                )

        Task {
            await refreshAuthorizationStatus()
        }
    }

    // MARK: - Toggle

    func setEnabled(
        _ enabled: Bool
    ) async {

        errorMessage = nil

        if enabled {

            await enableNotifications()

        } else {

            await disableNotifications()
        }
    }

    // MARK: - Enable

    private func enableNotifications() async {

        let center =
            UNUserNotificationCenter
                .current()

        do {

            let granted =
                try await center
                    .requestAuthorization(
                        options: [
                            .alert
                        ]
                    )

            await refreshAuthorizationStatus()

            guard granted else {

                isEnabled = false

                savePreference(
                    false
                )

                await updateDeviceRegistration(
                    notificationsEnabled:
                        false
                )

                return
            }

            isEnabled = true

            savePreference(
                true
            )

            UIApplication.shared
                .registerForRemoteNotifications()

            await updateDeviceRegistration(
                notificationsEnabled:
                    true
            )

        } catch {

            isEnabled = false

            savePreference(
                false
            )

            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Disable

    private func disableNotifications() async {

        isEnabled = false

        savePreference(
            false
        )

        await updateDeviceRegistration(
            notificationsEnabled:
                false
        )
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() async {

        let settings =
            await UNUserNotificationCenter
                .current()
                .notificationSettings()

        authorizationStatus =
            settings.authorizationStatus

        if authorizationStatus == .denied {

            isEnabled = false

            savePreference(
                false
            )

            await updateDeviceRegistration(
                notificationsEnabled:
                    false
            )
        }
    }

    // MARK: - FCM Token

    /// Receives the latest Firebase Messaging token.
    ///
    /// The token may arrive before or after the user enables notifications,
    /// so Lumori stores it in memory and updates Firestore whenever possible.
    func handleFCMToken(
        _ token: String
    ) async {

        latestFCMToken =
            token

        await updateDeviceRegistration(
            notificationsEnabled:
                isEnabled
        )
    }

    // MARK: - Device Registration

    private func updateDeviceRegistration(
        notificationsEnabled: Bool
    ) async {

        guard let user =
                Auth.auth().currentUser
        else {
            return
        }

        guard let token =
                latestFCMToken
        else {
            return
        }

        let deviceID =
            persistentDeviceID()

        let deviceReference =
            db
                .collection(
                    "users"
                )
                .document(
                    user.uid
                )
                .collection(
                    "devices"
                )
                .document(
                    deviceID
                )

        do {

            try await deviceReference
                .setData(
                    [
                        "fcmToken":
                            token,

                        "notificationsEnabled":
                            notificationsEnabled,

                        "updatedAt":
                            FieldValue
                                .serverTimestamp()
                    ],
                    merge: true
                )

            print(
                "📡 Notification device registration updated"
            )

        } catch {

            print(
                "🔥 Unable to update notification device registration:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Device ID

    private func persistentDeviceID()
        -> String {

        if let existing =
            UserDefaults.standard
                .string(
                    forKey:
                        deviceIDKey
                ) {

            return existing
        }

        let newID =
            UUID()
                .uuidString

        UserDefaults.standard
            .set(
                newID,
                forKey:
                    deviceIDKey
            )

        return newID
    }

    // MARK: - Open Settings

    func openSystemSettings() {

        guard let url =
                URL(
                    string:
                        UIApplication
                            .openSettingsURLString
                )
        else {
            return
        }

        UIApplication.shared
            .open(url)
    }

    // MARK: - Persistence

    private func savePreference(
        _ enabled: Bool
    ) {

        UserDefaults.standard
            .set(
                enabled,
                forKey:
                    preferenceKey
            )
    }
}
