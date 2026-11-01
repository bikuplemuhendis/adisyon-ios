import Foundation

/// Mutfağa gönderilmeyi bekleyen yerel sepet satırı.
struct DraftLine: Identifiable, Hashable {
    let id = UUID()
    let item: MenuItem
    var quantity: Int
    var note: String
    var optionIds: [String]
    var optionNames: [String]
    var unitMinor: Int

    var lineMinor: Int { unitMinor * quantity }
}

@MainActor
final class OrderViewModel: ObservableObject {
    let orderId: String

    @Published var order: Order?
    @Published var bill: Bill?
    @Published var menu: [MenuCategory] = []
    @Published var selectedCategoryId: String?
    @Published var drafts: [DraftLine] = []
    @Published var loadError: String?
    @Published var actionError: String?
    @Published var isSending = false
    @Published var closed = false

    private let poller = Poller()

    init(orderId: String) { self.orderId = orderId }

    var activeItems: [OrderItem] { (order?.items ?? []).filter { $0.status != .CANCELLED } }
    var draftTotal: Int { drafts.reduce(0) { $0 + $1.lineMinor } }

    var visibleItems: [MenuItem] {
        let cat = menu.first { $0.id == selectedCategoryId } ?? menu.first
        return (cat?.items ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }

    func start(api: APIClient) {
        poller.start { [weak self] in await self?.refresh(api: api, silent: true) }
    }
    func stop() { poller.stop() }

    func loadMenu(api: APIClient) async {
        guard menu.isEmpty else { return }
        do {
            menu = try await api.menuTree()
                .filter { $0.isActive != false }
                .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            selectedCategoryId = menu.first?.id
        } catch {
            actionError = errorText(error)
        }
    }

    func refresh(api: APIClient, silent: Bool = false) async {
        do {
            async let o = api.order(orderId)
            async let b = api.bill(orderId: orderId)
            let (order, bill) = try await (o, b)
            self.order = order
            self.bill = bill
            loadError = nil
            if order.status != "OPEN" { closed = true; stop() }
        } catch {
            if order == nil || !silent { loadError = errorText(error) }
        }
    }

    // MARK: Draft

    func add(_ item: MenuItem, optionIds: [String] = [], note: String = "") {
        let opts = (item.optionGroups ?? []).flatMap { $0.options }.filter { optionIds.contains($0.id) }
        let unit = item.priceMinor + opts.reduce(0) { $0 + $1.priceDeltaMinor }
        if let i = drafts.firstIndex(where: { $0.item.id == item.id && $0.optionIds == optionIds && $0.note == note }) {
            drafts[i].quantity += 1
        } else {
            drafts.append(DraftLine(item: item, quantity: 1, note: note, optionIds: optionIds,
                                    optionNames: opts.map { $0.name }, unitMinor: unit))
        }
    }

    func defaultOptionIds(for item: MenuItem) -> [String] {
        (item.optionGroups ?? []).flatMap { g in g.options.filter { $0.isDefault == true && $0.isAvailable != false }.map { $0.id } }
    }

    func needsOptionSheet(_ item: MenuItem) -> Bool {
        !(item.optionGroups ?? []).isEmpty
    }

    func changeQuantity(_ line: DraftLine, by delta: Int) {
        guard let i = drafts.firstIndex(where: { $0.id == line.id }) else { return }
        drafts[i].quantity += delta
        if drafts[i].quantity <= 0 { drafts.remove(at: i) }
    }

    func setNote(_ line: DraftLine, _ note: String) {
        guard let i = drafts.firstIndex(where: { $0.id == line.id }) else { return }
        drafts[i].note = note
    }

    /// Sepeti mutfağa gönder: her satır POST /orders/:id/items (KDS'e PENDING olarak düşer).
    func sendToKitchen(api: APIClient) async {
        guard !drafts.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        var remaining = drafts
        for line in drafts {
            do {
                let note = line.note.trimmingCharacters(in: .whitespacesAndNewlines)
                let updated = try await api.addItem(orderId: orderId, AddOrderItemRequest(
                    menuItemId: line.item.id, quantity: line.quantity,
                    note: note.isEmpty ? nil : note, optionIds: line.optionIds))
                order = updated
                remaining.removeAll { $0.id == line.id }
            } catch {
                actionError = "\(line.item.name): \(errorText(error))"
                break
            }
        }
        drafts = remaining
        await refresh(api: api, silent: true)
    }

    func serve(api: APIClient, item: OrderItem) async {
        do {
            order = try await api.serveItem(orderId: orderId, itemId: item.id)
        } catch { actionError = errorText(error) }
    }

    func toggleBillRequest(api: APIClient) async {
        do {
            order = try await api.requestBill(orderId: orderId, order?.billRequestedAt == nil)
        } catch { actionError = errorText(error) }
    }

    // MARK: Payment

    func pay(api: APIClient, method: PaymentMethod, amountMinor: Int, tipMinor: Int, close: Bool) async -> Bool {
        do {
            _ = try await api.pay(CreatePaymentRequest(orderId: orderId, method: method.rawValue,
                                                       amountMinor: amountMinor, tipMinor: tipMinor,
                                                       closeIfPaid: close, version: bill?.version),
                                  idempotencyKey: UUID().uuidString)
            await refresh(api: api, silent: true)
            return true
        } catch {
            actionError = errorText(error)
            await refresh(api: api, silent: true)
            return false
        }
    }

    func close(api: APIClient) async {
        do {
            _ = try await api.closeOrder(orderId: orderId, version: bill?.version)
            closed = true
            stop()
        } catch { actionError = errorText(error) }
    }
}
