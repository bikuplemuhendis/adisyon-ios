import SwiftUI

struct OrderDetailView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: OrderViewModel
    let tableName: String

    @State private var showMenu = false
    @State private var showPayment = false
    @State private var optionItem: MenuItem?
    @State private var editingNote: DraftLine?
    @State private var confirmClose = false

    init(orderId: String, tableName: String) {
        _vm = StateObject(wrappedValue: OrderViewModel(orderId: orderId))
        self.tableName = tableName
    }

    private var role: UserRole { state.user?.role ?? .unknown }

    var body: some View {
        Group {
            if let err = vm.loadError, vm.order == nil {
                ErrorRetryView(message: err) { Task { await vm.refresh(api: state.api) } }
            } else if vm.order == nil {
                ProgressView("Adisyon yükleniyor…")
            } else {
                list
            }
        }
        .navigationTitle("Masa \(tableName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await vm.toggleBillRequest(api: state.api) }
                    } label: {
                        Label(vm.order?.billRequestedAt == nil ? "Hesap istendi" : "Hesap isteğini kaldır",
                              systemImage: "doc.text")
                    }
                    if role.canTakePayment {
                        Button { showPayment = true } label: { Label("Ödeme al", systemImage: "creditcard") }
                        Button(role: .destructive) { confirmClose = true } label: {
                            Label("Adisyonu kapat", systemImage: "checkmark.seal")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task {
            await vm.refresh(api: state.api)
            await vm.loadMenu(api: state.api)
        }
        .onAppear { vm.start(api: state.api) }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showMenu) {
            MenuPickerSheet(vm: vm) { item in
                if vm.needsOptionSheet(item) { optionItem = item } else { vm.add(item) }
            }
        }
        .sheet(item: $optionItem) { item in
            OptionSheet(item: item, initial: vm.defaultOptionIds(for: item)) { ids, note in
                vm.add(item, optionIds: ids, note: note)
            }
        }
        .sheet(item: $editingNote) { line in
            NoteSheet(initial: line.note) { vm.setNote(line, $0) }
                .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showPayment) {
            if let bill = vm.bill {
                PaymentSheet(bill: bill) { method, amount, tip, close in
                    await vm.pay(api: state.api, method: method, amountMinor: amount, tipMinor: tip, close: close)
                }
            }
        }
        .confirmationDialog("Adisyon kapatılsın mı?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Kapat", role: .destructive) { Task { await vm.close(api: state.api) } }
        } message: {
            Text((vm.bill?.balanceMinor ?? 0) > 0 ? "Kalan bakiye: \(Money.format(vm.bill?.balanceMinor ?? 0))" : "Tüm ödeme alındı.")
        }
        .onChange(of: vm.closed) { closed in if closed { dismiss() } }
        .errorAlert($vm.actionError)
    }

    private var list: some View {
        List {
            if !vm.drafts.isEmpty {
                Section {
                    ForEach(vm.drafts) { line in
                        DraftRow(line: line,
                                 onMinus: { vm.changeQuantity(line, by: -1) },
                                 onPlus: { vm.changeQuantity(line, by: 1) },
                                 onNote: { editingNote = line })
                    }
                } header: {
                    HStack {
                        Text("Gönderilecek")
                        Spacer()
                        Text(Money.format(vm.draftTotal))
                    }
                }
            }

            Section("Adisyon") {
                if vm.activeItems.isEmpty {
                    Text("Henüz ürün yok. Ürün eklemek için + Ürün’e dokunun.").foregroundColor(.secondary)
                }
                ForEach(vm.activeItems) { item in
                    OrderItemRow(item: item)
                        .swipeActions {
                            if item.status == .READY {
                                Button("Servis") { Task { await vm.serve(api: state.api, item: item) } }
                                    .tint(Theme.primary)
                            }
                        }
                }
            }

            if let bill = vm.bill { BillSection(bill: bill) }
        }
        .listStyle(.insetGrouped)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { showMenu = true } label: {
                Label("Ürün", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.accent))

            if !vm.drafts.isEmpty {
                Button {
                    Task { await vm.sendToKitchen(api: state.api) }
                } label: {
                    if vm.isSending { ProgressView().tint(.white) }
                    else { Label("Mutfağa gönder (\(vm.drafts.reduce(0) { $0 + $1.quantity }))", systemImage: "paperplane.fill") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(vm.isSending)
            } else if role.canTakePayment {
                Button { showPayment = true } label: {
                    Label("Öde · \(Money.format(vm.bill?.balanceMinor ?? 0))", systemImage: "creditcard.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(vm.bill == nil)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct OrderItemRow: View {
    let item: OrderItem
    var body: some View {
        HStack(alignment: .top) {
            Text("\(item.quantity)×").font(.headline.monospacedDigit()).frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.body.weight(.medium))
                    if item.isRush == true { Image(systemName: "bolt.fill").foregroundColor(Theme.danger).font(.caption) }
                    if item.isComp == true { StatusBadge(text: "İkram", color: Theme.info) }
                }
                if let opts = item.optionsJson, !opts.isEmpty {
                    Text(opts.map { $0.name }.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                }
                if let note = item.note, !note.isEmpty {
                    Text("Not: \(note)").font(.caption).foregroundColor(Theme.accent)
                }
                StatusBadge(text: item.status.title, color: Theme.color(for: item.status))
            }
            Spacer()
            Text(Money.format(item.lineTotalMinor ?? 0)).font(.callout.monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}

struct DraftRow: View {
    let line: DraftLine
    let onMinus: () -> Void
    let onPlus: () -> Void
    let onNote: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.item.name).font(.body.weight(.medium))
                if !line.optionNames.isEmpty {
                    Text(line.optionNames.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                }
                Button(action: onNote) {
                    Label(line.note.isEmpty ? "Not ekle" : line.note, systemImage: "square.and.pencil").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: onMinus) { Image(systemName: "minus.circle.fill") }.buttonStyle(.borderless)
                Text("\(line.quantity)").font(.headline.monospacedDigit()).frame(minWidth: 22)
                Button(action: onPlus) { Image(systemName: "plus.circle.fill") }.buttonStyle(.borderless)
            }
            .font(.title2)
            .foregroundColor(Theme.primary)
        }
    }
}

struct BillSection: View {
    let bill: Bill
    var body: some View {
        Section("Hesap") {
            row("Ara toplam", bill.subtotalMinor)
            if let d = bill.discountMinor, d > 0 { row("İndirim", -d) }
            if let k = bill.kuverMinor, k > 0 { row("Kuver", k) }
            if let s = bill.serviceChargeMinor, s > 0 { row("Servis", s) }
            if let p = bill.packagingFeeMinor, p > 0 { row("Paket", p) }
            ForEach(bill.taxBreakdown ?? [], id: \.label) { t in
                row("\(t.label) (dahil)", t.taxMinor, secondary: true)
            }
            row("Toplam", bill.dueMinor, bold: true)
            if bill.paidMinor > 0 { row("Ödenen", bill.paidMinor) }
            if let tip = bill.tipMinor, tip > 0 { row("Bahşiş", tip, secondary: true) }
            row("Kalan", bill.balanceMinor, bold: true, color: bill.balanceMinor > 0 ? Theme.accent : Theme.success)
        }
    }

    private func row(_ title: String, _ minor: Int, bold: Bool = false, secondary: Bool = false, color: Color? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Money.format(minor)).monospacedDigit()
        }
        .font(bold ? .headline : .body)
        .foregroundColor(color ?? (secondary ? .secondary : .primary))
    }
}

struct NoteSheet: View {
    let initial: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Örn. az şekerli, soğansız", text: $text, axis: .vertical).lineLimit(3...5)
            }
            .navigationTitle("Not")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { onSave(String(text.prefix(500))); dismiss() } }
            }
        }
        .onAppear { text = initial }
    }
}
