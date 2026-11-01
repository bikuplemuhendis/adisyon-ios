import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage("appearance") private var appearance = 0 // 0 sistem, 1 açık, 2 koyu
    @State private var confirmLogout = false

    var body: some View {
        Form {
            if let u = state.user {
                Section("Hesap") {
                    LabeledContent("Ad", value: u.name)
                    if let e = u.email { LabeledContent("E-posta", value: e) }
                    LabeledContent("Rol", value: u.role.title)
                }
            }
            Section("Şube") {
                LabeledContent("Aktif şube", value: state.branchName ?? "—")
                Button("Şube değiştir") { state.changeBranch() }
            }
            Section("Görünüm") {
                Picker("Tema", selection: $appearance) {
                    Text("Sistem").tag(0)
                    Text("Açık").tag(1)
                    Text("Koyu").tag(2)
                }
                .pickerStyle(.segmented)
            }
            Section("Uygulama") {
                LabeledContent("Sürüm", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                LabeledContent("Sunucu", value: AppConfig.baseURL.host ?? "-")
                LabeledContent("Bildirimler", value: AppConfig.pushEnabled ? "Açık" : "Kapalı")
            }
            Section {
                Button("Çıkış yap", role: .destructive) { confirmLogout = true }
            }
        }
        .navigationTitle("Ayarlar")
        .confirmationDialog("Çıkış yapılsın mı?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Çıkış yap", role: .destructive) { Task { await state.logout() } }
        }
    }
}

/// Kullanıcının tema tercihi.
struct AppearanceModifier: ViewModifier {
    @AppStorage("appearance") private var appearance = 0
    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
    }
}
