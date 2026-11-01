import Foundation
#if canImport(Network)
import Network
import Combine

/// NWPathMonitor ile çevrimdışı tespiti.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var isExpensive: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.adisyonyonetim.netmon")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor in
                self?.isOnline = online
                self?.isExpensive = expensive
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
#endif
