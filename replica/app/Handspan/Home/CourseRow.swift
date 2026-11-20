import SwiftUI
import HandspanCore

/// S07, the course map: every course with its progress. The course in hand opens its
/// lesson path (S09); announced courses show what comes after it.
struct CourseRow: View {
    @Environment(AppModel.self) private var model
    var openCourse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Courses")
                .font(TextStyle.headline)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Space.md) {
                    Button(action: openCourse) {
                        CourseCard(title: model.course.title,
                                   detail: progressLine,
                                   progress: model.state.completion(of: model.course),
                                   badge: model.course.isFree ? "Free" : nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows every lesson in the course.")

                    ForEach(model.comingSoon) { course in
                        CourseCard(title: course.title, detail: course.summary,
                                   progress: nil, badge: "Coming soon")
                    }
                }
                .padding(.vertical, Space.xxs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var progressLine: String {
        let total = model.course.lessons.count
        let done = model.course.lessons.filter { model.state.progress[$0.id]?.done == true }.count
        return done == total ? "All \(total) lessons done" : "\(done) of \(total) lessons done"
    }
}

/// One course on the course map.
struct CourseCard: View {
    let title: String
    let detail: String
    /// Share of lessons done, 0...1. Nil for a course that has no lessons yet.
    let progress: Double?
    let badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top) {
                if let progress {
                    ProgressRing(value: progress, caption: "", size: 32, lineWidth: 3,
                                 foreground: Palette.tint, showsLabel: false)
                } else {
                    Image(systemName: "hourglass")
                        .font(TextStyle.headline)
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 32, height: 32)
                }
                Spacer(minLength: Space.sm)
                if let badge {
                    Text(badge)
                        .font(TextStyle.caption)
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, Space.xxs)
                        .background(Capsule().fill(Palette.surfaceSunken))
                }
            }
            Text(title).font(TextStyle.headline).foregroundStyle(Palette.text)
            Text(detail)
                .font(TextStyle.footnote)
                .foregroundStyle(Palette.textMuted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .frame(width: 220, alignment: .topLeading)
        .frame(minHeight: 150, alignment: .topLeading)
        .frostedCard(radius: Radius.inner)
        .accessibilityElement(children: .combine)
        .accessibilityValue(progress.map { "\(Int(($0 * 100).rounded())) percent done" } ?? "")
    }
}

#Preview {
    CourseRow(openCourse: {}).padding().environment(AppModel.preview(lessonsDone: 3))
}
