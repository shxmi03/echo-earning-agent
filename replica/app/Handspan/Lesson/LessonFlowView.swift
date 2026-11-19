import SwiftUI
import HandspanCore

/// F02 inside one lesson: S10 concept → S11 exercises → S14 result.
struct LessonFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(AudioInput.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @State private var session: LessonSession
    @State private var recorded = false

    init(lesson: Lesson) {
        _session = State(initialValue: LessonSession(lesson: lesson))
    }

    var body: some View {
        Group {
            switch session.phase {
            case .concept:
                ConceptView(lesson: session.lesson, close: close) { session.beginExercises() }
            case .exercise:
                ExerciseView(session: session, close: close)
            case .result:
                ResultView(lesson: session.lesson, result: session.run.result,
                           next: model.course.lesson(after: session.lesson.id),
                           tryAgain: {
                               recorded = false
                               session.restart()
                           },
                           close: close)
            }
        }
        .animation(Motion.standard, value: session.phase)
        .background(Palette.paper.ignoresSafeArea())
        .onChange(of: session.phase, initial: true) { _, phase in
            switch phase {
            case .exercise:
                startListeningIfNeeded()
            case .result:
                audio.stop()
                if !recorded {
                    recorded = true
                    model.record(session.run.result, lesson: session.lesson, startedAt: session.run.startedAt)
                }
            case .concept:
                break
            }
        }
        .onChange(of: model.inputMode) { _, _ in
            if session.phase == .exercise { startListeningIfNeeded() }
        }
        .onDisappear {
            session.stopAll()
            audio.onNote = nil
            audio.stop()
        }
    }

    private func startListeningIfNeeded() {
        guard model.inputMode == .mic else {
            audio.stop()
            return
        }
        audio.onNote = { [session] pitch, heardAt in session.play(pitch, at: heardAt) }
        Task { await audio.start() }
    }

    private func close() {
        session.stopAll()
        audio.stop()
        dismiss()
    }
}

// MARK: - S10 Concept card

struct ConceptView: View {
    let lesson: Lesson
    var close: () -> Void
    var start: () -> Void

    var body: some View {
        let concept = lesson.concept
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack {
                    GlassIconButton(systemImage: "xmark", label: "Close lesson", action: close)
                    Spacer()
                }
                Text(lesson.title.uppercased())
                    .font(TextStyle.caption)
                    .foregroundStyle(Palette.textMuted)
                Text(concept?.title ?? lesson.title)
                    .font(TextStyle.largeTitle)
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                if let keys = concept?.keys, !keys.isEmpty {
                    VStack {
                        KeyboardStrip(lowestMidi: 48, octaves: 3,
                                      states: Dictionary(uniqueKeysWithValues: keys.map { ($0.midi, NoteState.target) }))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Keyboard with \(keys.map(\.name).joined(separator: ", ")) marked")
                }
                ForEach(concept?.paragraphs ?? [], id: \.self) { paragraph in
                    Text(paragraph)
                        .font(TextStyle.body)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let tip = concept?.tip {
                    Label(tip, systemImage: "hand.raised")
                        .font(TextStyle.subheadline)
                        .foregroundStyle(Palette.text)
                        .padding(Space.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                            .fill(Palette.surfaceSunken))
                }
            }
            .padding(.horizontal, Layout.screenMargin + Space.xs)
            .padding(.top, Space.md)
            .frame(maxWidth: Layout.maxReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Start the exercises", action: start)
                .buttonStyle(.primaryStyle(fullWidth: true))
                .padding(.horizontal, Layout.screenMargin + Space.xs)
                .padding(.bottom, Space.sm)
                .frame(maxWidth: Layout.maxReadableWidth)
        }
    }
}

#Preview {
    LessonFlowView(lesson: try! SeedContent.firstCourse().lessons[0])
        .environment(AppModel.preview())
        .environment(AudioInput())
}
