import Foundation

/// Uygulamanın kullandığı API uç noktaları (prefix: /api).
extension APIClient {
    // Auth
    func bootstrap(slug: String) async throws -> BootstrapResponse {
        try await get("auth/bootstrap", query: ["slug": slug], auth: false)
    }
    func login(email: String, password: String) async throws -> AuthResponse {
        try await post("auth/login", body: LoginRequest(email: email, password: password), auth: false)
    }
    func pinLogin(businessId: String, pin: String) async throws -> AuthResponse {
        try await post("auth/pin-login", body: PinLoginRequest(businessId: businessId, pin: pin), auth: false)
    }
    func verify2fa(pendingToken: String, code: String) async throws -> AuthResponse {
        try await post("auth/2fa/verify", body: TotpVerifyRequest(pendingToken: pendingToken, code: code), auth: false)
    }
    func logout(refreshToken: String) async {
        let _: EmptyResponse? = try? await post("auth/logout", body: RefreshRequest(refreshToken: refreshToken), auth: false)
    }
    func me() async throws -> AuthUser { try await get("auth/me") }
    func branches() async throws -> [Branch] { try await get("auth/branches") }
    func selectBranch(_ id: String) async throws -> AuthResponse {
        try await patch("auth/session/branch", body: SelectBranchRequest(branchId: id))
    }

    // Tables
    func tables() async throws -> [DiningTable] { try await get("tables") }
    func setTableStatus(_ id: String, _ status: TableStatus) async throws -> DiningTable {
        try await patch("tables/\(id)/status", body: TableStatusRequest(status: status.rawValue))
    }

    // Menu
    func menuTree() async throws -> [MenuCategory] { try await get("menu/tree") }

    // Orders
    func openOrders() async throws -> [Order] { try await get("orders", query: ["status": "OPEN"]) }
    func order(_ id: String) async throws -> Order { try await get("orders/\(id)") }
    func openOrder(tableId: String, covers: Int?, note: String?) async throws -> Order {
        try await post("orders", body: OpenOrderRequest(tableId: tableId, covers: covers, note: note))
    }
    func addItem(orderId: String, _ req: AddOrderItemRequest) async throws -> Order {
        try await post("orders/\(orderId)/items", body: req)
    }
    func serveItem(orderId: String, itemId: String) async throws -> Order {
        try await post("orders/\(orderId)/items/\(itemId)/serve", body: EmptyBody())
    }
    func requestBill(orderId: String, _ requested: Bool) async throws -> Order {
        try await post("orders/\(orderId)/bill-request", body: BillRequestBody(requested: requested))
    }

    // Payments
    func bill(orderId: String) async throws -> Bill { try await get("orders/\(orderId)/bill") }
    func pay(_ req: CreatePaymentRequest, idempotencyKey: String) async throws -> EmptyResponse {
        try await post("payments", body: req, headers: ["Idempotency-Key": idempotencyKey])
    }
    func closeOrder(orderId: String, version: Int?) async throws -> EmptyResponse {
        try await post("orders/\(orderId)/close", body: CloseOrderRequest(version: version, tableStatus: nil))
    }

    // KDS
    func kdsQueue(station: String) async throws -> KdsQueue { try await get("kds/queue", query: ["station": station]) }
    func bump(itemId: String, target: OrderItemStatus?) async throws -> EmptyResponse {
        try await post("kds/items/\(itemId)/bump", body: KdsBumpRequest(targetStatus: target?.rawValue))
    }
    func bumpAll(orderId: String, station: String?) async throws -> EmptyResponse {
        try await post("kds/orders/\(orderId)/bump-all", body: KdsBumpAllRequest(station: station))
    }

    // Kasa
    func currentShift() async throws -> Shift? { try await get("shifts/current") }
    func summary(from: String, to: String) async throws -> ReportSummary {
        try await get("reports/summary", query: ["from": from, "to": to])
    }

    // Devices
    func registerDevice(token: String, branchId: String?) async throws -> EmptyResponse {
        try await post("devices", body: RegisterDeviceRequest(token: token, platform: "ios", branchId: branchId))
    }
    func unregisterDevice(token: String) async throws -> EmptyResponse {
        try await delete("devices", body: RemoveDeviceRequest(token: token))
    }
}
