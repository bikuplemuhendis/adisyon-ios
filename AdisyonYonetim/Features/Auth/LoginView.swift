import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focus: Field?
    enum Field { case email, password, slug, totp }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                Picker("Giriş türü", selection: $vm.mode) {
                    ForEach(LoginViewModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if vm.pendingToken != nil {
                    totpForm
                } else if vm.mode == .email {
                    emailForm
                } else {
                    pinForm
                }

                if let e = vm.error ?? state.bannerError {
                    Text(e).font(.footnote).foregroundColor(Theme.danger).multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: vm.mode) { _ in vm.error = nil; state.bannerError = nil }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("LaunchLogo").resizable().scaledToFit().frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("Adisyon Yönetim").font(.largeTitle.bold()).foregroundColor(Theme.primary)
            Text("Personel girişi").foregroundColor(.secondary)
        }
        .padding(.top, 32)
    }

    private var emailForm: some View {
        VStack(spacing: 14) {
            TextField("E-posta", text: $vm.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
                .fieldStyle()
            SecureField("Şifre", text: $vm.password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await vm.loginEmail(state: state) } }
                .fieldStyle()
            Button {
                Task { await vm.loginEmail(state: state) }
            } label: {
                if vm.isLoading { ProgressView().tint(.white) } else { Text("Giriş yap") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!vm.canSubmitEmail)
            .opacity(vm.canSubmitEmail ? 1 : 0.6)
        }
    }

    private var pinForm: some View {
        VStack(spacing: 18) {
            TextField("İşletme kodu (örn. demo-kafe)", text: $vm.businessSlug)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .slug)
                .fieldStyle()
            PinPad(pin: $vm.pin, maxLength: 8) {
                Task { await vm.loginPin(state: state) }
            }
            .disabled(vm.isLoading)
            if vm.isLoading { ProgressView() }
        }
    }

    private var totpForm: some View {
        VStack(spacing: 14) {
            Text("İki adımlı doğrulama").font(.headline)
            Text("Doğrulayıcı uygulamanızdaki 6 haneli kodu girin.").font(.subheadline).foregroundColor(.secondary)
            TextField("123456", text: $vm.totpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .focused($focus, equals: .totp)
                .fieldStyle()
            Button {
                Task { await vm.verify2fa(state: state) }
            } label: {
                if vm.isLoading { ProgressView().tint(.white) } else { Text("Doğrula") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(vm.totpCode.count != 6 || vm.isLoading)
            Button("Vazgeç") { vm.pendingToken = nil; vm.totpCode = "" }
        }
        .onAppear { focus = .totp }
    }
}

struct PinPad: View {
    @Binding var pin: String
    let maxLength: Int
    let onSubmit: () -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✓"]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<max(4, pin.count), id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Theme.primary : Color.secondary.opacity(0.25))
                        .frame(width: 14, height: 14)
                }
            }
            .frame(height: 20)
            .accessibilityLabel("\(pin.count) hane girildi")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(keys, id: \.self) { key in
                    Button { tap(key) } label: {
                        Text(key)
                            .font(.title.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(key == "✓" ? Theme.primary : Color(.secondarySystemGroupedBackground))
                            .foregroundColor(key == "✓" ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(key == "✓" && pin.count < 4)
                    .accessibilityLabel(key == "⌫" ? "Sil" : key == "✓" ? "Giriş" : key)
                }
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫": if !pin.isEmpty { pin.removeLast() }
        case "✓": onSubmit()
        default: if pin.count < maxLength { pin.append(key) }
        }
    }
}

extension View {
    func fieldStyle() -> some View {
        self.padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
