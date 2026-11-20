import SwiftUI
import HandspanCore

/// S09: the course's lessons in order. Done (with stars), current, locked.
struct CoursePathView: View {
    @Environment(AppModel.self) private var model
    var start: (Lesson) -> Void

    var body: some View {
        List {
            Section {
                Text(model.course.summary)
                    .font(TextStyle.subheadline)
                    .foregroundStyle(Palette.textMuted)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(model.course.lessons) { lesson in
                    if let gate = model.course.gate(before: lesson.id) {
                        gateRow(gate)
                    }
                    row(lesson, state: model.state.state(of: lesson, in: model.course))
                }
            }
        }
        .navigationTitle(model.course.title)
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
    }

    @ViewBuilder
    private func row(_ lesson: Lesson, state: LocalState.LessonState) -> some View {
        let number = model.lessonNumber(lesson)
        Button {
            start(lesson)
        } label: {
            HStack(spacing: Space.md) {
                LessonNode(number: number, state: state)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(lesson.title).font(TextStyle.headline).foregroundStyle(Palette.text)
                    Text(lesson.kind == .song
                         ? "Song · \(lesson.minutes) min · \(lesson.exercises.count - 1) lines, then the whole song"
                         : "\(lesson.minutes) min · \(lesson.exercises.count) exercises")
                        .font(TextStyle.footnote).foregroundStyle(Palette.textMuted)
                }
                Spacer()
                if case .done(let stars) = state {
                    HStack(spacing: Space.xxs) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .foregroundStyle(i < stars ? Palette.warning : Palette.textMuted)
                        }
                    }
                    .font(TextStyle.footnote)
                }
            }
            .padding(.vertical, Space.xxs)
            .frame(minHeight: Layout.minTarget)
        }
        .disabled(state == .locked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lesson \(number), \(lesson.title)")
        .accessibilityValue(accessibilityValue(state))
        .accessibilityHint(state == .locked ? lockedHint(lesson) : "")
    }

    private func lockedHint(_ lesson: Lesson) -> String {
        if let gate = model.course.gate(before: lesson.id),
           !model.state.progress(of: gate, in: model.course).isOpen {
            return "Opens at \(gate.starsRequired) stars from \(model.lessonRange(for: gate))."
        }
        return "Finish the lessons before it first."
    }

    // MARK: Star gates

    /// A checkpoint between lessons. When it's the next step, tapping it replays the
    /// lesson with the most stars to gain (fix 4: never a dead end).
    @ViewBuilder
    private func gateRow(_ gate: StarGate) -> some View {
        let state = model.state.state(of: gate, in: model.course)
        let p = model.state.progress(of: gate, in: model.course)
        Button {
            if case .gate(_, _, let replay) = model.nextStep { start(replay) }
        } label: {
            HStack(spacing: Space.md) {
                GateNode(state: state)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(gate.title).font(TextStyle.headline).foregroundStyle(Palette.text)
                    Text(gateLine(state, p, gate))
                        .font(TextStyle.footnote).foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Label("\(min(p.earned, p.required))/\(p.required)", systemImage: "star.fill")
                    .font(TextStyle.footnote.monospacedDigit())
                    .foregroundStyle(p.isOpen ? Palette.warning : Palette.textMuted)
            }
            .padding(.vertical, Space.xxs)
            .frame(minHeight: Layout.minTarget)
        }
        .disabled(!isCurrent(state))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checkpoint, \(gate.title)")
        .accessibilityValue("\(p.earned) of \(p.required) stars")
        .accessibilityHint(isCurrent(state) ? "Replays the lesson with the most stars to gain." : "")
    }

    private func isCurrent(_ state: LocalState.GateState) -> Bool {
        if case .current = state { true } else { false }
    }

    private func gateLine(_ state: LocalState.GateState, _ p: LocalState.GateProgress, _ gate: StarGate) -> String {
        let range = model.lessonRange(for: gate)
        switch state {
        case .open:
            return "Open: \(p.earned) stars from \(range)."
        case .current:
            return "\(p.missing) more \(p.missing == 1 ? "star" : "stars") from \(range) opens the next lesson. Replay one to earn them."
        case .locked:
            return "Opens at \(p.required) stars from \(range)."
        }
    }

    private func accessibilityValue(_ state: LocalState.LessonState) -> String {
        switch state {
        case .done(let stars): "Done, \(stars) of 3 stars"
        case .current: "Up next"
        case .locked: "Locked"
        }
    }
}

struct GateNode: View {
    let state: LocalState.GateState

    var body: some View {
        ZStack {
            Circle().fill(fill)
            switch state {
            case .open:
                Image(systemName: "star.fill").font(TextStyle.headline).foregroundStyle(Palette.onTint)
            case .current:
                Image(systemName: "star").font(TextStyle.headline).foregroundStyle(Palette.onTint)
            case .locked:
                Image(systemName: "lock.fill").font(TextStyle.footnote).foregroundStyle(Palette.textMuted)
            }
        }
        .frame(width: Layout.minTarget, height: Layout.minTarget)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch state {
        case .open: Palette.success
        case .current: Palette.tint
        case .locked: Palette.surfaceSunken
        }
    }
}

struct LessonNode: View {
    let number: Int
    let state: LocalState.LessonState

    var body: some View {
        ZStack {
            Circle().fill(fill)
            switch state {
            case .done:
                Image(systemName: "checkmark").font(TextStyle.headline).foregroundStyle(Palette.onTint)
            case .current:
                Text("\(number)").font(TextStyle.number(.headline)).foregroundStyle(Palette.onTint)
            case .locked:
                Image(systemName: "lock.fill").font(TextStyle.footnote).foregroundStyle(Palette.textMuted)
            }
        }
        .frame(width: Layout.minTarget, height: Layout.minTarget)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch state {
        case .done: Palette.success
        case .current: Palette.tint
        case .locked: Palette.surfaceSunken
        }
    }
}

#Preview {
    NavigationStack { CoursePathView { _ in } }.environment(AppModel.preview(lessonsDone: 2))
}
