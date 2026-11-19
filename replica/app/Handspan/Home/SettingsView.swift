import SwiftUI
import HandspanCore

/// S23, the part needed for App Review: input mode, the account, and account deletion
/// (guideline 5.1.1(v)). Subscription management comes with the paywall (S05).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Playing on") {
                    Picker("Input", selection: Binding(
                        get: { model.inputMode },
                        set: { model.setInputMode($0) }
                    )) {
                        Text("Piano, through the microphone").tag(InputMode.mic)
                        Text("Keys on the screen").tag(InputMode.touch)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Account") {
                    if let profile = model.state.profile {
                        LabeledContent("Name", value: profile.name)
                    }
                    if let email = model.state.session?.email {
                        LabeledContent("Email", value: email)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        if deleting { ProgressView() } else { Text("Delete account") }
                    }
                    .disabled(deleting)
                } footer: {
                    Text("Deletes your account, your profile and all your progress, on this \(DeviceWord.current) and on our servers. It can't be undone. Deleting doesn't cancel an App Store subscription: do that in Settings › Apple Account › Subscriptions.")
                }
                if let deleteError {
                    Text(deleteError).foregroundStyle(Palette.danger)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete your account and all progress?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { delete() }
                Button("Keep my account", role: .cancel) {}
            }
        }
    }

    private func delete() {
        deleting = true
        deleteError = nil
        Task {
            defer { deleting = false }
            do {
                try await model.deleteAccount()
                dismiss()
            } catch {
                deleteError = "We couldn't delete the account just now. Check your connection and try again."
            }
        }
    }
}

#Preview { SettingsView().environment(AppModel.preview()) }
