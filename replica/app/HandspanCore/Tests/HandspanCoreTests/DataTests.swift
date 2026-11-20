import Foundation
import Testing
@testable import HandspanCore

private let t0 = Date(timeIntervalSince1970: 1_763_000_000)   // whole seconds: survives ISO 8601

private func attempt(lesson: String, stars: Int, profile: UUID = UUID(), at: Date = t0) -> Attempt {
    Attempt(profileId: profile, lessonId: lesson, contentVersion: 1, accuracy: stars * 30,
            stars: stars, inputMode: .mic, startedAt: at.addingTimeInterval(-300), finishedAt: at)
}

@Suite struct BackendTests {
    @Test func signInStates() async throws {
        let backend = FakeBackend()
        await #expect(throws: AuthError.invalidEmail) { try await backend.sendCode(to: "not-an-email") }
        try await backend.sendCode(to: "Ana@Example.com")
        await #expect(throws: AuthError.wrongCode) { _ = try await backend.verify(email: "ana@example.com", code: "000000") }
        await #expect(throws: AuthError.wrongCode) { _ = try await backend.verify(email: "ana@example.com", code: "12345") }
        await #expect(throws: AuthError.expiredCode) { _ = try await backend.verify(email: "ana@example.com", code: "999999") }
        let a = try await backend.verify(email: "ana@example.com", code: "482913")
        let b = try await backend.verify(email: "ANA@example.com", code: "111111")
        #expect(a.accountId == b.accountId)
        #expect(a.email == "ana@example.com")
    }

    @Test func tooManyWrongCodes() async throws {
        let backend = FakeBackend()
        try await backend.sendCode(to: "a@b.co")
        for _ in 0..<5 { _ = try? await backend.verify(email: "a@b.co", code: "000000") }
        await #expect(throws: AuthError.tooManyTries) { _ = try await backend.verify(email: "a@b.co", code: "123456") }
        try await backend.sendCode(to: "a@b.co")   // a new code resets the count
        _ = try await backend.verify(email: "a@b.co", code: "123456")
    }

    @Test func recordAttemptsIsIdempotent() async throws {
        let backend = FakeBackend()
        let session = try await backend.verify(email: "a@b.co", code: "123456")
        let batch = [attempt(lesson: "x", stars: 3), attempt(lesson: "y", stars: 1)]
        #expect(try await backend.recordAttempts(batch, session: session) == 2)
        #expect(try await backend.recordAttempts(batch, session: session) == 0)
    }

    @Test func offline() async throws {
        let backend = FakeBackend()
        await backend.setOffline(true)
        await #expect(throws: AuthError.offline) { try await backend.sendCode(to: "a@b.co") }
    }

    @Test func emailRule() {
        #expect(EmailRule.isPlausible("a@b.co"))
        #expect(EmailRule.isPlausible(" ana.k@mail.example.hr "))
        for bad in ["", "a", "a@", "@b.co", "a@b", "a@.co", "a@b.", "a b@c.co", "a@b@c.co"] {
            #expect(!EmailRule.isPlausible(bad), "\(bad)")
        }
    }

    @Test func profileNames() {
        #expect(Profile.validName("  Ana ") == "Ana")
        #expect(Profile.validName("   ") == nil)
        #expect(Profile.validName(String(repeating: "x", count: 40)) != nil)
        #expect(Profile.validName(String(repeating: "x", count: 41)) == nil)
    }
}

@Suite struct LocalStateTests {
    let course: Course

    init() throws { course = try SeedContent.firstCourse() }

    @Test func pathUnlocksInOrder() {
        var state = LocalState()
        let l = course.lessons
        #expect(state.state(of: l[0], in: course) == .current)
        #expect(state.state(of: l[1], in: course) == .locked)
        state.record(attempt(lesson: l[0].id, stars: 2))
        #expect(state.state(of: l[0], in: course) == .done(stars: 2))
        #expect(state.state(of: l[1], in: course) == .current)
        #expect(state.nextLesson(in: course)?.id == l[1].id)
        #expect(abs(state.completion(of: course) - 1.0 / Double(l.count)) < 1e-9)
    }

    @Test func zeroStarsIsNotDone() {
        var state = LocalState()
        state.record(attempt(lesson: course.lessons[0].id, stars: 0))
        #expect(state.state(of: course.lessons[0], in: course) == .current)
        #expect(state.pendingAttempts.count == 1)   // practice still counts and still syncs
    }

    @Test func bestStarsNeverDrop() {
        var state = LocalState()
        let id = course.lessons[0].id
        state.record(attempt(lesson: id, stars: 3))
        state.record(attempt(lesson: id, stars: 1))
        #expect(state.progress[id]?.bestStars == 3)
    }

    @Test func pendingQueueDedupesAndClears() {
        var state = LocalState()
        let a = attempt(lesson: "x", stars: 1)
        state.record(a)
        state.record(a)
        #expect(state.pendingAttempts.count == 1)
        state.markUploaded([a.clientAttemptId])
        #expect(state.pendingAttempts.isEmpty)
    }

    @Test func practiceDaysUseTheLearnersTimeZone() throws {
        var state = LocalState()
        // 2025-11-13 02:13 UTC is still Nov 12 in New York.
        state.record(attempt(lesson: "x", stars: 1), timeZone: try #require(TimeZone(identifier: "America/New_York")))
        #expect(state.practiceDays == ["2025-11-12"])
    }

    @Test func storeRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hs-\(UUID().uuidString).json")
        let store = LocalStore(url: url)
        #expect(store.load() == LocalState())          // nothing saved yet
        var state = LocalState()
        state.onboarded = true
        state.session = Session(accountId: UUID(), email: "a@b.co")
        state.profile = Profile(name: "Ana", inputMode: .mic, experience: .beginner)
        state.record(attempt(lesson: course.lessons[0].id, stars: 3))
        try store.save(state)
        #expect(store.load() == state)
        try store.erase()
        #expect(store.load() == LocalState())
    }
}

@Suite struct StarGateTests {
    let course: Course

    init() throws { course = try SeedContent.firstCourse() }

    private var gate: StarGate { course.gates[0] }
    private var song: Lesson { course.lessons.last! }
    private var beforeSong: [Lesson] { Array(course.lessons.dropLast()) }

    @Test func firstCourseHasOneGateBeforeTheSong() throws {
        #expect(course.gates.count == 1)
        #expect(gate.before == song.id)
        #expect(song.kind == .song)
        #expect(course.lessons(countingToward: gate).map(\.id) == beforeSong.map(\.id))
        // Reachable, and not a formality: more than one star per lesson, less than three.
        let most = beforeSong.count * 3
        #expect(gate.starsRequired > beforeSong.count && gate.starsRequired < most)
        #expect(course.gates.allSatisfy { UUID(uuidString: $0.id) != nil })
    }

    @Test func gateLockedUntilTheLessonsBeforeItAreDone() {
        var state = LocalState()
        #expect(state.state(of: gate, in: course) == .locked(.init(earned: 0, required: gate.starsRequired)))
        state.record(attempt(lesson: beforeSong[0].id, stars: 3))
        if case .locked(let p) = state.state(of: gate, in: course) { #expect(p.earned == 3) } else { Issue.record("expected locked") }
        #expect(state.state(of: song, in: course) == .locked)
    }

    @Test func shortOfStarsNamesTheLessonToReplay() {
        var state = LocalState()
        for (i, lesson) in beforeSong.enumerated() {
            state.record(attempt(lesson: lesson.id, stars: i == 2 ? 1 : 2))   // 2+2+1+2+2 = 9
        }
        let p = state.progress(of: gate, in: course)
        #expect(p.earned == 9 && !p.isOpen && p.missing == 1)
        #expect(state.state(of: gate, in: course) == .current(p))
        #expect(state.nextLesson(in: course) == nil)
        #expect(state.state(of: song, in: course) == .locked)
        #expect(state.nextStep(in: course) == .gate(gate, p, replay: beforeSong[2]))   // the 1-star lesson
    }

    @Test func replayingOpensTheGate() {
        var state = LocalState()
        for lesson in beforeSong { state.record(attempt(lesson: lesson.id, stars: 2)) }
        if gate.starsRequired > beforeSong.count * 2 {
            state.record(attempt(lesson: beforeSong[0].id, stars: 3))
        }
        #expect(state.progress(of: gate, in: course).isOpen)
        #expect(state.state(of: gate, in: course) == .open)
        #expect(state.nextLesson(in: course)?.id == song.id)
        #expect(state.state(of: song, in: course) == .current)
        #expect(state.nextStep(in: course) == .lesson(song))
        state.record(attempt(lesson: song.id, stars: 1))
        #expect(state.nextStep(in: course) == .finished)
    }

    @Test func tiesReplayTheEarliestLesson() {
        var state = LocalState()
        for lesson in beforeSong { state.record(attempt(lesson: lesson.id, stars: 1)) }
        guard case .gate(_, _, let replay) = state.nextStep(in: course) else { Issue.record("expected a gate"); return }
        #expect(replay.id == beforeSong[0].id)
    }

    @Test func contentWithoutGatesStillDecodes() throws {
        let data = try JSONEncoder().encode(course)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("the course didn't encode to a JSON object")
            return
        }
        object.removeValue(forKey: "gates")
        let old = try JSONDecoder().decode(Course.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.gates.isEmpty)
        var state = LocalState()
        for lesson in old.lessons.dropLast() { state.record(attempt(lesson: lesson.id, stars: 1)) }
        #expect(state.nextLesson(in: old)?.id == old.lessons.last?.id)   // no gate in the way
    }

    @Test func gatesRoundTrip() throws {
        let again = try JSONDecoder().decode(Course.self, from: JSONEncoder().encode(course))
        #expect(again == course)
    }

    @Test func comingSoonCourses() throws {
        let soon = try SeedContent.comingSoon()
        #expect(!soon.isEmpty)
        #expect(soon.allSatisfy { UUID(uuidString: $0.id) != nil && $0.id != course.id })
        #expect(Set(soon.map(\.id)).count == soon.count)
    }
}
