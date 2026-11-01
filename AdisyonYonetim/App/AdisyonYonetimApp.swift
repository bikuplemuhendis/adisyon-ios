import SwiftUI

@main
struct AdisyonYonetimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(network)
                .tint(Theme.primary)
                .modifier(AppearanceModifier())
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        ZStack {
            switch state.phase {
            case .launching:
                SplashView()
            case .loggedOut:
                LoginView()
            case .needsBranch:
                BranchPickerView()
            case .ready:
                MainTabView()
            }
            if !network.isOnline {
                OfflineView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.default, value: network.isOnline)
        .task { await state.bootstrap() }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Image("LaunchLogo").resizable().scaledToFit().frame(width: 160, height: 160)
                ProgressView().tint(Theme.primary)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let role = state.user?.role ?? .unknown
        TabView {
            if !role.isKitchen {
                TablesView()
                    .tabItem { Label("Masalar", systemImage: "square.grid.2x2") }
            }
            NavigationStack { KitchenView() }
                .tabItem { Label("Mutfak", systemImage: "flame") }
            if role.canSeeReports {
                NavigationStack { CashSummaryView() }
                    .tabItem { Label("Kasa", systemImage: "turkishlirasign.circle") }
            }
            NavigationStack { SettingsView() }
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
    }
}
