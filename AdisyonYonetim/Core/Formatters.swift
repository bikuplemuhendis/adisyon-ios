import Foundation

enum Money {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "TRY"
        f.locale = Locale(identifier: "tr_TR")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    /// Kuruş → "₺1.234,50"
    static func format(_ minor: Int) -> String {
        formatter.string(from: NSNumber(value: Double(minor) / 100.0)) ?? "\(minor / 100) ₺"
    }

    /// "12,50" / "12.50" → 1250
    static func parse(_ text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v >= 0 else { return nil }
        return Int((v * 100).rounded())
    }
}

enum DateFmt {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoNoFrac = ISO8601DateFormatter()
    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "tr_TR")
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s) ?? isoNoFrac.date(from: s)
    }
    static func dayString(_ d: Date = Date()) -> String { day.string(from: d) }
    static func timeString(_ s: String?) -> String { parse(s).map { time.string(from: $0) } ?? "" }
    static func elapsed(_ sec: Int?) -> String {
        guard let sec else { return "" }
        let m = sec / 60
        return m < 60 ? "\(m) dk" : "\(m / 60) sa \(m % 60) dk"
    }
}
