import Foundation

/// Derleme zamanı yapılandırması (Info.plist → build settings).
enum AppConfig {
    static let defaultBaseURL = URL(string: "https://api.adisyonyonetim.com.tr/api")!

    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !raw.isEmpty, !raw.hasPrefix("$("), let url = URL(string: raw) {
            return url
        }
        return defaultBaseURL
    }

    /// Push bildirimleri bayrağı. GoogleService-Info.plist / APNs ayarlanmadan açmayın.
    static var pushEnabled: Bool {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "PUSH_ENABLED") as? String ?? "NO").uppercased()
        return raw == "YES" || raw == "TRUE" || raw == "1"
    }

    /// Kimlik içermeyen genel User-Agent.
    static let userAgent = "AdisyonYonetim-iOS/1.0"

    /// Canlı güncelleme için yoklama aralığı (sn).
    static let pollInterval: TimeInterval = 5

    static let defaultBusinessSlug = "demo-kafe"
}
