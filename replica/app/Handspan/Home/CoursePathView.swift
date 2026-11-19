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
                    Text("\(lesson.minutes) min · \(lesson.exercises.count) exercises")
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
        .accessibilityHint(state == .locked ? "Finish the lessons before it first." : "")
    }

    private func accessibilityValue(_ state: LocalState.LessonState) -> String {
        switch state {
        case .done(let stars): "Done, \(stars) of 3 stars"
        case .current: "Up next"
        case .locked: "Locked"
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
