import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case email = "E-posta", pin = "Personel PIN"
        var id: String { rawValue }
    }

    @Published var mode: Mode = .email
    @Published var email = ""
    @Published var password = ""
    @Published var businessSlug: String = UserDefaults.standard.string(forKey: "businessSlug") ?? AppConfig.defaultBusinessSlug
    @Published var businessName: String?
    @Published var pin = ""
    @Published var totpCode = ""
    @Published var pendingToken: String?
    @Published var isLoading = false
    @Published var error: String?

    var canSubmitEmail: Bool { email.contains("@") && password.count >= 8 && !isLoading }
    var canSubmitPin: Bool { (4...8).contains(pin.count) && !businessSlug.isEmpty && !isLoading }

    func loginEmail(state: AppState) async {
        await run(state) {
            try await state.api.login(email: self.email.trimmingCharacters(in: .whitespaces).lowercased(),
                                      password: self.password)
        }
    }

    func loginPin(state: AppState) async {
        await run(state) {
            let slug = self.businessSlug.trimmingCharacters(in: .whitespaces).lowercased()
            let boot = try await state.api.bootstrap(slug: slug)
            guard let bid = boot.businessId else { throw APIError.validation("İşletme bulunamadı: \(slug)") }
            UserDefaults.standard.set(slug, forKey: "businessSlug")
            self.businessName = boot.name
            return try await state.api.pinLogin(businessId: bid, pin: self.pin)
        }
    }

    func verify2fa(state: AppState) async {
        guard let token = pendingToken else { return }
        await run(state) { try await state.api.verify2fa(pendingToken: token, code: self.totpCode) }
    }

    private func run(_ state: AppState, _ op: @escaping () async throws -> AuthResponse) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let res = try await op()
            if res.requires2fa == true, let t = res.pendingToken {
                pendingToken = t
                return
            }
            pendingToken = nil
            pin = ""
            password = ""
            try await state.didAuthenticate(res)
        } catch {
            self.error = errorText(error)
            pin = ""
        }
    }
}
