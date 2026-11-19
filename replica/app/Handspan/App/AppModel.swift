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

    /// The real app: Supabase when `SupabaseSettings` is filled in, else the in-memory fake.
    static func live() -> AppModel {
        let course: Course
        do { course = try SeedContent.firstCourse() } catch {
            fatalError("The bundled first course is missing or broken: \(error)")
        }
        let backend: any Backend
        if let config = SupabaseSettings.config {
            backend = SupabaseBackend(config: config, tokenStore: KeychainTokenStore())
        } else {
            backend = FakeBackend()
        }
        return AppModel(backend: backend, store: try? LocalStore.standard(), course: course)
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

    /// Right after the code is accepted. An account that already has a profile (a
    /// reinstall, a second device, "I already have an account") is restored with its
    /// progress and skips the name step: returns true. A new account returns false.
    func restoreAccount(session: Session) async throws -> Bool {
        guard let profile = try await backend.existingProfile(session: session) else { return false }
        let remote = (try? await backend.lessonProgress(profileId: profile.id, session: session)) ?? [:]
        // Keep the better of each lesson, the same rule as the server's greatest(best_stars).
        for (lessonId, theirs) in remote {
            var mine = state.progress[lessonId] ?? LessonProgress()
            mine.bestStars = max(mine.bestStars, theirs.bestStars)
            if theirs.done, !mine.done { mine.done = true; mine.completedAt = theirs.completedAt }
            state.progress[lessonId] = mine
        }
        state.session = session
        state.profile = profile
        if state.goal == nil { state.goal = draftGoal }
        state.onboarded = true
        save()
        Task { await sync() }
        return true
    }

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
                              timing: result.timing, stars: result.stars, inputMode: profile.inputMode,
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

    /// A verified StoreKit transaction, for the server's own check. Failing here is fine:
    /// StoreKit keeps the entitlement on the device, and the next purchase, restore or
    /// App Store notification brings the server up to date.
    func syncSubscription(_ signedTransaction: String) async {
        guard let session = state.session else { return }
        try? await backend.syncSubscription(signedTransaction: signedTransaction, session: session)
    }

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
