import SwiftUI

enum Theme {
    /// Teal #0F766E
    static let primary = Color(hex: 0x0F766E)
    /// Amber #F59E0B
    static let accent = Color(hex: 0xF59E0B)
    static let danger = Color(hex: 0xDC2626)
    static let success = Color(hex: 0x16A34A)
    static let info = Color(hex: 0x2563EB)

    static func color(for status: TableStatus) -> Color {
        switch status {
        case .EMPTY: return success
        case .OCCUPIED: return primary
        case .RESERVED: return info
        case .DIRTY: return accent
        case .unknown: return .gray
        }
    }

    static func color(for status: OrderItemStatus) -> Color {
        switch status {
        case .PENDING: return accent
        case .PREPARING: return info
        case .READY: return success
        case .SERVED: return .gray
        case .CANCELLED: return danger
        case .unknown: return .gray
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundColor(.white)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
