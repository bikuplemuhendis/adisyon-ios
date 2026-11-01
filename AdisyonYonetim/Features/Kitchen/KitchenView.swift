import SwiftUI

struct KitchenView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm = KitchenViewModel()

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            Picker("İstasyon", selection: $vm.station) {
                ForEach(KitchenViewModel.stations, id: \.key) { Text($0.title).tag($0.key) }
            }
            .pickerStyle(.segmented)
            .padding()

            if let err = vm.loadError, vm.tickets.isEmpty {
                ErrorRetryView(message: err) { Task { await vm.refresh(api: state.api) } }
            } else if vm.tickets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    if vm.isLoading { ProgressView() } else {
                        Image(systemName: "checkmark.circle").font(.system(size: 48)).foregroundColor(Theme.success)
                        Text("Bekleyen sipariş yok").foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.tickets) { t in TicketCard(ticket: t, vm: vm) }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .refreshable { await vm.refresh(api: state.api) }
            }
        }
        .navigationTitle("Mutfak")
        .onChange(of: vm.station) { _ in Task { await vm.refresh(api: state.api) } }
        .onAppear { vm.start(api: state.api) }
        .onDisappear { vm.stop() }
        .errorAlert($vm.actionError)
    }
}

struct TicketCard: View {
    @EnvironmentObject private var state: AppState
    let ticket: KdsTicket
    @ObservedObject var vm: KitchenViewModel

    private var title: String {
        if let t = ticket.tableName { return "Masa \(t)" }
        if let q = ticket.queueNumber { return "Paket #\(q)" }
        return ticket.guestName ?? "Sipariş"
    }

    private var urgent: Bool { (ticket.elapsedSec ?? 0) > 15 * 60 || ticket.hasRush == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                if ticket.hasRush == true { StatusBadge(text: "ACİL", color: Theme.danger) }
                Spacer()
                Label(DateFmt.elapsed(ticket.elapsedSec), systemImage: "clock")
                    .font(.caption.bold())
                    .foregroundColor(urgent ? Theme.danger : .secondary)
            }
            Divider()
            ForEach(ticket.items) { item in
                HStack(alignment: .top) {
                    Text("\(item.quantity)×").font(.headline.monospacedDigit()).frame(width: 34, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.body.weight(.semibold))
                            .strikethrough(item.status == .READY)
                        if let o = item.optionsJson, !o.isEmpty {
                            Text(o.map { $0.name }.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                        }
                        if let n = item.note, !n.isEmpty {
                            Text("Not: \(n)").font(.caption.bold()).foregroundColor(Theme.accent)
                        }
                        if let a = item.allergens, !a.isEmpty {
                            Text("Alerjen: \(a.joined(separator: ", "))").font(.caption2).foregroundColor(Theme.danger)
                        }
                    }
                    Spacer()
                    itemButton(item)
                }
            }
            if ticket.items.contains(where: { $0.status != .READY }) {
                Button {
                    Task { await vm.bumpAll(api: state.api, ticket: ticket) }
                } label: {
                    if vm.busyIds.contains(ticket.orderId) { ProgressView().tint(.white) }
                    else { Label("Hepsi hazır", systemImage: "checkmark.circle.fill") }
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.success))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(urgent ? Theme.danger : Color.clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private func itemButton(_ item: KdsItem) -> some View {
        if vm.busyIds.contains(item.id) {
            ProgressView()
        } else {
            switch item.status {
            case .PENDING:
                Button("Başla") { Task { await vm.bump(api: state.api, item: item) } }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
            case .PREPARING:
                Button("Hazır") { Task { await vm.bump(api: state.api, item: item, toReady: true) } }
                    .buttonStyle(.borderedProminent).tint(Theme.success)
            default:
                StatusBadge(text: item.status.title, color: Theme.color(for: item.status))
            }
        }
    }
}
