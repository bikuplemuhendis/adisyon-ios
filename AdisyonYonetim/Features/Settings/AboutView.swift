import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Sürüm", value: "\(version) (\(build))")
            }
            Section("Yasal ve destek") {
                aboutLink(title: "Gizlilik Politikası", url: AppConfig.privacyURL)
                aboutLink(title: "KVKK Aydınlatma", url: AppConfig.kvkkURL)
                aboutLink(title: "Hesap silme", url: AppConfig.accountDeletionURL)
                aboutLink(title: "Destek", url: AppConfig.supportURL)
            }
        }
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutLink(title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
        }
    }
}
