import SwiftUI
import HandspanCore
import StoreKit
import CoreAudioKit

/// S23, the part needed for App Review: input mode, the plan (manage in one tap, request
/// a refund), the account, and account deletion (guideline 5.1.1(v)).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreModel.self) private var store
    @State private var showPlans = false
    @State private var checkTiming = false
    @State private var pairBluetooth = false
    @Environment(MIDIInput.self) private var midi
    @AppStorage("showFingers") private var showFingers = true
    @State private var remind = PracticeReminder.isOn
    @State private var remindAt = PracticeReminder.time
    @State private var remindNote: String?
    @State private var manage = false
    @State private var refundFor: UInt64?
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
                        Text("MIDI keyboard (USB or Bluetooth)").tag(InputMode.midi)
                        Text("Keys on the screen").tag(InputMode.touch)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if model.inputMode == .mic {
                        Button("Check timing") { checkTiming = true }
                    }
                    if model.inputMode == .midi {
                        LabeledContent("Keyboard", value: midi.devices.first ?? "None found")
                        Button("Pair a Bluetooth MIDI keyboard") { pairBluetooth = true }
                    }
                    Toggle("Finger numbers on the staff", isOn: $showFingers)
                }

                Section {
                    Toggle("Daily reminder", isOn: Binding(get: { remind }, set: { setReminder($0) }))
                    if remind {
                        DatePicker("Time", selection: $remindAt, displayedComponents: .hourAndMinute)
                            .onChange(of: remindAt) { _, time in Task { await PracticeReminder.turnOn(at: time) } }
                    }
                } header: {
                    Text("Practice")
                } footer: {
                    Text(remindNote ?? "One quiet nudge a day, at the time you pick. Off by default.")
                }

                Section {
                    if let plan = store.activePlan {
                        LabeledContent("Plan", value: "\(plan.size.title), \(plan.period.title.lowercased())")
                        Button("Manage or cancel subscription") { manage = true }
                        if let id = store.latestTransactionId {
                            Button("Request a refund") { refundFor = id }
                        }
                    } else {
                        LabeledContent("Plan", value: "Free: the first course")
                    }
                    Button("See plans") { showPlans = true }
                } header: {
                    Text("Plan")
                } footer: {
                    Text("Cancelling takes one tap and keeps your plan until the end of the period you paid for.")
                }

                Section("Account") {
                    if let profile = model.state.profile {
                        LabeledContent("Name", value: profile.name)
                    }
                    if let email = model.state.session?.email {
                        LabeledContent("Email", value: email)
                    }
                }

                Section("About") {
                    Link("Privacy policy", destination: LegalLinks.privacy)
                    Link("Terms of use", destination: LegalLinks.terms)
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
            .sheet(isPresented: $showPlans) { PaywallView() }
            .sheet(isPresented: $checkTiming) { TimingCheckView() }
            .sheet(isPresented: $pairBluetooth, onDismiss: { midi.refresh() }) {
                NavigationStack {
                    BluetoothMIDIPairing()
                        .navigationTitle("Bluetooth MIDI")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { pairBluetooth = false } }
                        }
                }
            }
            .onChange(of: model.inputMode, initial: true) { _, mode in
                if mode == .midi { midi.start() }
            }
            .manageSubscriptionsSheet(isPresented: $manage)
            .refundRequestSheet(for: refundFor ?? 0, isPresented: Binding(
                get: { refundFor != nil }, set: { if !$0 { refundFor = nil } }))
            .task { await store.refreshEntitlement() }
            .confirmationDialog("Delete your account and all progress?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { delete() }
                Button("Keep my account", role: .cancel) {}
            }
        }
    }

    private func setReminder(_ on: Bool) {
        remindNote = nil
        guard on else {
            remind = false
            PracticeReminder.turnOff()
            return
        }
        remind = true
        Task {
            let granted = await PracticeReminder.turnOn(at: remindAt)
            if !granted {
                remind = false
                remindNote = "Notifications are off for Handspan. Turn them on in Settings › Notifications › Handspan."
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

#Preview { SettingsView().environment(AppModel.preview()).environment(StoreModel()).environment(AudioInput()).environment(MIDIInput()) }

/// Apple's own Bluetooth MIDI pairing screen (CoreAudioKit). USB keyboards need nothing.
struct BluetoothMIDIPairing: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CABTMIDICentralViewController { CABTMIDICentralViewController() }
    func updateUIViewController(_ controller: CABTMIDICentralViewController, context: Context) {}
}
