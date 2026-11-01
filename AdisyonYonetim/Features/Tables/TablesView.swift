import SwiftUI

struct OrderRoute: Hashable {
    let orderId: String
    let tableName: String
}

struct TablesView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm = TablesViewModel()
    @State private var path: [OrderRoute] = []
    @State private var openingTable: DiningTable?

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) { stackContent }
    }

    private var stackContent: some View {
        content
            .navigationTitle(state.branchName.map { "Masalar · \($0)" } ?? "Masalar")
            .navigationDestination(for: OrderRoute.self) { route in
                OrderDetailView(orderId: route.orderId, tableName: route.tableName)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await vm.refresh(api: state.api) } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .refreshable { await vm.refresh(api: state.api) }
            .onAppear { vm.start(api: state.api) }
            .onDisappear { vm.stop() }
            .sheet(item: $openingTable) { table in
                OpenOrderSheet(table: table) { covers in
                    if let order = await vm.openOrder(api: state.api, table: table, covers: covers) {
                        openingTable = nil
                        navigate(OrderRoute(orderId: order.id, tableName: table.name))
                    }
                }
                .presentationDetents([.medium])
            }
            .errorAlert($vm.actionError)
    }

    @ViewBuilder private var content: some View {
        if let err = vm.loadError, vm.tables.isEmpty {
            ErrorRetryView(message: err) { Task { await vm.refresh(api: state.api) } }
        } else if vm.tables.isEmpty && vm.isLoading {
            ProgressView("Masalar yükleniyor…")
        } else {
            ScrollView {
                if vm.zones.count > 1 { zonePicker }
                legend
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.filtered) { table in
                        TableCell(table: table, order: vm.ordersByTable[table.id])
                            .onTapGesture { tap(table) }
                            .contextMenu {
                                if table.status == .DIRTY {
                                    Button("Temizlendi olarak işaretle") {
                                        Task { await vm.markClean(api: state.api, table: table) }
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
        }
    }

    private var zonePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip("Tümü", selected: vm.zone == nil) { vm.zone = nil }
                ForEach(vm.zones, id: \.self) { z in chip(z, selected: vm.zone == z) { vm.zone = z } }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([TableStatus.EMPTY, .OCCUPIED, .RESERVED, .DIRTY], id: \.self) { s in
                HStack(spacing: 4) {
                    Circle().fill(Theme.color(for: s)).frame(width: 8, height: 8)
                    Text(s.title).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Theme.primary : Color(.secondarySystemBackground))
                .foregroundColor(selected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private func tap(_ table: DiningTable) {
        if let order = vm.ordersByTable[table.id] {
            navigate(OrderRoute(orderId: order.id, tableName: table.name))
        } else {
            openingTable = table
        }
    }

    private func navigate(_ route: OrderRoute) {
        path.append(route)
    }
}

/// Masa kutusu
struct TableCell: View {
    let table: DiningTable
    let order: Order?

    var body: some View {
        let color = Theme.color(for: order != nil ? .OCCUPIED : table.status)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(table.name).font(.title3.bold())
                Spacer()
                if order?.billRequestedAt != nil {
                    Image(systemName: "doc.text.fill").foregroundColor(Theme.accent)
                        .accessibilityLabel("Hesap istendi")
                }
            }
            Text(order != nil ? TableStatus.OCCUPIED.title : table.status.title)
                .font(.caption.bold()).foregroundColor(color)
            Spacer(minLength: 0)
            if let order {
                Text(Money.format(order.totalMinor)).font(.headline.monospacedDigit())
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill").font(.caption2)
                    Text("\(order.covers ?? 0)").font(.caption)
                    Spacer()
                    Text(DateFmt.timeString(order.createdAt)).font(.caption).foregroundColor(.secondary)
                }
            } else if let cap = table.capacity {
                Text("\(cap) kişilik").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(minHeight: 110)
        .background(color.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct OpenOrderSheet: View {
    let table: DiningTable
    let onOpen: (Int) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var covers = 2
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Masa \(table.name)") {
                    Stepper("Kişi sayısı: \(covers)", value: $covers, in: 1...99)
                }
                Section {
                    Button {
                        busy = true
                        Task { await onOpen(covers); busy = false }
                    } label: {
                        HStack { Spacer(); if busy { ProgressView() } else { Text("Adisyon aç").bold() }; Spacer() }
                    }
                    .disabled(busy)
                }
            }
            .navigationTitle("Yeni adisyon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } } }
        }
        .onAppear { covers = min(max(table.capacity ?? 2, 1), 4) }
    }
}
