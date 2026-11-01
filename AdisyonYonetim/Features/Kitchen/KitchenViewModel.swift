import Foundation

@MainActor
final class KitchenViewModel: ObservableObject {
    static let stations: [(key: String, title: String)] = [
        ("ALL", "Tümü"), ("KITCHEN", "Mutfak"), ("BAR", "Bar"), ("DESSERT", "Tatlı"), ("EXPO", "Hazır"),
    ]

    @Published var station: String = UserDefaults.standard.string(forKey: "kdsStation") ?? "ALL" {
        didSet { UserDefaults.standard.set(station, forKey: "kdsStation") }
    }
    @Published var tickets: [KdsTicket] = []
    @Published var loadError: String?
    @Published var actionError: String?
    @Published var isLoading = false
    @Published var busyIds: Set<String> = []

    private let poller = Poller()

    func start(api: APIClient) {
        poller.start { [weak self] in await self?.refresh(api: api, silent: true) }
    }
    func stop() { poller.stop() }

    func refresh(api: APIClient, silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { isLoading = false }
        do {
            let q = try await api.kdsQueue(station: station)
            tickets = q.tickets
            loadError = nil
        } catch {
            if !silent || tickets.isEmpty { loadError = errorText(error) }
        }
    }

    /// PENDING→PREPARING→READY (boş hedefle API bir adım ilerletir).
    func bump(api: APIClient, item: KdsItem, toReady: Bool = false) async {
        busyIds.insert(item.id)
        defer { busyIds.remove(item.id) }
        do {
            _ = try await api.bump(itemId: item.id, target: toReady ? .READY : nil)
            await refresh(api: api, silent: true)
        } catch { actionError = errorText(error) }
    }

    func bumpAll(api: APIClient, ticket: KdsTicket) async {
        busyIds.insert(ticket.orderId)
        defer { busyIds.remove(ticket.orderId) }
        let st = ["KITCHEN", "BAR", "DESSERT"].contains(station) ? station : nil
        do {
            _ = try await api.bumpAll(orderId: ticket.orderId, station: st)
            await refresh(api: api, silent: true)
        } catch { actionError = errorText(error) }
    }
}
