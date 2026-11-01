import Foundation

/// Basit periyodik yenileyici. API'nin Socket.IO ağ geçidi (/realtime) var;
/// harici bağımlılık eklememek için canlı güncellemeler yoklama ile yapılır.
@MainActor
final class Poller {
    private var task: Task<Void, Never>?
    private let interval: TimeInterval

    init(interval: TimeInterval = AppConfig.pollInterval) { self.interval = interval }

    func start(_ action: @escaping @MainActor () async -> Void) {
        stop()
        let ns = UInt64(interval * 1_000_000_000)
        task = Task { @MainActor in
            while !Task.isCancelled {
                await action()
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
