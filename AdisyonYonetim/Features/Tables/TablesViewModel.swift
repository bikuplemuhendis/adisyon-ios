import Foundation

@MainActor
final class TablesViewModel: ObservableObject {
    @Published var tables: [DiningTable] = []
    @Published var ordersByTable: [String: Order] = [:]
    @Published var zone: String? = nil
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var actionError: String?

    private let poller = Poller()

    var zones: [String] {
        Array(Set(tables.compactMap { $0.zone })).sorted()
    }

    var filtered: [DiningTable] {
        tables.filter { zone == nil || $0.zone == zone }
            .sorted { ($0.sortOrder ?? 0, $0.name) < ($1.sortOrder ?? 0, $1.name) }
    }

    func start(api: APIClient) {
        poller.start { [weak self] in await self?.refresh(api: api, silent: true) }
    }
    func stop() { poller.stop() }

    func refresh(api: APIClient, silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { isLoading = false }
        do {
            async let t = api.tables()
            async let o = api.openOrders()
            let (tables, orders) = try await (t, o)
            self.tables = tables
            var map: [String: Order] = [:]
            for order in orders { if let tid = order.tableId { map[tid] = order } }
            ordersByTable = map
            loadError = nil
        } catch {
            if !silent || tables.isEmpty { loadError = errorText(error) }
        }
    }

    func openOrder(api: APIClient, table: DiningTable, covers: Int) async -> Order? {
        do {
            let order = try await api.openOrder(tableId: table.id, covers: covers, note: nil)
            await refresh(api: api, silent: true)
            return order
        } catch {
            actionError = errorText(error)
            return nil
        }
    }

    func markClean(api: APIClient, table: DiningTable) async {
        do {
            _ = try await api.setTableStatus(table.id, .EMPTY)
            await refresh(api: api, silent: true)
        } catch { actionError = errorText(error) }
    }
}
