import SwiftUI

/// Account + developer configuration. The Yoto client id is entered here on first run.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var clientIDField = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var environment = appEnvironment

        Form {
            accountSection
            developerSection(environment: environment)
            optionsSection(environment: environment)
            guidanceSection
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear { clientIDField = appEnvironment.clientID }
        .alert("Sign-in failed", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var accountSection: some View {
        Section("Yoto Account") {
            switch appEnvironment.auth.status {
            case .signedIn:
                Label("Signed in", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Sign Out", role: .destructive) {
                    Task { await appEnvironment.auth.signOut() }
                }
            case .signingIn:
                HStack {
                    ProgressView()
                    Text("Signing in…")
                }
            case .signedOut:
                Button {
                    signIn()
                } label: {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign In with Yoto")
                    }
                }
                .disabled(!appEnvironment.hasClientID || isSigningIn)
                if !appEnvironment.hasClientID {
                    Text("Add your Client ID below to enable sign-in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func developerSection(environment: AppEnvironment) -> some View {
        Section("Developer") {
            TextField("Yoto Client ID", text: $clientIDField)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
            Button("Save Client ID") {
                appEnvironment.updateClientID(clientIDField)
            }
            .disabled(clientIDField.trimmingCharacters(in: .whitespaces) == appEnvironment.clientID)
            LabeledContent("Redirect URI", value: "yototools://callback")
                .font(.footnote)
        }
    }

    private func optionsSection(environment: AppEnvironment) -> some View {
        Section("Options") {
            Toggle("Private sign-in session", isOn: Binding(
                get: { environment.usesEphemeralSession },
                set: { environment.usesEphemeralSession = $0 }))
        }
    }

    private var guidanceSection: some View {
        Section("How to get a Client ID") {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Sign in at dashboard.yoto.dev")
                Text("2. Create a Native / public client app (PKCE, no secret).")
                Text("3. Add redirect URI **yototools://callback**.")
                Text("4. Enable scopes: content view/manage and icons manage, plus offline_access.")
                Text("5. Paste the Client ID above and Save.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func signIn() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                try await appEnvironment.auth.signIn()
            } catch is CancellationError {
                // user cancelled; ignore
            } catch let error as WebAuthError where error == .cancelled {
                // user cancelled; ignore
            } catch {
                errorMessage = APIErrorFormatter.message(error)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
