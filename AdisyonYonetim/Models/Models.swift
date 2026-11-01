import Foundation

// MARK: - Auth

enum UserRole: String, Codable {
    case SUPER_ADMIN, OWNER, MANAGER, CASHIER, WAITER, KITCHEN
    case unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UserRole(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
        case .SUPER_ADMIN: return "Süper Yönetici"
        case .OWNER: return "İşletme Sahibi"
        case .MANAGER: return "Müdür"
        case .CASHIER: return "Kasiyer"
        case .WAITER: return "Garson"
        case .KITCHEN: return "Mutfak"
        case .unknown: return "Personel"
        }
    }
    var canTakePayment: Bool { [.SUPER_ADMIN, .OWNER, .MANAGER, .CASHIER].contains(self) }
    var canSeeReports: Bool { [.SUPER_ADMIN, .OWNER, .MANAGER, .CASHIER].contains(self) }
    var isKitchen: Bool { self == .KITCHEN }
}

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String?
    let name: String
    let role: UserRole
    let businessId: String?
    let sessionId: String?
    let selectedBranchId: String?
    let branchIds: [String]
    let impersonatorId: String?
}

/// POST /auth/login | /auth/pin-login | /auth/2fa/verify | /auth/refresh | PATCH /auth/session/branch
/// Login 2FA açık kullanıcıda `{ requires2fa: true, pendingToken }` döner.
struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: AuthUser?
    let requires2fa: Bool?
    let pendingToken: String?
}

struct LoginRequest: Encodable { let email: String; let password: String }
struct PinLoginRequest: Encodable { let businessId: String; let pin: String }
struct TotpVerifyRequest: Encodable { let pendingToken: String; let code: String }
struct RefreshRequest: Encodable { let refreshToken: String }
struct SelectBranchRequest: Encodable { let branchId: String }

/// GET /auth/bootstrap?slug=
struct BootstrapResponse: Decodable {
    let businessId: String?
    let slug: String?
    let name: String?
}

/// GET /auth/branches
struct Branch: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let businessId: String?
    let isDefault: Bool?
}

// MARK: - Tables

enum TableStatus: String, Codable {
    case EMPTY, OCCUPIED, RESERVED, DIRTY
    case unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TableStatus(rawValue: raw) ?? .unknown
    }
    var title: String {
        switch self {
        case .EMPTY: return "Boş"
        case .OCCUPIED: return "Dolu"
        case .RESERVED: return "Rezerve"
        case .DIRTY: return "Temizlenecek"
        case .unknown: return "-"
        }
    }
}

/// GET /tables
struct DiningTable: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let zone: String?
    let capacity: Int?
    let status: TableStatus
    let sortOrder: Int?
}

struct TableStatusRequest: Encodable { let status: String }

// MARK: - Menu

/// GET /menu/tree
struct MenuCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let sortOrder: Int?
    let isActive: Bool?
    let items: [MenuItem]?
}

struct MenuItem: Codable, Identifiable, Hashable {
    let id: String
    let categoryId: String?
    let name: String
    let description: String?
    let priceMinor: Int
    let imageUrl: String?
    let station: String?
    let allergens: [String]?
    let isAvailable: Bool
    let sortOrder: Int?
    let optionGroups: [MenuOptionGroup]?
}

struct MenuOptionGroup: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let required: Bool
    let minSelect: Int?
    let maxSelect: Int?
    let options: [MenuOption]
}

struct MenuOption: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let priceDeltaMinor: Int
    let isDefault: Bool?
    let isAvailable: Bool?
}

// MARK: - Orders

enum OrderItemStatus: String, Codable {
    case PENDING, PREPARING, READY, SERVED, CANCELLED
    case unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = OrderItemStatus(rawValue: raw) ?? .unknown
    }
    var title: String {
        switch self {
        case .PENDING: return "Bekliyor"
        case .PREPARING: return "Hazırlanıyor"
        case .READY: return "Hazır"
        case .SERVED: return "Servis edildi"
        case .CANCELLED: return "İptal"
        case .unknown: return "-"
        }
    }
}

struct OrderTableRef: Codable, Hashable {
    let id: String
    let name: String
    let zone: String?
    let status: TableStatus?
}

struct SelectedOption: Codable, Hashable {
    let name: String
    let priceDeltaMinor: Int?
}

struct OrderItem: Codable, Identifiable, Hashable {
    let id: String
    let orderId: String?
    let menuItemId: String?
    let name: String
    let station: String?
    let quantity: Int
    let unitPriceMinor: Int?
    let lineTotalMinor: Int?
    let optionsJson: [SelectedOption]?
    let note: String?
    let status: OrderItemStatus
    let isRush: Bool?
    let isHeld: Bool?
    let isComp: Bool?
    let createdAt: String?
}

/// GET /orders, GET /orders/:id, POST /orders
struct Order: Codable, Identifiable, Hashable {
    let id: String
    let tableId: String?
    let status: String
    let orderType: String?
    let queueNumber: Int?
    let version: Int?
    let guestName: String?
    let covers: Int?
    let discountMinor: Int?
    let note: String?
    let subtotalMinor: Int
    let totalMinor: Int
    let billRequestedAt: String?
    let createdAt: String?
    let table: OrderTableRef?
    let items: [OrderItem]?
}

struct OpenOrderRequest: Encodable {
    let tableId: String
    let covers: Int?
    let note: String?
}

struct AddOrderItemRequest: Encodable {
    let menuItemId: String
    let quantity: Int
    let note: String?
    let optionIds: [String]
}

struct BillRequestBody: Encodable { let requested: Bool }

// MARK: - Bill & payments

struct TaxLine: Codable, Hashable {
    let key: String?
    let label: String
    let ratePercent: Double?
    let taxableMinor: Int?
    let taxMinor: Int
}

struct Payment: Codable, Identifiable, Hashable {
    let id: String
    let method: String
    let amountMinor: Int
    let tipMinor: Int?
    let status: String?
    let createdAt: String?
}

/// GET /orders/:orderId/bill
struct Bill: Codable, Hashable {
    let orderId: String
    let status: String
    let version: Int?
    let tableName: String?
    let covers: Int?
    let subtotalMinor: Int
    let discountMinor: Int?
    let kuverMinor: Int?
    let serviceChargeMinor: Int?
    let packagingFeeMinor: Int?
    let taxBreakdown: [TaxLine]?
    let taxMinor: Int?
    let dueMinor: Int
    let paidMinor: Int
    let tipMinor: Int?
    let balanceMinor: Int
    let payments: [Payment]?
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case CASH, CARD, OTHER
    var id: String { rawValue }
    var title: String {
        switch self {
        case .CASH: return "Nakit"
        case .CARD: return "Kart"
        case .OTHER: return "Diğer"
        }
    }
}

/// POST /payments
struct CreatePaymentRequest: Encodable {
    let orderId: String
    let method: String
    let amountMinor: Int
    let tipMinor: Int
    let closeIfPaid: Bool
    let version: Int?
}

/// POST /orders/:id/close
struct CloseOrderRequest: Encodable {
    let version: Int?
    let tableStatus: String?
}

// MARK: - KDS

/// GET /kds/queue?station=
struct KdsQueue: Codable {
    let station: String
    let tickets: [KdsTicket]
    let generatedAt: String?
}

struct KdsTicket: Codable, Identifiable, Hashable {
    var id: String { orderId }
    let orderId: String
    let tableName: String?
    let tableZone: String?
    let guestName: String?
    let orderType: String?
    let queueNumber: Int?
    let elapsedSec: Int?
    let hasRush: Bool?
    let items: [KdsItem]
}

struct KdsItem: Codable, Identifiable, Hashable {
    let id: String
    let orderId: String
    let name: String
    let station: String?
    let quantity: Int
    let status: OrderItemStatus
    let optionsJson: [SelectedOption]?
    let note: String?
    let isRush: Bool?
    let isHeld: Bool?
    let allergens: [String]?
    let elapsedSec: Int?
}

/// POST /kds/items/:itemId/bump — targetStatus boş ise bir adım ilerler.
struct KdsBumpRequest: Encodable { let targetStatus: String? }
/// POST /kds/orders/:orderId/bump-all
struct KdsBumpAllRequest: Encodable { let station: String? }

// MARK: - Kasa

/// GET /shifts/current (açık vardiya yoksa null)
struct Shift: Codable, Identifiable, Hashable {
    let id: String
    let status: String
    let openingFloatMinor: Int
    let closingCountMinor: Int?
    let expectedCashMinor: Int?
    let varianceMinor: Int?
    let openedAt: String?
    let closedAt: String?
    let note: String?
}

/// GET /reports/summary?from=&to=
struct ReportSummary: Codable, Hashable {
    let from: String?
    let to: String?
    let closedChecks: Int
    let grossSalesMinor: Int
    let tipsMinor: Int
    let discountsMinor: Int
    let voidLines: Int?
    let voidMinor: Int?
    let compLines: Int?
    let compMinor: Int?
    let covers: Int?
    let avgCheckMinor: Int?
    let pendingApprovals: Int?
}

// MARK: - Devices

/// POST /devices
struct RegisterDeviceRequest: Encodable {
    let token: String
    let platform: String
    let branchId: String?
}
struct RemoveDeviceRequest: Encodable { let token: String }

struct EmptyResponse: Decodable {}
struct EmptyBody: Encodable {}
