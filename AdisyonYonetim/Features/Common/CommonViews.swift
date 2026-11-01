import SwiftUI

/// Yükleme / hata / içerik durumu.
enum LoadState<T> {
    case idle, loading, loaded(T), failed(String)

    var value: T? { if case .loaded(let v) = self { return v } else { return nil } }
}

struct ErrorRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.accent)
            Text(message).multilineTextAlignment(.center).foregroundColor(.secondary)
            Button("Tekrar dene", action: retry)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 240)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// NWPathMonitor çevrimdışı dediğinde tüm ekranın üstünde gösterilir.
struct OfflineView: View {
    @EnvironmentObject private var state: AppState
    @State private var checking = false

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.97).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Text("Bağlantı yok").font(.title2.bold())
                Text("İnternet bağlantınızı kontrol edin. Bağlantı geldiğinde otomatik devam edilir.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button {
                    checking = true
                    Task {
                        await state.bootstrap()
                        checking = false
                    }
                } label: {
                    if checking { ProgressView().tint(.white) } else { Text("Tekrar dene") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
            }
            .padding(32)
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

extension View {
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Hata", isPresented: Binding(get: { message.wrappedValue != nil },
                                          set: { if !$0 { message.wrappedValue = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

func errorText(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}
