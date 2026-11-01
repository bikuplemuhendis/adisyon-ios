import SwiftUI

/// Kategoriye göre ürün ekleme.
struct MenuPickerSheet: View {
    @ObservedObject var vm: OrderViewModel
    let onPick: (MenuItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    private var items: [MenuItem] {
        if search.isEmpty { return vm.visibleItems }
        return vm.menu.flatMap { $0.items ?? [] }
            .filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if search.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(vm.menu) { cat in
                                let selected = (vm.selectedCategoryId ?? vm.menu.first?.id) == cat.id
                                Button { vm.selectedCategoryId = cat.id } label: {
                                    Text(cat.name).font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(selected ? Theme.primary : Color(.secondarySystemBackground))
                                        .foregroundColor(selected ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding()
                    }
                }
                if vm.menu.isEmpty {
                    Spacer(); ProgressView("Menü yükleniyor…"); Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items) { item in
                                Button { onPick(item) } label: { MenuItemCell(item: item) }
                                    .disabled(!item.isAvailable)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 80)
                    }
                }
            }
            .searchable(text: $search, prompt: "Ürün ara")
            .navigationTitle("Ürün ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti (\(vm.drafts.reduce(0) { $0 + $1.quantity }))") { dismiss() }
                }
            }
        }
    }
}

struct MenuItemCell: View {
    let item: MenuItem
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                .lineLimit(2).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            HStack {
                Text(Money.format(item.priceMinor)).font(.callout.monospacedDigit()).foregroundColor(Theme.primary)
                Spacer()
                if !item.isAvailable { StatusBadge(text: "Tükendi", color: Theme.danger) }
                else if !(item.optionGroups ?? []).isEmpty { Image(systemName: "slider.horizontal.3").foregroundColor(.secondary) }
            }
        }
        .padding(12)
        .frame(minHeight: 84)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(item.isAvailable ? 1 : 0.5)
    }
}

/// Seçenek grupları (min/max seçim) + not.
struct OptionSheet: View {
    let item: MenuItem
    let initial: [String]
    let onAdd: ([String], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var note = ""

    private var groups: [MenuOptionGroup] { item.optionGroups ?? [] }

    private var isValid: Bool {
        groups.allSatisfy { g in
            let n = g.options.filter { selected.contains($0.id) }.count
            let minSel = max(g.minSelect ?? 0, g.required ? 1 : 0)
            return n >= minSel && n <= (g.maxSelect ?? Int.max)
        }
    }

    private var total: Int {
        item.priceMinor + groups.flatMap { $0.options }.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.priceDeltaMinor }
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(groups) { g in
                    Section {
                        ForEach(g.options.filter { $0.isAvailable != false }) { o in
                            Button { toggle(o, in: g) } label: {
                                HStack {
                                    Image(systemName: selected.contains(o.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(Theme.primary)
                                    Text(o.name).foregroundColor(.primary)
                                    Spacer()
                                    if o.priceDeltaMinor != 0 {
                                        Text("+\(Money.format(o.priceDeltaMinor))").foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(g.name + (g.required ? " (zorunlu)" : ""))
                    }
                }
                Section("Not") {
                    TextField("Ürün notu", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle · \(Money.format(total))") {
                        onAdd(Array(selected).sorted(), note.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear { selected = Set(initial) }
    }

    private func toggle(_ o: MenuOption, in g: MenuOptionGroup) {
        if selected.contains(o.id) {
            selected.remove(o.id)
            return
        }
        if (g.maxSelect ?? Int.max) == 1 {
            g.options.forEach { selected.remove($0.id) }
        } else if g.options.filter({ selected.contains($0.id) }).count >= (g.maxSelect ?? Int.max) {
            return
        }
        selected.insert(o.id)
    }
}
