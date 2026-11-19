import SwiftUI
import HandspanCore

/// S07: today's lesson, the course, the practice week.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var activeLesson: Lesson?
    @State private var showSettings = false
    @State private var showPath = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Layout.stackGap) {
                    ScreenHeader(title: greeting, subtitle: Date.now.formatted(.dateTime.weekday(.wide).month().day())) {
                        GlassIconButton(systemImage: "gearshape", label: "Settings") { showSettings = true }
                    }
                    .padding(.horizontal, -Layout.screenMargin)

                    if model.syncStatus == .offline {
                        SyncBanner()
                    }

                    if let lesson = model.nextLesson {
                        FocusCard(
                            courseTitle: model.course.title,
                            courseProgress: model.state.completion(of: model.course),
                            eyebrow: "Lesson \(model.lessonNumber(lesson)) of \(model.course.lessons.count)",
                            title: lesson.title,
                            summary: lesson.summary,
                            duration: "\(lesson.minutes) min",
                            upNext: model.course.lesson(after: lesson.id)?.title ?? "The end of the course",
                            start: { activeLesson = lesson }
                        )
                    } else {
                        CourseDoneCard()
                    }

                    Button {
                        showPath = true
                    } label: {
                        HStack {
                            Label("All lessons in \(model.course.title)", systemImage: "list.bullet")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.textMuted)
                        }
                        .font(TextStyle.headline)
                        .foregroundStyle(Palette.text)
                        .padding(Layout.cardPadding)
                        .frame(minHeight: Layout.minTarget)
                        .frostedCard(radius: Radius.inner)
                    }
                    .buttonStyle(.plain)

                    WeekStrip(label: "This week", range: weekRange, days: weekDays)
                }
                .padding(.horizontal, Layout.screenMargin)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: Layout.maxReadableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(SkyBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPath) {
                CoursePathView { activeLesson = $0 }
            }
        }
        .fullScreenCover(item: $activeLesson) { lesson in
            LessonFlowView(lesson: lesson)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var greeting: String {
        if let name = model.state.profile?.name { "Hi, \(name)" } else { "Today" }
    }

    // MARK: Week strip

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // weeks start on Monday, like the streak (S19)
        return c
    }

    private var weekDates: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekDays: [WeekDay] {
        weekDates.map { date in
            WeekDay(letter: String(date.formatted(.dateTime.weekday(.narrow))),
                    number: calendar.component(.day, from: date),
                    practised: model.state.practiceDays.contains(LocalState.dayKey(date, timeZone: .current)),
                    isToday: calendar.isDateInToday(date))
        }
    }

    private var weekRange: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        return (first..<last).formatted(.interval.month(.abbreviated).day())
    }
}

/// Shown when uploads fail. Nothing is lost: attempts wait on the device (string 13).
struct SyncBanner: View {
    var body: some View {
        Label("No connection. Your practice is saved on this \(DeviceWord.current) and will sync later.",
              systemImage: "icloud.slash")
            .font(TextStyle.subheadline)
            .foregroundStyle(Palette.text)
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frostedCard(radius: Radius.chip)
    }
}

struct CourseDoneCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Palette.success)
                .accessibilityHidden(true)
            Text("\(model.course.title) is done").font(TextStyle.titleStrong).foregroundStyle(Palette.text)
            Text("Every lesson finished. The next course, with the left hand, is on its way.")
                .font(TextStyle.subheadline).foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
    }
}

#Preview { HomeView().environment(AppModel.preview()).environment(AudioInput()) }
