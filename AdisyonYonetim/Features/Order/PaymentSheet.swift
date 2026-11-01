import SwiftUI

struct PaymentSheet: View {
    let bill: Bill
    let onPay: (PaymentMethod, Int, Int, Bool) async -> Bool
    @Environment(\.dismiss) private var dismiss

    @State private var method: PaymentMethod = .CASH
    @State private var amountText = ""
    @State private var tipText = ""
    @State private var closeIfPaid = true
    @State private var busy = false

    private var amount: Int? { Money.parse(amountText) }
    private var tip: Int { Money.parse(tipText) ?? 0 }
    private var change: Int { method == .CASH ? max(0, (amount ?? 0) - bill.balanceMinor) : 0 }
    /// Para üstü varsa API'ye yalnızca bakiye kadar gönderilir.
    private var tenderMinor: Int { min(amount ?? 0, bill.balanceMinor) }
    private var valid: Bool { tenderMinor > 0 && (method == .CASH || (amount ?? 0) <= bill.balanceMinor) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Text("Kalan bakiye"); Spacer(); Text(Money.format(bill.balanceMinor)).bold().monospacedDigit() }
                    if bill.paidMinor > 0 {
                        HStack { Text("Ödenen"); Spacer(); Text(Money.format(bill.paidMinor)).monospacedDigit() }
                    }
                }
                Section("Ödeme yöntemi") {
                    Picker("Yöntem", selection: $method) {
                        ForEach(PaymentMethod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Tutar") {
                    HStack {
                        TextField("0,00", text: $amountText).keyboardType(.decimalPad).font(.title2.monospacedDigit())
                        Text("₺")
                    }
                    HStack {
                        quick("Tamamı", bill.balanceMinor)
                        quick("½", bill.balanceMinor / 2)
                        if method == .CASH {
                            quick("200", 20000)
                            quick("500", 50000)
                        }
                    }
                    if change > 0 {
                        HStack { Text("Para üstü"); Spacer(); Text(Money.format(change)).foregroundColor(Theme.accent).bold() }
                    }
                }
                Section("Bahşiş") {
                    TextField("0,00", text: $tipText).keyboardType(.decimalPad)
                }
                Section {
                    Toggle("Bakiye sıfırlanırsa adisyonu kapat", isOn: $closeIfPaid)
                }
                Section {
                    Button {
                        busy = true
                        Task {
                            let ok = await onPay(method, tenderMinor, tip, closeIfPaid)
                            busy = false
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack { Spacer(); if busy { ProgressView() } else { Text("\(Money.format(tenderMinor)) tahsil et").bold() }; Spacer() }
                    }
                    .disabled(!valid || busy)
                }
            }
            .navigationTitle("Ödeme al")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } } }
            .onAppear { amountText = String(format: "%.2f", Double(bill.balanceMinor) / 100).replacingOccurrences(of: ".", with: ",") }
        }
    }

    private func quick(_ title: String, _ minor: Int) -> some View {
        Button(title) {
            amountText = String(format: "%.2f", Double(minor) / 100).replacingOccurrences(of: ".", with: ",")
        }
        .buttonStyle(.bordered)
        .tint(Theme.primary)
    }
}
