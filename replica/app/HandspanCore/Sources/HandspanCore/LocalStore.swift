import Foundation

/// Best result per lesson, as in `lesson_progress`. Kept locally so the course map works
/// offline, and rebuilt from the server after sign-in on a new device (/replica-backend).
public struct LessonProgress: Codable, Sendable, Equatable {
    public var bestStars: Int
    public var done: Bool
    public var completedAt: Date?

    public init(bestStars: Int = 0, done: Bool = false, completedAt: Date? = nil) {
        self.bestStars = bestStars
        self.done = done
        self.completedAt = completedAt
    }
}

/// What the learner wants to play (S03). Kept on the device for now; it will steer the
/// path choice after the first course (S08).
public enum Goal: String, Codable, Sendable, CaseIterable {
    case classical, songs, chords, own
}

/// Everything the app keeps on the device between launches.
public struct LocalState: Codable, Sendable, Equatable {
    public var onboarded = false
    public var session: Session?
    public var profile: Profile?
    public var goal: Goal?
    public var progress: [String: LessonProgress] = [:]
    /// Finished attempts not yet confirmed by the server, oldest first.
    public var pendingAttempts: [Attempt] = []
    /// Days (yyyy-MM-dd in the learner's time zone) with at least one finished lesson.
    public var practiceDays: Set<String> = []

    public init() {}

    /// Records an attempt locally. Never lowers a best score (same rule as the server's
    /// `greatest(best_stars)`), and queues the attempt for upload.
    public mutating func record(_ attempt: Attempt, timeZone: TimeZone = .current) {
        var p = progress[attempt.lessonId] ?? LessonProgress()
        p.bestStars = max(p.bestStars, attempt.stars)
        if attempt.stars > 0, !p.done {
            p.done = true
            p.completedAt = attempt.finishedAt
        }
        progress[attempt.lessonId] = p
        if !pendingAttempts.contains(where: { $0.clientAttemptId == attempt.clientAttemptId }) {
            pendingAttempts.append(attempt)
        }
        practiceDays.insert(Self.dayKey(attempt.finishedAt, timeZone: timeZone))
    }

    public mutating func markUploaded(_ ids: Set<UUID>) {
        pendingAttempts.removeAll { ids.contains($0.clientAttemptId) }
    }

    public static func dayKey(_ date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Course path (S09)

    public enum LessonState: Equatable, Sendable { case done(stars: Int), current, locked }

    /// Lessons open in order: the first one not done is current, the rest are locked.
    public func state(of lesson: Lesson, in course: Course) -> LessonState {
        if let p = progress[lesson.id], p.done { return .done(stars: p.bestStars) }
        return nextLesson(in: course)?.id == lesson.id ? .current : .locked
    }

    public func nextLesson(in course: Course) -> Lesson? {
        course.lessons.first { progress[$0.id]?.done != true }
    }

    /// Share of the course's lessons done, 0...1.
    public func completion(of course: Course) -> Double {
        guard !course.lessons.isEmpty else { return 0 }
        let done = course.lessons.filter { progress[$0.id]?.done == true }.count
        return Double(done) / Double(course.lessons.count)
    }
}

/// Saves `LocalState` as one JSON file, written atomically.
public struct LocalStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func standard() throws -> LocalStore {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
        return LocalStore(url: dir.appendingPathComponent("handspan-state.json"))
    }

    public func load() -> LocalState {
        guard let data = try? Data(contentsOf: url) else { return LocalState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(LocalState.self, from: data)) ?? LocalState()
    }

    public func save(_ state: LocalState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: url, options: [.atomic])
    }

    public func erase() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
