import SwiftUI

@MainActor
final class CashSummaryViewModel: ObservableObject {
    @Published var shift: Shift?
    @Published var summary: ReportSummary?
    @Published var date = Date()
    @Published var loadError: String?
    @Published var isLoading = false

    func refresh(api: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        let day = DateFmt.dayString(date)
        do {
            async let s = api.summary(from: day, to: day)
            async let sh = api.currentShift()
            summary = try await s
            shift = (try? await sh) ?? nil
            loadError = nil
        } catch {
            loadError = errorText(error)
        }
    }
}

/// Kasa / gün özeti: GET /reports/summary + GET /shifts/current
struct CashSummaryView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm = CashSummaryViewModel()

    var body: some View {
        Group {
            if let err = vm.loadError, vm.summary == nil {
                ErrorRetryView(message: err) { Task { await vm.refresh(api: state.api) } }
            } else {
                List {
                    Section {
                        DatePicker("Gün", selection: $vm.date, in: ...Date(), displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "tr_TR"))
                    }
                    if let s = vm.summary {
                        Section("Gün özeti") {
                            metric("Brüt satış", Money.format(s.grossSalesMinor), big: true)
                            metric("Kapanan adisyon", "\(s.closedChecks)")
                            metric("Ortalama adisyon", Money.format(s.avgCheckMinor ?? 0))
                            metric("Kişi (kuver)", "\(s.covers ?? 0)")
                            metric("Bahşiş", Money.format(s.tipsMinor))
                            metric("İndirim", Money.format(s.discountsMinor))
                            metric("İptal", "\(s.voidLines ?? 0) satır · \(Money.format(s.voidMinor ?? 0))")
                            metric("İkram", "\(s.compLines ?? 0) satır · \(Money.format(s.compMinor ?? 0))")
                            if let p = s.pendingApprovals, p > 0 { metric("Bekleyen onay", "\(p)") }
                        }
                    } else if vm.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                    Section("Kasa vardiyası") {
                        if let sh = vm.shift {
                            metric("Durum", sh.status == "OPEN" ? "Açık" : "Kapalı")
                            metric("Açılış", DateFmt.timeString(sh.openedAt))
                            metric("Açılış kasası", Money.format(sh.openingFloatMinor))
                            if let e = sh.expectedCashMinor { metric("Beklenen nakit", Money.format(e)) }
                            if let v = sh.varianceMinor { metric("Fark", Money.format(v)) }
                        } else {
                            Text("Açık kasa vardiyası yok.").foregroundColor(.secondary)
                        }
                    }
                }
                .refreshable { await vm.refresh(api: state.api) }
            }
        }
        .navigationTitle("Kasa")
        .task { await vm.refresh(api: state.api) }
        .onChange(of: vm.date) { _ in Task { await vm.refresh(api: state.api) } }
    }

    private func metric(_ title: String, _ value: String, big: Bool = false) -> some View {
        HStack {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).font(big ? .title3.bold() : .body.weight(.medium)).monospacedDigit()
                .foregroundColor(big ? Theme.primary : .primary)
        }
    }
}
