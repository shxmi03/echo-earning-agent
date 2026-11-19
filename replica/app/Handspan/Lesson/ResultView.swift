import SwiftUI
import HandspanCore

/// S14: stars, the plain-numbers sentence, and what to do next.
/// Never "Fail" (components.md); 0 stars reads "Almost" and names the tricky note.
struct ResultView: View {
    let lesson: Lesson
    let result: LessonResult
    let next: Lesson?
    var tryAgain: () -> Void
    var close: () -> Void

    var body: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            StarRow(earned: result.stars, size: Space.xxxl)
            VStack(spacing: Space.sm) {
                Text(result.passed ? "\(lesson.title): done" : lesson.title)
                    .font(TextStyle.title3)
                    .foregroundStyle(Palette.textMuted)
                Text(result.headline)
                    .font(TextStyle.titleStrong)
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            AccuracyBar(accuracy: result.accuracy)
            if result.passed, let next {
                Text("Next: \(next.title)")
                    .font(TextStyle.subheadline)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            VStack(spacing: Space.sm) {
                if result.passed {
                    Button("Continue", action: close)
                        .buttonStyle(.primaryStyle(fullWidth: true))
                    Button("Try again", action: tryAgain)
                        .buttonStyle(.glass)
                        .frame(minHeight: Layout.minTarget)
                } else {
                    Button("Try again", action: tryAgain)
                        .buttonStyle(.primaryStyle(fullWidth: true))
                    Button("Back to the course", action: close)
                        .buttonStyle(.glass)
                        .frame(minHeight: Layout.minTarget)
                }
            }
        }
        .padding(.horizontal, Layout.screenMargin + Space.xs)
        .padding(.bottom, Space.sm)
        .frame(maxWidth: Layout.maxReadableWidth)
        .frame(maxWidth: .infinity)
    }
}

struct AccuracyBar: View {
    let accuracy: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text("Right the first time")
                Spacer()
                Text("\(accuracy)%").monospacedDigit()
            }
            .font(TextStyle.subheadline)
            .foregroundStyle(Palette.text)
            ProgressView(value: Double(accuracy), total: 100)
                .tint(Palette.success)
        }
        .padding(Layout.cardPadding)
        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.surface))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Passed") {
    ResultView(lesson: try! SeedContent.firstCourse().lessons[1],
               result: LessonResult(results: [ExerciseResult(exerciseIndex: 0, total: 10, firstTryHits: 9, missedPitches: [Pitch(62)])]),
               next: nil, tryAgain: {}, close: {})
}

#Preview("Not yet") {
    ResultView(lesson: try! SeedContent.firstCourse().lessons[1],
               result: LessonResult(results: [ExerciseResult(exerciseIndex: 0, total: 10, firstTryHits: 2, missedPitches: [Pitch(64), Pitch(64)])]),
               next: nil, tryAgain: {}, close: {})
}
