import Foundation
import SwiftUI

/// Uygulama genel durumu: oturum, şube seçimi, API istemcisi.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable { case launching, loggedOut, needsBranch, ready }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var user: AuthUser?
    @Published var branchName: String?
    @Published var bannerError: String?

    let api: APIClient
    private let store: TokenStore

    init(store: TokenStore? = nil) {
        #if canImport(Security)
        let s = store ?? KeychainTokenStore()
        #else
        let s = store ?? InMemoryTokenStore()
        #endif
        self.store = s
        let relay = SessionRelay()
        self.api = APIClient(
            store: s,
            onSessionExpired: { [relay] in Task { @MainActor in relay.target?.handleExpired() } },
            onSessionUpdated: { [relay] session in Task { @MainActor in relay.target?.user = session.user } }
        )
        relay.target = self
    }

    func bootstrap() async {
        guard let session = store.load() else { phase = .loggedOut; return }
        user = session.user
        do {
            let me = try await api.me()
            var updated = session
            updated.user = me
            store.save(updated)
            user = me
            if let bid = me.selectedBranchId {
                branchName = (try? await api.branches())?.first { $0.id == bid }?.name ?? branchName
            }
            phase = me.selectedBranchId == nil ? .needsBranch : .ready
            await PushManager.shared.syncTokenIfNeeded(api: api, branchId: me.selectedBranchId)
        } catch APIError.offline {
            // Çevrimdışı: kayıtlı oturumla devam et; ekranlar yeniden deneme gösterir.
            phase = session.user.selectedBranchId == nil ? .needsBranch : .ready
        } catch {
            phase = .loggedOut
        }
    }

    func didAuthenticate(_ auth: AuthResponse) async throws {
        let session = try await api.saveSession(from: auth)
        user = session.user
        let branches = (try? await api.branches()) ?? []
        if let bid = session.user.selectedBranchId {
            branchName = branches.first { $0.id == bid }?.name
        }
        if session.user.selectedBranchId == nil || branches.count > 1 {
            phase = .needsBranch
        } else {
            phase = .ready
        }
        await PushManager.shared.requestAuthorizationIfEnabled()
        await PushManager.shared.syncTokenIfNeeded(api: api, branchId: session.user.selectedBranchId)
    }

    func selectBranch(_ branch: Branch) async throws {
        let auth = try await api.selectBranch(branch.id)
        let session = try await api.saveSession(from: auth)
        user = session.user
        branchName = branch.name
        phase = .ready
        await PushManager.shared.syncTokenIfNeeded(api: api, branchId: branch.id, force: true)
    }

    func changeBranch() { phase = .needsBranch }

    func logout() async {
        if let token = PushManager.shared.deviceToken {
            _ = try? await api.unregisterDevice(token: token)
        }
        if let s = await api.currentSession() {
            await api.logout(refreshToken: s.refreshToken)
        }
        await api.clearSession()
        user = nil
        branchName = nil
        phase = .loggedOut
    }

    private func handleExpired() {
        guard phase != .loggedOut else { return }
        user = nil
        bannerError = APIError.unauthorized.errorDescription
        phase = .loggedOut
    }
}

/// API istemcisinden AppState'e zayıf referanslı olay köprüsü.
private final class SessionRelay: @unchecked Sendable {
    weak var target: AppState?
}
