import Foundation
import HandspanCore
import Observation

/// App-wide state: the local store, the data layer and the course. Screens read from
/// here and call its methods; none of them talk to the backend directly.
@MainActor @Observable
final class AppModel {
    enum SyncStatus: Equatable { case synced, pending, offline }

    let backend: any Backend
    private let store: LocalStore?
    let course: Course

    private(set) var state: LocalState
    private(set) var syncStatus: SyncStatus = .synced

    /// Answers collected during onboarding, saved once the profile exists.
    var draftInputMode: InputMode = .mic
    var draftExperience: Experience = .beginner
    var draftGoal: Goal?

    init(backend: any Backend, store: LocalStore?, course: Course) {
        self.backend = backend
        self.store = store
        self.course = course
        self.state = store?.load() ?? LocalState()
        syncStatus = state.pendingAttempts.isEmpty ? .synced : .pending
    }

    /// The real app. The backend is the in-memory fake until /replica-backend lands.
    static func live() -> AppModel {
        let course: Course
        do { course = try SeedContent.firstCourse() } catch {
            fatalError("The bundled first course is missing or broken: \(error)")
        }
        return AppModel(backend: FakeBackend(), store: try? LocalStore.standard(), course: course)
    }

    /// For SwiftUI previews: nothing touches the disk.
    static func preview(onboarded: Bool = true, lessonsDone: Int = 1) -> AppModel {
        let model = AppModel(backend: FakeBackend(), store: nil, course: (try? SeedContent.firstCourse())!)
        if onboarded {
            model.state.onboarded = true
            model.state.profile = Profile(name: "Ana", inputMode: .mic, experience: .beginner)
            model.state.session = Session(accountId: UUID(), email: "ana@example.com")
            for lesson in model.course.lessons.prefix(lessonsDone) {
                model.state.record(Attempt(profileId: model.state.profile!.id, lessonId: lesson.id,
                                           contentVersion: 1, accuracy: 92, stars: 3, inputMode: .mic,
                                           startedAt: .now.addingTimeInterval(-400), finishedAt: .now))
            }
            model.state.pendingAttempts = []
        }
        return model
    }

    private func save() {
        do { try store?.save(state) } catch {
            // The next successful save writes everything again; nothing is lost in memory.
            print("Handspan: could not save local state: \(error)")
        }
    }

    // MARK: Onboarding

    var inputMode: InputMode { state.profile?.inputMode ?? draftInputMode }

    func finishOnboarding(session: Session, name: String) async throws {
        let profile = Profile(name: name, inputMode: draftInputMode, experience: draftExperience)
        let saved = try await backend.createProfile(profile, session: session)
        state.session = session
        state.profile = saved
        state.goal = draftGoal
        state.onboarded = true
        save()
    }

    func setInputMode(_ mode: InputMode) {
        draftInputMode = mode
        if state.profile != nil {
            state.profile?.inputMode = mode
            save()
        }
    }

    // MARK: Lessons

    var nextLesson: Lesson? { state.nextLesson(in: course) }

    func lessonNumber(_ lesson: Lesson) -> Int {
        (course.lessons.firstIndex(of: lesson) ?? 0) + 1
    }

    /// Saves a finished lesson locally first, then tries to upload. Never loses an attempt.
    @discardableResult
    func record(_ result: LessonResult, lesson: Lesson, startedAt: Date) -> Attempt? {
        guard let profile = state.profile else { return nil }
        let attempt = Attempt(profileId: profile.id, lessonId: lesson.id,
                              contentVersion: course.contentVersion, accuracy: result.accuracy,
                              stars: result.stars, inputMode: profile.inputMode,
                              startedAt: startedAt, finishedAt: .now)
        state.record(attempt)
        syncStatus = .pending
        save()
        Task { await sync() }
        return attempt
    }

    func sync() async {
        guard let session = state.session, !state.pendingAttempts.isEmpty else {
            syncStatus = state.pendingAttempts.isEmpty ? .synced : syncStatus
            return
        }
        let batch = state.pendingAttempts
        do {
            _ = try await backend.recordAttempts(batch, session: session)
            state.markUploaded(Set(batch.map(\.clientAttemptId)))
            syncStatus = state.pendingAttempts.isEmpty ? .synced : .pending
            save()
        } catch {
            syncStatus = .offline
        }
    }

    // MARK: Account

    /// Deletes the account on the server, then everything on this device.
    func deleteAccount() async throws {
        if let session = state.session {
            try await backend.deleteAccount(session: session)
        }
        try? store?.erase()
        state = LocalState()
        draftInputMode = .mic
        draftExperience = .beginner
        draftGoal = nil
        syncStatus = .synced
    }
}
