import Foundation

// The data layer. Screens talk to `Backend` only. `FakeBackend` keeps everything in
// memory with the same signatures as the Supabase calls in architecture.md, so the real
// one (`SupabaseBackend`) replaces it without touching screen code. The app picks the
// fake when `SupabaseConfig` is empty, and in previews.

public enum InputMode: String, Codable, Sendable { case mic, midi, touch }
public enum Experience: String, Codable, Sendable, CaseIterable { case beginner, some, advanced }
public enum ProfileKind: String, Codable, Sendable { case adult, kid }

public struct Profile: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var kind: ProfileKind
    public var inputMode: InputMode
    public var experience: Experience

    public init(id: UUID = UUID(), name: String, kind: ProfileKind = .adult,
                inputMode: InputMode, experience: Experience) {
        self.id = id
        self.name = name
        self.kind = kind
        self.inputMode = inputMode
        self.experience = experience
    }

    /// profiles.name is 1 to 40 characters.
    public static func validName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...40).contains(name.count) ? name : nil
    }
}

public struct Session: Codable, Sendable, Equatable {
    public let accountId: UUID
    public let email: String

    public init(accountId: UUID, email: String) {
        self.accountId = accountId
        self.email = email
    }
}

/// One finished lesson attempt. Field names follow the `attempts` table.
public struct Attempt: Codable, Sendable, Equatable, Identifiable {
    public let clientAttemptId: UUID
    public let profileId: UUID
    public let lessonId: String
    public let contentVersion: Int
    public let accuracy: Int
    /// 0...100 when the lesson had timed exercises (attempts.timing).
    public let timing: Int?
    public let stars: Int
    public let inputMode: InputMode
    public let tempoPct: Int
    public let hands: String
    public let startedAt: Date
    public let finishedAt: Date

    public var id: UUID { clientAttemptId }

    public init(clientAttemptId: UUID = UUID(), profileId: UUID, lessonId: String, contentVersion: Int,
                accuracy: Int, timing: Int? = nil, stars: Int, inputMode: InputMode, tempoPct: Int = 100,
                hands: String = "right", startedAt: Date, finishedAt: Date) {
        self.clientAttemptId = clientAttemptId
        self.profileId = profileId
        self.lessonId = lessonId
        self.contentVersion = contentVersion
        self.accuracy = accuracy
        self.timing = timing
        self.stars = stars
        self.inputMode = inputMode
        self.tempoPct = tempoPct
        self.hands = hands
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public enum AuthError: Error, Equatable, Sendable {
    case invalidEmail, wrongCode, expiredCode, tooManyTries, offline
}

public protocol Backend: Sendable {
    /// auth.signInWithOtp: sends a 6-digit code.
    func sendCode(to email: String) async throws
    /// auth.verifyOtp
    func verify(email: String, code: String) async throws -> Session
    /// The account's first learner profile, if it already has one (a reinstall or a
    /// second device). nil for a new account.
    func existingProfile(session: Session) async throws -> Profile?
    func createProfile(_ profile: Profile, session: Session) async throws -> Profile
    /// lesson_progress for one profile, keyed by lesson id. Rebuilds the course map on
    /// a new device.
    func lessonProgress(profileId: UUID, session: Session) async throws -> [String: LessonProgress]
    /// rpc record_attempts: returns how many were new. Replays are ignored.
    func recordAttempts(_ attempts: [Attempt], session: Session) async throws -> Int
    /// functions/v1/delete-account
    func deleteAccount(session: Session) async throws
}

public enum EmailRule {
    public static func isPlausible(_ raw: String) -> Bool {
        let email = raw.trimmingCharacters(in: .whitespaces)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix("."), !email.contains(" ") else { return false }
        return true
    }
}

/// In-memory stand-in for Supabase. For the simulator and tests only.
/// Any 6-digit code works except `000000` (wrong) and `999999` (expired), so every
/// sign-in state can be seen.
public actor FakeBackend: Backend {
    public private(set) var codesSent: [String] = []
    public private(set) var profiles: [UUID: Profile] = [:]
    public private(set) var attempts: [UUID: Attempt] = [:]
    public private(set) var deletedAccounts: Set<UUID> = []
    public var isOffline = false
    private var accounts: [String: UUID] = [:]
    private var profileOwners: [UUID: UUID] = [:]
    private var wrongTries = 0

    public init() {}

    public func setOffline(_ offline: Bool) { isOffline = offline }

    public func sendCode(to email: String) async throws {
        guard !isOffline else { throw AuthError.offline }
        guard EmailRule.isPlausible(email) else { throw AuthError.invalidEmail }
        codesSent.append(email.lowercased())
        wrongTries = 0
    }

    public func verify(email: String, code: String) async throws -> Session {
        guard !isOffline else { throw AuthError.offline }
        guard wrongTries < 5 else { throw AuthError.tooManyTries }
        guard code.count == 6, code.allSatisfy(\.isNumber), code != "000000" else {
            wrongTries += 1
            throw AuthError.wrongCode
        }
        if code == "999999" { throw AuthError.expiredCode }
        let key = email.lowercased()
        let id = accounts[key] ?? UUID()
        accounts[key] = id
        return Session(accountId: id, email: key)
    }

    public func existingProfile(session: Session) async throws -> Profile? {
        guard !isOffline else { throw AuthError.offline }
        return profileOwners.first { $0.value == session.accountId }.flatMap { profiles[$0.key] }
    }

    public func createProfile(_ profile: Profile, session: Session) async throws -> Profile {
        guard !isOffline else { throw AuthError.offline }
        // Same rule as the profiles_cap trigger: one profile without a plan.
        guard !profileOwners.values.contains(session.accountId) else { throw BackendError.profileLimitReached }
        profiles[profile.id] = profile
        profileOwners[profile.id] = session.accountId
        return profile
    }

    public func lessonProgress(profileId: UUID, session: Session) async throws -> [String: LessonProgress] {
        guard !isOffline else { throw AuthError.offline }
        guard profileOwners[profileId] == session.accountId else { return [:] }
        var out: [String: LessonProgress] = [:]
        for a in attempts.values where a.profileId == profileId {
            var p = out[a.lessonId] ?? LessonProgress()
            p.bestStars = max(p.bestStars, a.stars)
            if a.stars > 0, !p.done { p.done = true; p.completedAt = a.finishedAt }
            out[a.lessonId] = p
        }
        return out
    }

    public func recordAttempts(_ batch: [Attempt], session: Session) async throws -> Int {
        guard !isOffline else { throw AuthError.offline }
        var inserted = 0
        for a in batch where attempts[a.clientAttemptId] == nil {
            attempts[a.clientAttemptId] = a
            inserted += 1
        }
        return inserted
    }

    public func deleteAccount(session: Session) async throws {
        guard !isOffline else { throw AuthError.offline }
        deletedAccounts.insert(session.accountId)
        for (pid, owner) in profileOwners where owner == session.accountId {
            profileOwners[pid] = nil
            profiles[pid] = nil
            attempts = attempts.filter { $0.value.profileId != pid }
        }
        accounts = accounts.filter { $0.value != session.accountId }
    }
}
