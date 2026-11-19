import SwiftUI
import HandspanCore

/// S04: ask for the microphone, then confirm a note is heard.
/// States: ask, listening, heard, nothing heard, denied, failed.
struct SoundCheckView: View {
    @Environment(AppModel.self) private var model
    @Environment(AudioInput.self) private var audio
    @Environment(\.openURL) private var openURL
    @State private var phase: Phase = .ask
    @State private var listenTask: Task<Void, Never>?
    var next: () -> Void

    enum Phase: Equatable { case ask, listening, heard(Pitch), silent, denied, failed(String) }

    var body: some View {
        OnboardingScaffold(step: 4, title: title, subtitle: subtitle,
                           buttonTitle: buttonTitle, buttonEnabled: phase != .listening, action: primary) {
            VStack(alignment: .leading, spacing: Space.lg) {
                switch phase {
                case .ask:
                    Image(systemName: "mic")
                        .font(.system(.largeTitle))
                        .foregroundStyle(Palette.tint)
                        .accessibilityHidden(true)
                case .listening, .silent:
                    LevelMeter(level: audio.level)
                    if phase == .silent {
                        Text("Nothing heard yet. Move the \(DeviceWord.current) closer to the piano. On a digital piano, check that the volume is up.")
                            .font(TextStyle.subheadline)
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        useScreenKeysButton
                    }
                case .heard(let pitch):
                    Label("Heard \(pitch.name).", systemImage: "checkmark.circle.fill")
                        .font(TextStyle.title3)
                        .foregroundStyle(Palette.success)
                case .denied, .failed:
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.glass)
                    useScreenKeysButton
                }
            }
        }
        .onChange(of: audio.notesHeard) { _, _ in
            guard let pitch = audio.lastHeard, phase == .listening || phase == .silent else { return }
            listenTask?.cancel()
            phase = .heard(pitch)
        }
        .onChange(of: audio.status) { _, status in
            if status == .denied { phase = .denied }
            if case .failed(let message) = status { phase = .failed(message) }
        }
        .onAppear {
            if audio.permission == .denied { phase = .denied }
        }
        .onDisappear {
            listenTask?.cancel()
            audio.stop()
        }
    }

    private var useScreenKeysButton: some View {
        Button("Use the keys on the screen for now") {
            model.setInputMode(.touch)
            audio.stop()
            next()
        }
        .font(TextStyle.headline)
        .frame(minHeight: Layout.minTarget)
    }

    private var title: String {
        switch phase {
        case .ask: "Let Handspan hear your piano"
        case .listening, .silent: "Play any key"
        case .heard: "Handspan can hear you"
        case .denied: "The microphone is off"
        case .failed: "The microphone didn't start"
        }
    }

    private var subtitle: String? {
        switch phase {
        case .ask: "Handspan listens to your piano to check each note. The sound stays on this \(DeviceWord.current)."
        case .listening, .silent: "A single note, held for a moment."
        case .heard: "Every note you play will be checked like that one."
        case .denied: "Handspan needs the microphone to hear your piano. You can turn it on in Settings, or play on the screen for now."
        case .failed(let message): message
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .ask: "Allow the microphone"
        case .listening: "Listening…"
        case .silent: "Keep listening"
        case .heard, .denied, .failed: "Continue"
        }
    }

    private func primary() {
        switch phase {
        case .ask, .silent:
            listen()
        case .listening:
            break
        case .heard:
            audio.stop()
            next()
        case .denied, .failed:
            // Carry on without the mic; the player offers the screen keys.
            model.setInputMode(.touch)
            next()
        }
    }

    private func listen() {
        phase = .listening
        listenTask?.cancel()
        listenTask = Task {
            await audio.start()
            guard audio.status == .running else { return }
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled, phase == .listening { phase = .silent }
        }
    }
}

/// A plain input-level bar for the sound check.
struct LevelMeter: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceSunken)
                Capsule().fill(Palette.tint)
                    .frame(width: max(Space.sm, geo.size.width * level))
            }
        }
        .frame(height: Space.sm)
        .animation(Motion.keyFeedback, value: level)
        .accessibilityElement()
        .accessibilityLabel("Input level")
        .accessibilityValue(Text(level, format: .percent.precision(.fractionLength(0))))
    }
}
