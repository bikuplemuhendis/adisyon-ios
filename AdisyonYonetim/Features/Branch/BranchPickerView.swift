import SwiftUI

struct BranchPickerView: View {
    @EnvironmentObject private var state: AppState
    @State private var load: LoadState<[Branch]> = .idle
    @State private var selecting: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                switch load {
                case .idle, .loading:
                    ProgressView("Şubeler yükleniyor…")
                case .failed(let m):
                    ErrorRetryView(message: m) { Task { await fetch() } }
                case .loaded(let branches):
                    if branches.isEmpty {
                        ErrorRetryView(message: "Erişebileceğiniz şube yok.") { Task { await fetch() } }
                    } else {
                        List(branches) { b in
                            Button {
                                Task { await choose(b) }
                            } label: {
                                HStack {
                                    Image(systemName: "building.2").foregroundColor(Theme.primary)
                                    VStack(alignment: .leading) {
                                        Text(b.name).font(.headline).foregroundColor(.primary)
                                        if b.isDefault == true { Text("Varsayılan şube").font(.caption).foregroundColor(.secondary) }
                                    }
                                    Spacer()
                                    if selecting == b.id { ProgressView() }
                                    else if b.id == state.user?.selectedBranchId {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.primary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .disabled(selecting != nil)
                        }
                    }
                }
            }
            .navigationTitle("Şube seçin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Çıkış") { Task { await state.logout() } }
                }
            }
            .errorAlert($error)
        }
        .task { await fetch() }
    }

    private func fetch() async {
        load = .loading
        do {
            var list = try await state.api.branches()
            // Şu anki şube listede yoksa (yanıt yalnızca diğerlerini dönerse) yine de göster.
            if let current = state.user?.selectedBranchId, !list.contains(where: { $0.id == current }) {
                list.insert(Branch(id: current, name: state.branchName ?? "Mevcut şube", businessId: state.user?.businessId, isDefault: nil), at: 0)
            }
            load = .loaded(list)
        } catch {
            load = .failed(errorText(error))
        }
    }

    private func choose(_ b: Branch) async {
        selecting = b.id
        defer { selecting = nil }
        do { try await state.selectBranch(b) } catch { self.error = errorText(error) }
    }
}
