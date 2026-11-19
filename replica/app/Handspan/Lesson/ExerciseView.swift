import SwiftUI
import HandspanCore

/// S11: read a note and play it. No clock; it waits for the right key.
/// S12 when the exercise is timed: the staff moves under a cursor in time with a click.
/// States: waiting (target), correct, wrong (with a hint), not heard, mic off; on the
/// stage also ready, count-in, playing and paused (S13 menu).
struct ExerciseView: View {
    @Environment(AppModel.self) private var model
    @Environment(AudioInput.self) private var audio
    let session: LessonSession
    var close: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            header

            if let exercise = session.exercise {
                Text(exercise.prompt)
                    .font(TextStyle.title3)
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if exercise.isTimed {
                        MovingStageView(session: session)
                    } else {
                        StaffView(exercise: exercise, states: session.noteStates)
                    }
                }
                    .frame(minHeight: 180, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                        .strokeBorder(Palette.border))
                    .id(exercise.id)
                    .transition(.push(from: .trailing))
            }

            Text(session.message)
                .font(TextStyle.headline)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: Layout.minTarget, alignment: .leading)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)

            if session.isTimed, session.stage != .running {
                Button(session.stage == .paused ? "Start again" : "Start") { session.startStage() }
                    .buttonStyle(.primaryStyle(fullWidth: true))
                    .accessibilityHint("Four clicks count you in, then the notes move to the line.")
            }

            Spacer(minLength: 0)

            if usesScreenKeys {
                PlayableKeyboard(lowestMidi: 60, octaves: 1, states: session.keyStates) { session.play(Pitch($0)) }
            } else {
                KeyboardStrip(lowestMidi: 60, octaves: 1, states: session.keyStates)
            }

            footer
        }
        .padding(.horizontal, Layout.screenMargin)
        .padding(.bottom, Space.sm)
        .frame(maxWidth: Layout.maxReadableWidth * 1.4)
        .frame(maxWidth: .infinity)
        .animation(Motion.standard, value: session.exercise?.id)
        .sensoryFeedback(.error, trigger: session.wrongCount)
        .onChange(of: session.message) { _, message in
            AccessibilityNotification.Announcement(message).post()
        }
        .sheet(isPresented: Binding(get: { session.isPaused }, set: { open in
            // Swiping the menu away is the same as Resume.
            if !open, session.isPaused { session.resume() }
        })) {
            PauseMenu(session: session, exit: close)
        }
    }

    /// Screen keys when the learner chose them, or when the mic can't be used.
    private var usesScreenKeys: Bool {
        if model.inputMode == .touch { return true }
        switch audio.status {
        case .denied, .failed: return true
        default: return false
        }
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            GlassIconButton(systemImage: "pause.fill", label: "Pause") { session.pause() }
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Exercise \(session.exerciseNumber) of \(session.run.exerciseCount)")
                    .font(TextStyle.footnote.monospacedDigit())
                    .foregroundStyle(Palette.textMuted)
                ProgressView(value: session.progress)
                    .tint(Palette.tint)
                    .animation(Motion.standard, value: session.progress)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, Space.xs)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: Space.md) {
            if usesScreenKeys {
                if model.inputMode == .mic {
                    Label("The microphone is off. Tap the keys instead.", systemImage: "mic.slash")
                } else {
                    Label("Tap the key on the screen.", systemImage: "hand.tap")
                }
            } else {
                switch audio.status {
                case .running:
                    Label("Listening", systemImage: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: audio.level > 0.15)
                case .interrupted:
                    Label("Paused while another app uses the microphone", systemImage: "pause.circle")
                default:
                    Label("Starting the microphone", systemImage: "mic")
                }
                Spacer()
                if !session.isTimed {
                    Button("I played it right") { session.overrideCorrect() }
                        .buttonStyle(.glass)
                        .accessibilityHint("Counts this note when Handspan didn't hear it correctly.")
                }
            }
        }
        .font(TextStyle.footnote)
        .foregroundStyle(Palette.textMuted)
        .frame(maxWidth: .infinity, minHeight: Layout.minTarget, alignment: .leading)
    }
}

/// The keyboard strip, playable (components.md: the touch variant of KeyboardStrip).
/// For the no-piano path and when the mic is off.
struct PlayableKeyboard: View {
    var lowestMidi: Int = 60
    var octaves: Int = 1
    var states: [Int: NoteState] = [:]
    var press: (Int) -> Void

    private var highest: Int { lowestMidi + 12 * octaves }
    private var whiteKeys: [Int] {
        (lowestMidi...highest).filter { !KeyboardStrip.isBlack($0) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(whiteKeys.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(whiteKeys, id: \.self) { midi in
                        key(midi, black: false).frame(width: w - 1)
                    }
                }
                ForEach(whiteKeys.indices, id: \.self) { i in
                    let midi = whiteKeys[i] + 1
                    if KeyboardStrip.isBlack(midi), midi < highest {
                        key(midi, black: true)
                            .frame(width: w * 0.6, height: geo.size.height * 0.62)
                            .offset(x: w * CGFloat(i + 1) - w * 0.3)
                    }
                }
            }
        }
        .frame(height: 140)
        .animation(Motion.keyFeedback, value: states)
    }

    private func key(_ midi: Int, black: Bool) -> some View {
        let state = states[midi]
        return Button {
            press(midi)
        } label: {
            RoundedRectangle(cornerRadius: Space.xs - 2, style: .continuous)
                .fill(state.map(\.color) ?? (black ? Palette.ink : Palette.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: Space.xs - 2, style: .continuous)
                    .strokeBorder(Palette.border))
                .overlay(alignment: .bottom) {
                    if let symbol = state?.symbol {
                        Image(systemName: symbol).font(.caption.weight(.bold))
                            .foregroundStyle(Palette.onTint).padding(.bottom, Space.xs)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Pitch(midi).name)
        .accessibilityValue(state?.accessibilityLabel ?? "")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}
