import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The real data layer: Supabase Auth (email one-time code), PostgREST under row level
// security, the record_attempts RPC and the delete-account edge function. Plain
// URLSession, no SDK: the app only needs a handful of calls, and this keeps the package
// free of dependencies. Schema and functions: replica/supabase/.

/// The project URL and its publishable key. Both are public by design (they ship inside
/// the app); row level security is what protects the data.
public struct SupabaseConfig: Sendable, Equatable {
    public let url: URL
    public let publishableKey: String

    public init(url: URL, publishableKey: String) {
        self.url = url
        self.publishableKey = publishableKey
    }
}

/// What a signed-in device holds. Kept in the Keychain by the app, never in the
/// JSON local store.
public struct AuthTokens: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var userId: UUID
    public var email: String

    public init(accessToken: String, refreshToken: String, expiresAt: Date, userId: UUID, email: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userId = userId
        self.email = email
    }
}

public protocol TokenStore: Sendable {
    func load() -> AuthTokens?
    func save(_ tokens: AuthTokens?)
}

/// For tests and previews.
public final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: AuthTokens?

    public init(_ tokens: AuthTokens? = nil) { self.tokens = tokens }
    public func load() -> AuthTokens? { lock.withLock { tokens } }
    public func save(_ tokens: AuthTokens?) { lock.withLock { self.tokens = tokens } }
}

/// One HTTP round trip. URLSession in the app, a script in the tests.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Failures that aren't about the sign-in code itself.
public enum BackendError: Error, Equatable, Sendable {
    case notSignedIn
    case profileLimitReached
    case server(status: Int, code: String?)
}

public actor SupabaseBackend: Backend {
    private let config: SupabaseConfig
    private let tokenStore: any TokenStore
    private let http: any HTTPTransport
    private let now: @Sendable () -> Date
    private var tokens: AuthTokens?

    // Supabase answers "otp_expired" for a wrong code and an old one alike, so the
    // difference is worked out here: codes live 10 minutes (supabase/config.toml).
    private var codeSentAt: Date?
    private var wrongTries = 0
    static let codeLifetime: TimeInterval = 600
    static let maxWrongTries = 5

    public init(config: SupabaseConfig, tokenStore: any TokenStore, http: any HTTPTransport = URLSession.shared,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.tokenStore = tokenStore
        self.http = http
        self.now = now
        self.tokens = tokenStore.load()
    }

    // MARK: Auth

    public func sendCode(to email: String) async throws {
        let email = Self.normalise(email)
        guard EmailRule.isPlausible(email) else { throw AuthError.invalidEmail }
        struct OTPBody: Encodable { let email: String; let create_user: Bool }
        let (data, response) = try await perform(path: "auth/v1/otp", body: OTPBody(email: email, create_user: true))
        switch response.statusCode {
        case 200..<300:
            codeSentAt = now()
            wrongTries = 0
        case 429: throw AuthError.tooManyTries
        case 400, 422: throw AuthError.invalidEmail
        default: throw Self.serverError(response, data)
        }
    }

    public func verify(email: String, code: String) async throws -> Session {
        let email = Self.normalise(email)
        guard wrongTries < Self.maxWrongTries else { throw AuthError.tooManyTries }
        guard code.count == 6, code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else {
            wrongTries += 1
            throw AuthError.wrongCode
        }
        let (data, response) = try await perform(path: "auth/v1/verify",
                                                 body: ["type": "email", "email": email, "token": code])
        switch response.statusCode {
        case 200..<300:
            let t = try Self.decodeTokens(data, now: now())
            store(t)
            codeSentAt = nil
            wrongTries = 0
            return Session(accountId: t.userId, email: t.email)
        case 429:
            throw AuthError.tooManyTries
        case 400, 401, 403:
            if let sent = codeSentAt, now().timeIntervalSince(sent) > Self.codeLifetime {
                throw AuthError.expiredCode
            }
            wrongTries += 1
            throw wrongTries >= Self.maxWrongTries ? AuthError.tooManyTries : AuthError.wrongCode
        default:
            throw Self.serverError(response, data)
        }
    }

    /// Forgets the tokens on this device. The refresh token is revoked on the server too
    /// when the network allows; signing out never fails because of that.
    public func signOut() async {
        if let t = tokens {
            _ = try? await perform(path: "auth/v1/logout", body: [String: String](), bearer: t.accessToken)
        }
        store(nil)
    }

    // MARK: Data

    public func existingProfile(session: Session) async throws -> Profile? {
        let data = try await authed(get: "rest/v1/profiles",
                                    query: [("select", "id,name,kind,input_mode,experience"),
                                            ("order", "created_at.asc"), ("limit", "1")],
                                    session: session)
        return try JSONDecoder().decode([ProfileRow].self, from: data).first?.profile
    }

    public func createProfile(_ profile: Profile, session: Session) async throws -> Profile {
        let row: [String: String] = [
            "id": profile.id.uuidString.lowercased(),
            "account_id": session.accountId.uuidString.lowercased(),
            "name": profile.name,
            "kind": profile.kind.rawValue,
            "input_mode": profile.inputMode.rawValue,
            "experience": profile.experience.rawValue,
        ]
        do {
            _ = try await authed(post: "rest/v1/profiles", body: row, session: session,
                                 headers: ["Prefer": "return=minimal"])
        } catch BackendError.server(_, let code) where code == "profile_limit_reached" {
            throw BackendError.profileLimitReached
        }
        return profile
    }

    public func lessonProgress(profileId: UUID, session: Session) async throws -> [String: LessonProgress] {
        let data = try await authed(get: "rest/v1/lesson_progress",
                                    query: [("select", "lesson_id,best_stars,status,completed_at"),
                                            ("profile_id", "eq.\(profileId.uuidString.lowercased())")],
                                    session: session)
        var out: [String: LessonProgress] = [:]
        for row in try JSONDecoder().decode([ProgressRow].self, from: data) {
            out[row.lesson_id.lowercased()] = LessonProgress(
                bestStars: row.best_stars, done: row.status == "done",
                completedAt: row.completed_at.flatMap(Self.parseDate))
        }
        return out
    }

    public func recordAttempts(_ attempts: [Attempt], session: Session) async throws -> Int {
        var inserted = 0
        // The RPC takes at most 200 per call.
        for start in stride(from: 0, to: attempts.count, by: 200) {
            let chunk = attempts[start..<min(start + 200, attempts.count)]
            let body = RecordAttemptsBody(batch: chunk.map(AttemptRow.init), tz: TimeZone.current.identifier)
            let data = try await authed(post: "rest/v1/rpc/record_attempts", body: body, session: session)
            inserted += try JSONDecoder().decode(Int.self, from: data)
        }
        return inserted
    }

    public func deleteAccount(session: Session) async throws {
        _ = try await authed(post: "functions/v1/delete-account", body: [String: String](), session: session)
        store(nil)
    }

    // MARK: Plumbing

    private func store(_ t: AuthTokens?) {
        tokens = t
        tokenStore.save(t)
    }

    /// A fresh access token for this session, refreshed a minute before it runs out.
    private func accessToken(for session: Session, forceRefresh: Bool = false) async throws -> String {
        guard var t = tokens, t.userId == session.accountId else { throw BackendError.notSignedIn }
        if forceRefresh || t.expiresAt.timeIntervalSince(now()) < 60 {
            let (data, response) = try await perform(path: "auth/v1/token", query: [("grant_type", "refresh_token")],
                                                     body: ["refresh_token": t.refreshToken])
            guard (200..<300).contains(response.statusCode) else {
                if (400..<500).contains(response.statusCode) {
                    store(nil)          // refresh token revoked or used up: sign in again
                    throw BackendError.notSignedIn
                }
                throw Self.serverError(response, data)
            }
            t = try Self.decodeTokens(data, now: now())
            store(t)
        }
        return t.accessToken
    }

    private func authed(get path: String, query: [(String, String)], session: Session) async throws -> Data {
        try await authed(path: path, method: "GET", query: query, body: nil, session: session, headers: [:])
    }

    private func authed<B: Encodable>(post path: String, body: B, session: Session,
                                      headers: [String: String] = [:]) async throws -> Data {
        try await authed(path: path, method: "POST", query: [], body: try JSONEncoder().encode(body),
                         session: session, headers: headers)
    }

    /// Signed-in call; on a 401 refreshes once and tries again.
    private func authed(path: String, method: String, query: [(String, String)], body: Data?,
                        session: Session, headers: [String: String]) async throws -> Data {
        var token = try await accessToken(for: session)
        for attempt in 0..<2 {
            let (data, response) = try await perform(path: path, method: method, query: query, rawBody: body,
                                                     bearer: token, headers: headers)
            if response.statusCode == 401, attempt == 0 {
                token = try await accessToken(for: session, forceRefresh: true)
                continue
            }
            guard (200..<300).contains(response.statusCode) else { throw Self.serverError(response, data) }
            return data
        }
        throw BackendError.notSignedIn
    }

    private func perform<B: Encodable>(path: String, query: [(String, String)] = [], body: B,
                                       bearer: String? = nil) async throws -> (Data, HTTPURLResponse) {
        try await perform(path: path, method: "POST", query: query, rawBody: try JSONEncoder().encode(body),
                          bearer: bearer, headers: [:])
    }

    private func perform(path: String, method: String, query: [(String, String)], rawBody: Data?,
                         bearer: String?, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(url: config.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let rawBody {
            request.httpBody = rawBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        do {
            return try await http.send(request)
        } catch let error as URLError where error.code != .cancelled {
            throw AuthError.offline
        }
    }

    // MARK: Wire formats

    static func normalise(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func serverError(_ response: HTTPURLResponse, _ data: Data) -> BackendError {
        // Auth answers {"code": 403, "error_code": "otp_expired"}; PostgREST answers
        // {"code": "P0001", "message": "profile_limit_reached"} for a raised exception.
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let known = ["profile_limit_reached", "profile_not_in_account"]
        let code = (body["message"] as? String).flatMap { known.contains($0) ? $0 : nil }
            ?? body["error_code"] as? String
            ?? body["code"] as? String
        return .server(status: response.statusCode, code: code)
    }

    static func decodeTokens(_ data: Data, now: Date) throws -> AuthTokens {
        struct Body: Decodable {
            struct User: Decodable { let id: UUID; let email: String? }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        let b = try JSONDecoder().decode(Body.self, from: data)
        return AuthTokens(accessToken: b.access_token, refreshToken: b.refresh_token,
                          expiresAt: now.addingTimeInterval(b.expires_in), userId: b.user.id,
                          email: b.user.email ?? "")
    }

    /// Postgres timestamps come with 0 to 6 fractional digits and a +00:00 offset.
    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }

    static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private struct ProfileRow: Decodable {
        let id: UUID
        let name: String
        let kind: ProfileKind
        let input_mode: InputMode
        let experience: Experience
        var profile: Profile { Profile(id: id, name: name, kind: kind, inputMode: input_mode, experience: experience) }
    }

    private struct ProgressRow: Decodable {
        let lesson_id: String
        let best_stars: Int
        let status: String
        let completed_at: String?
    }

    struct RecordAttemptsBody: Encodable {
        let batch: [AttemptRow]
        let tz: String
    }

    /// One element of record_attempts' batch (see supabase/migrations, record_attempts).
    struct AttemptRow: Encodable {
        let client_attempt_id: String
        let profile_id: String
        let lesson_id: String
        let content_version: Int
        let accuracy: Int
        let stars: Int
        let input_mode: String
        let tempo_pct: Int
        let hands: String
        let started_at: String
        let finished_at: String

        init(_ a: Attempt) {
            client_attempt_id = a.clientAttemptId.uuidString.lowercased()
            profile_id = a.profileId.uuidString.lowercased()
            lesson_id = a.lessonId.lowercased()
            content_version = a.contentVersion
            accuracy = a.accuracy
            stars = a.stars
            input_mode = a.inputMode.rawValue
            tempo_pct = a.tempoPct
            hands = a.hands
            started_at = SupabaseBackend.formatDate(a.startedAt)
            finished_at = SupabaseBackend.formatDate(a.finishedAt)
        }
    }
}
