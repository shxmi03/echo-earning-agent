import SwiftUI
import HandspanCore

/// S06: email → 6-digit code → profile name. No password.
/// States: email, sending, code sent, wrong code, expired code, too many tries, offline, name.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    let returning: Bool

    @State private var phase: Phase = .email
    @State private var email = ""
    @State private var code = ""
    @State private var name = ""
    @State private var session: Session?
    @State private var error: String?
    @State private var busy = false
    @State private var resendAt = Date.distantPast
    @FocusState private var focus: Field?

    enum Phase { case email, code, name }
    enum Field { case email, code, name }

    var body: some View {
        OnboardingScaffold(title: title, subtitle: subtitle, buttonTitle: buttonTitle,
                           buttonEnabled: canContinue, isLoading: busy, action: submit) {
            VStack(alignment: .leading, spacing: Space.md) {
                switch phase {
                case .email:
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .focused($focus, equals: .email)
                        .onSubmit(submit)
                        .modifier(InputField(label: "Email"))
                case .code:
                    TextField("6-digit code", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .font(TextStyle.number(.title2))
                        .focused($focus, equals: .code)
                        .onChange(of: code) { _, new in
                            let digits = String(new.filter(\.isNumber).prefix(6))
                            if digits != new { code = digits }
                            if digits.count == 6, !busy { submit() }
                        }
                        .modifier(InputField(label: "Code"))
                    HStack {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let wait = Int(resendAt.timeIntervalSince(context.date).rounded(.up))
                            Button(wait > 0 ? "Send a new code in \(wait) s" : "Send a new code") { resend() }
                                .disabled(wait > 0 || busy)
                        }
                        Spacer()
                        Button("Different email") {
                            phase = .email
                            code = ""
                            error = nil
                            focus = .email
                        }
                    }
                    .font(TextStyle.subheadline)
                case .name:
                    TextField("Your first name", text: $name)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .focused($focus, equals: .name)
                        .onSubmit(submit)
                        .modifier(InputField(label: "Name"))
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(TextStyle.subheadline)
                        .foregroundStyle(Palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .onAppear { focus = .email }
    }

    private var title: String {
        switch phase {
        case .email: returning ? "Welcome back" : "Save your progress"
        case .code: "Check your email"
        case .name: "What should we call you?"
        }
    }

    private var subtitle: String? {
        switch phase {
        case .email: "Enter your email. We'll send a 6-digit code. No password."
        case .code: "We sent a code to \(email.trimmingCharacters(in: .whitespaces))."
        case .name: "It shows on your home screen. You can change it later."
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .email: "Send code"
        case .code: "Check code"
        case .name: "Start lesson 1"
        }
    }

    private var canContinue: Bool {
        switch phase {
        case .email: EmailRule.isPlausible(email)
        case .code: code.count == 6
        case .name: Profile.validName(name) != nil
        }
    }

    private func submit() {
        guard canContinue, !busy else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                switch phase {
                case .email:
                    try await model.backend.sendCode(to: email.trimmingCharacters(in: .whitespaces))
                    resendAt = .now.addingTimeInterval(30)
                    phase = .code
                    focus = .code
                case .code:
                    let verified = try await model.backend.verify(email: email.trimmingCharacters(in: .whitespaces), code: code)
                    session = verified
                    if try await model.restoreAccount(session: verified) { return }
                    phase = .name
                    focus = .name
                case .name:
                    guard let session, let valid = Profile.validName(name) else { return }
                    try await model.finishOnboarding(session: session, name: valid)
                }
            } catch let authError as AuthError {
                error = message(for: authError)
                if authError == .wrongCode { code = "" }
            } catch BackendError.notSignedIn {
                phase = .email
                code = ""
                self.error = "Your sign-in ran out. Enter your email again."
            } catch {
                self.error = "Something went wrong on our side. Try again in a moment."
            }
        }
    }

    private func resend() {
        code = ""
        error = nil
        Task {
            do {
                try await model.backend.sendCode(to: email.trimmingCharacters(in: .whitespaces))
                resendAt = .now.addingTimeInterval(30)
            } catch let authError as AuthError {
                error = message(for: authError)
            } catch {
                self.error = "Something went wrong on our side. Try again in a moment."
            }
        }
    }

    private func message(for error: AuthError) -> String {
        switch error {
        case .invalidEmail: "That email address doesn't look complete. Check for typos."
        case .wrongCode: "That code doesn't match. Check the latest email from us."
        case .expiredCode: "That code has expired. Send a new one."
        case .tooManyTries: "Too many wrong codes. Send a new one."
        case .offline: "No connection. Connect to the internet to sign in."
        }
    }
}

/// A labelled text field on a filled surface. The label stays visible (not just a placeholder).
struct InputField: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).font(TextStyle.subheadline.weight(.medium)).foregroundStyle(Palette.textMuted)
            content
                .font(TextStyle.body)
                .padding(.horizontal, Space.md)
                .frame(minHeight: Layout.minTarget + Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Palette.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Palette.borderInput, lineWidth: 1)
                )
                .accessibilityLabel(label)
        }
    }
}
