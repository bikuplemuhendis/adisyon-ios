import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum HTTPMethod: String { case GET, POST, PATCH, DELETE }

/// async/await URLSession istemcisi.
/// - `Authorization: Bearer`, `X-Business-Id`, `X-Branch-Id` başlıklarını ekler (dashboard ile aynı).
/// - 401'de refresh token ile tek seferlik yenileme yapar; eşzamanlı istekler aynı yenilemeyi bekler.
actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let store: TokenStore
    private var refreshTask: Task<StoredSession, Error>?

    /// Oturum tamamen düştüğünde (refresh başarısız) çağrılır.
    nonisolated let onSessionExpired: @Sendable () -> Void
    /// Token yenilendiğinde çağrılır (UI'daki kullanıcıyı güncellemek için).
    nonisolated let onSessionUpdated: @Sendable (StoredSession) -> Void

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL = AppConfig.baseURL,
         store: TokenStore,
         session: URLSession? = nil,
         onSessionExpired: @escaping @Sendable () -> Void = {},
         onSessionUpdated: @escaping @Sendable (StoredSession) -> Void = { _ in }) {
        self.baseURL = baseURL
        self.store = store
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 20
            #if !canImport(FoundationNetworking)
            cfg.waitsForConnectivity = false
            #endif
            cfg.httpAdditionalHeaders = ["User-Agent": AppConfig.userAgent, "Accept": "application/json"]
            self.session = URLSession(configuration: cfg)
        }
        self.onSessionExpired = onSessionExpired
        self.onSessionUpdated = onSessionUpdated
    }

    // MARK: Public API

    func get<T: Decodable>(_ path: String, query: [String: String] = [:], auth: Bool = true) async throws -> T {
        try await send(.GET, path, query: query, body: Optional<EmptyBody>.none, auth: auth)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool = true, headers: [String: String] = [:]) async throws -> T {
        try await send(.POST, path, body: body, auth: auth, headers: headers)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(.PATCH, path, body: body)
    }

    func delete<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(.DELETE, path, body: body)
    }

    // MARK: Core

    func send<T: Decodable, B: Encodable>(_ method: HTTPMethod,
                                          _ path: String,
                                          query: [String: String] = [:],
                                          body: B?,
                                          auth: Bool = true,
                                          headers: [String: String] = [:]) async throws -> T {
        let bodyData = try body.map { try encoder.encode($0) }
        var current = auth ? store.load() : nil
        var request = try makeRequest(method, path, query: query, body: bodyData, session: current, headers: headers)
        var (data, response) = try await perform(request)

        if response.statusCode == 401, auth, current != nil {
            current = try await refreshedSession()
            request = try makeRequest(method, path, query: query, body: bodyData, session: current, headers: headers)
            (data, response) = try await perform(request)
            if response.statusCode == 401 {
                await expire()
                throw APIError.unauthorized
            }
        }
        return try decode(T.self, data: data, response: response)
    }

    private func makeRequest(_ method: HTTPMethod, _ path: String, query: [String: String],
                             body: Data?, session: StoredSession?, headers: [String: String]) throws -> URLRequest {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(trimmed), resolvingAgainstBaseURL: false) else {
            throw APIError.transport("Geçersiz adres")
        }
        if !query.isEmpty {
            comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.transport("Geçersiz adres") }
        var r = URLRequest(url: url)
        r.httpMethod = method.rawValue
        r.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            r.httpBody = body
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let s = session {
            r.setValue("Bearer \(s.accessToken)", forHTTPHeaderField: "Authorization")
            if let b = s.user.businessId { r.setValue(b, forHTTPHeaderField: "X-Business-Id") }
            if let br = s.user.selectedBranchId { r.setValue(br, forHTTPHeaderField: "X-Branch-Id") }
        }
        headers.forEach { r.setValue($0.value, forHTTPHeaderField: $0.key) }
        return r
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, resp) = try await session.data(for: request)
            guard let http = resp as? HTTPURLResponse else { throw APIError.transport("Geçersiz yanıt") }
            return (data, http)
        } catch let e as APIError {
            throw e
        } catch let e as URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost, .timedOut:
                throw APIError.offline
            default:
                throw APIError.transport(e.localizedDescription)
            }
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, data: Data, response: HTTPURLResponse) throws -> T {
        let code = response.statusCode
        guard (200..<300).contains(code) else {
            let msg = (try? decoder.decode(APIErrorBody.self, from: data))?.message?.text ?? ""
            switch code {
            case 400, 422: throw APIError.validation(msg)
            case 401: throw APIError.unauthorized
            case 403: throw APIError.forbidden(msg)
            case 404: throw APIError.notFound
            case 409: throw APIError.conflict(msg)
            default: throw APIError.server(code, msg)
            }
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        // Nest `null` döndürebilir (örn. /shifts/current) veya boş gövde.
        let payload = data.isEmpty ? Data("null".utf8) : data
        do {
            return try decoder.decode(T.self, from: payload)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: Refresh

    private func refreshedSession() async throws -> StoredSession {
        if let task = refreshTask { return try await task.value }
        guard let old = store.load() else { throw APIError.unauthorized }
        let task = Task<StoredSession, Error> { [baseURL, session, decoder, encoder] in
            var r = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
            r.httpBody = try encoder.encode(RefreshRequest(refreshToken: old.refreshToken))
            let (data, resp) = try await session.data(for: r)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.unauthorized
            }
            let auth = try decoder.decode(AuthResponse.self, from: data)
            guard let access = auth.accessToken, let refresh = auth.refreshToken else { throw APIError.unauthorized }
            return StoredSession(accessToken: access, refreshToken: refresh, user: auth.user ?? old.user)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let fresh = try await task.value
            store.save(fresh)
            onSessionUpdated(fresh)
            return fresh
        } catch {
            await expire()
            throw APIError.unauthorized
        }
    }

    private func expire() async {
        store.clear()
        onSessionExpired()
    }

    // MARK: Session helpers

    func currentSession() -> StoredSession? { store.load() }

    func saveSession(from auth: AuthResponse) throws -> StoredSession {
        guard let a = auth.accessToken, let r = auth.refreshToken, let u = auth.user else {
            throw APIError.decoding("Eksik oturum bilgisi")
        }
        let s = StoredSession(accessToken: a, refreshToken: r, user: u)
        store.save(s)
        return s
    }

    func clearSession() { store.clear() }
}
