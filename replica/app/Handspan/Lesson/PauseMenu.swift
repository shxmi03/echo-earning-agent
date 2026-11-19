import SwiftUI
import HandspanCore

/// S13, course variant (components.md: PauseMenu): Resume, Restart, Listen, Exit, plus a
/// tempo choice on timed exercises so a hard line can be learnt slower first.
struct PauseMenu: View {
    @Bindable var session: LessonSession
    var exit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Paused")
                .font(TextStyle.title2)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)

            Button("Resume") {
                session.resume()
                dismiss()
            }
            .buttonStyle(.primaryStyle(fullWidth: true))

            HStack(spacing: Space.md) {
                Button {
                    session.restartExercise()
                    dismiss()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                Button {
                    session.listen()
                } label: {
                    Label("Listen", systemImage: "ear").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.large)

            if session.isTimed {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Tempo").font(TextStyle.subheadline.weight(.medium)).foregroundStyle(Palette.textMuted)
                    Picker("Tempo", selection: $session.tempoPct) {
                        Text(verbatim: "60%").tag(60)
                        Text(verbatim: "80%").tag(80)
                        Text(verbatim: "100%").tag(100)
                    }
                    .pickerStyle(.segmented)
                    Text("Slower is fine for learning. The lesson's stars count at any tempo.")
                        .font(TextStyle.footnote)
                        .foregroundStyle(Palette.textMuted)
                }
            }

            Spacer(minLength: 0)

            Button(role: .destructive) {
                session.stopAll()
                dismiss()
                exit()
            } label: {
                Label("Leave lesson", systemImage: "xmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            Text("The lesson starts from the beginning next time.")
                .font(TextStyle.footnote)
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity)
        }
        .padding(Layout.screenMargin)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
