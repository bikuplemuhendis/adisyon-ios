import Foundation
import UIKit
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseCore
import FirebaseMessaging
#endif

/// Push bildirimleri. `PUSH_ENABLED=YES` olmadan hiçbir şey yapmaz.
///
/// - Firebase SDK (FirebaseMessaging) projeye eklenmişse FCM token'ı kaydedilir
///   (backend FCM ile gönderiyor; Android ile aynı kanal).
/// - Eklenmemişse ham APNs token'ı hex olarak kaydedilir.
/// Kayıt: POST /api/devices { token, platform: "ios", branchId }
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()

    private(set) var deviceToken: String?
    private var lastSyncedKey: String?
    private weak var pendingAPI: APIClient?
    private var pendingBranch: String?

    func configureFirebaseIfAvailable() {
        #if canImport(FirebaseMessaging)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
        }
        #endif
    }

    func requestAuthorizationIfEnabled() async {
        guard AppConfig.pushEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didReceiveAPNsToken(_ data: Data) {
        #if canImport(FirebaseMessaging)
        if FirebaseApp.app() != nil {
            Messaging.messaging().apnsToken = data
            return // FCM token delegate ile gelir
        }
        #endif
        let hex = data.map { String(format: "%02x", $0) }.joined()
        updateToken(hex)
    }

    fileprivate func updateToken(_ token: String) {
        deviceToken = token
        if let api = pendingAPI {
            Task { await syncTokenIfNeeded(api: api, branchId: pendingBranch) }
        }
    }

    func syncTokenIfNeeded(api: APIClient, branchId: String?, force: Bool = false) async {
        guard AppConfig.pushEnabled else { return }
        pendingAPI = api
        pendingBranch = branchId
        guard let token = deviceToken else { return }
        let key = "\(token)|\(branchId ?? "-")"
        if !force && key == lastSyncedKey { return }
        do {
            _ = try await api.registerDevice(token: token, branchId: branchId)
            lastSyncedKey = key
        } catch {
            print("[Push] cihaz kaydı başarısız: \(error.localizedDescription)")
        }
    }
}

#if canImport(FirebaseMessaging)
extension PushManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in PushManager.shared.updateToken(fcmToken) }
    }
}
#endif
