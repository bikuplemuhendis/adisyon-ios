import Foundation

enum APIError: LocalizedError, Equatable {
    case offline
    case unauthorized
    case forbidden(String)
    case notFound
    case conflict(String)
    case validation(String)
    case server(Int, String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .offline: return "İnternet bağlantısı yok."
        case .unauthorized: return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        case .forbidden(let m): return m.isEmpty ? "Bu işlem için yetkiniz yok." : m
        case .notFound: return "Kayıt bulunamadı."
        case .conflict(let m): return m.isEmpty ? "Kayıt başka bir cihazda değişti, yenileyin." : m
        case .validation(let m): return m.isEmpty ? "Geçersiz bilgi." : m
        case .server(let c, let m): return m.isEmpty ? "Sunucu hatası (\(c))." : m
        case .decoding(let m): return "Yanıt çözümlenemedi: \(m)"
        case .transport(let m): return "Bağlantı hatası: \(m)"
        }
    }
}

/// NestJS hata gövdesi: { message: string | string[], error, statusCode }
struct APIErrorBody: Decodable {
    let message: StringOrArray?
    let error: String?
    let statusCode: Int?

    enum StringOrArray: Decodable {
        case one(String), many([String])
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { self = .one(s) }
            else { self = .many((try? c.decode([String].self)) ?? []) }
        }
        var text: String {
            switch self {
            case .one(let s): return s
            case .many(let a): return a.joined(separator: "\n")
            }
        }
    }
}
