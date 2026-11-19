import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import HandspanCore

/// Answers each request from a list of canned responses and remembers what was asked.
private final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    struct Reply { let status: Int; let body: String }
    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []
    var failWith: URLError?

    init(_ replies: [Reply]) { self.replies = replies }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try lock.withLock {
            requests.append(request)
            if let failWith { throw failWith }
            let r = replies.isEmpty ? Reply(status: 500, body: "{}") : replies.removeFirst()
            let response = HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: nil)!
            return (Data(r.body.utf8), response)
        }
    }

    var paths: [String] { lock.withLock { requests.map { $0.url!.path } } }
    func body(_ i: Int) throws -> [String: Any] {
        let data = try #require(lock.withLock { requests[i].httpBody })
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    func header(_ i: Int, _ name: String) -> String? { lock.withLock { requests[i].value(forHTTPHeaderField: name) } }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var t = Date(timeIntervalSince1970: 1_763_000_000)
    var now: Date { lock.withLock { t } }
    func advance(_ s: TimeInterval) { lock.withLock { t += s } }
}

private let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test")
private let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
private let tokenJSON = """
{"access_token":"jwt-1","token_type":"bearer","expires_in":3600,"refresh_token":"r-1",
 "user":{"id":"11111111-1111-1111-1111-111111111111","email":"ana@example.com"}}
"""

private func backend(_ t: ScriptedTransport, clock: Clock = Clock(), tokens: AuthTokens? = nil)
    -> (SupabaseBackend, MemoryTokenStore) {
    let store = MemoryTokenStore(tokens)
    return (SupabaseBackend(config: config, tokenStore: store, http: t, now: { clock.now }), store)
}

private func signedIn(_ clock: Clock, expiresIn: TimeInterval = 3600) -> AuthTokens {
    AuthTokens(accessToken: "jwt-old", refreshToken: "r-old", expiresAt: clock.now.addingTimeInterval(expiresIn),
               userId: userId, email: "ana@example.com")
}

private let session = Session(accountId: userId, email: "ana@example.com")

@Suite struct SupabaseBackendTests {
    @Test func signInWithACode() async throws {
        let t = ScriptedTransport([.init(status: 200, body: "{}"), .init(status: 200, body: tokenJSON)])
        let (b, store) = backend(t)
        try await b.sendCode(to: "  Ana@Example.com ")
        let s = try await b.verify(email: "ana@example.com", code: "482913")

        #expect(t.paths == ["/auth/v1/otp", "/auth/v1/verify"])
        #expect(try t.body(0)["email"] as? String == "ana@example.com")
        #expect(try t.body(0)["create_user"] as? Bool == true)
        #expect(try t.body(1)["type"] as? String == "email")
        #expect(try t.body(1)["token"] as? String == "482913")
        #expect(t.header(0, "apikey") == "sb_publishable_test")
        #expect(t.header(0, "Authorization") == nil)        // the publishable key is not a JWT
        #expect(s == Session(accountId: userId, email: "ana@example.com"))
        #expect(store.load()?.refreshToken == "r-1")
    }

    @Test func wrongExpiredAndTooMany() async throws {
        let clock = Clock()
        let wrong = ScriptedTransport.Reply(status: 403, body: #"{"code":403,"error_code":"otp_expired","msg":"Token has expired or is invalid"}"#)
        let t = ScriptedTransport([.init(status: 200, body: "{}"), wrong, wrong, wrong, wrong, wrong])
        let (b, _) = backend(t, clock: clock)
        try await b.sendCode(to: "a@b.co")
        await #expect(throws: AuthError.wrongCode) { _ = try await b.verify(email: "a@b.co", code: "111111") }
        await #expect(throws: AuthError.wrongCode) { _ = try await b.verify(email: "a@b.co", code: "12a456") }  // never sent
        #expect(t.paths.count == 2)
        clock.advance(601)
        await #expect(throws: AuthError.expiredCode) { _ = try await b.verify(email: "a@b.co", code: "222222") }
        clock.advance(-601)
        await #expect(throws: AuthError.wrongCode) { _ = try await b.verify(email: "a@b.co", code: "333333") }
        await #expect(throws: AuthError.wrongCode) { _ = try await b.verify(email: "a@b.co", code: "444444") }
        await #expect(throws: AuthError.tooManyTries) { _ = try await b.verify(email: "a@b.co", code: "555555") }
        let sent = t.paths.count
        await #expect(throws: AuthError.tooManyTries) { _ = try await b.verify(email: "a@b.co", code: "666666") }
        #expect(t.paths.count == sent)                       // stops asking the server
    }

    @Test func rateLimitedAndOffline() async throws {
        let t = ScriptedTransport([.init(status: 429, body: #"{"error_code":"over_email_send_rate_limit"}"#)])
        let (b, _) = backend(t)
        await #expect(throws: AuthError.tooManyTries) { try await b.sendCode(to: "a@b.co") }
        await #expect(throws: AuthError.invalidEmail) { try await b.sendCode(to: "not-an-email") }
        t.failWith = URLError(.notConnectedToInternet)
        await #expect(throws: AuthError.offline) { try await b.sendCode(to: "a@b.co") }
    }

    @Test func recordAttemptsSendsTheBatch() async throws {
        let clock = Clock()
        let t = ScriptedTransport([.init(status: 200, body: "1")])
        let (b, _) = backend(t, clock: clock, tokens: signedIn(clock))
        let profile = UUID()
        let a = Attempt(profileId: profile, lessonId: "A0709EE4-87F0-5519-A787-E7004B828EC9", contentVersion: 1,
                        accuracy: 92, stars: 3, inputMode: .mic, startedAt: clock.now.addingTimeInterval(-300),
                        finishedAt: clock.now)
        #expect(try await b.recordAttempts([a], session: session) == 1)

        #expect(t.paths == ["/rest/v1/rpc/record_attempts"])
        #expect(t.header(0, "Authorization") == "Bearer jwt-old")
        let body = try t.body(0)
        #expect(body["tz"] is String)
        let row = try #require((body["batch"] as? [[String: Any]])?.first)
        #expect(row["client_attempt_id"] as? String == a.clientAttemptId.uuidString.lowercased())
        #expect(row["profile_id"] as? String == profile.uuidString.lowercased())
        #expect(row["lesson_id"] as? String == "a0709ee4-87f0-5519-a787-e7004b828ec9")
        #expect(row["stars"] as? Int == 3)
        #expect(row["hands"] as? String == "right")
        #expect(row["finished_at"] as? String == "2025-11-13T02:13:20Z")
    }

    @Test func refreshesAnExpiringToken() async throws {
        let clock = Clock()
        let t = ScriptedTransport([.init(status: 200, body: tokenJSON), .init(status: 200, body: "0")])
        let (b, store) = backend(t, clock: clock, tokens: signedIn(clock, expiresIn: 30))
        _ = try await b.recordAttempts([], session: session)        // empty: no RPC call
        #expect(t.paths.isEmpty)
        let a = Attempt(profileId: UUID(), lessonId: "x", contentVersion: 1, accuracy: 0, stars: 0,
                        inputMode: .touch, startedAt: clock.now, finishedAt: clock.now)
        _ = try await b.recordAttempts([a], session: session)
        #expect(t.paths == ["/auth/v1/token", "/rest/v1/rpc/record_attempts"])
        #expect(try t.body(0)["refresh_token"] as? String == "r-old")
        #expect(t.header(1, "Authorization") == "Bearer jwt-1")
        #expect(store.load()?.accessToken == "jwt-1")
    }

    @Test func retriesOnceAfterA401() async throws {
        let clock = Clock()
        let t = ScriptedTransport([.init(status: 401, body: #"{"code":"PGRST301"}"#),
                                   .init(status: 200, body: tokenJSON),
                                   .init(status: 200, body: "[]")])
        let (b, _) = backend(t, clock: clock, tokens: signedIn(clock))
        #expect(try await b.existingProfile(session: session) == nil)
        #expect(t.paths == ["/rest/v1/profiles", "/auth/v1/token", "/rest/v1/profiles"])
    }

    @Test func revokedRefreshTokenSignsOut() async throws {
        let clock = Clock()
        let t = ScriptedTransport([.init(status: 400, body: #"{"error_code":"refresh_token_not_found"}"#)])
        let (b, store) = backend(t, clock: clock, tokens: signedIn(clock, expiresIn: -10))
        await #expect(throws: BackendError.notSignedIn) { _ = try await b.existingProfile(session: session) }
        #expect(store.load() == nil)
    }

    @Test func anotherAccountsSessionIsRejected() async throws {
        let clock = Clock()
        let t = ScriptedTransport([])
        let (b, _) = backend(t, clock: clock, tokens: signedIn(clock))
        let other = Session(accountId: UUID(), email: "b@example.com")
        await #expect(throws: BackendError.notSignedIn) { _ = try await b.existingProfile(session: other) }
        #expect(t.paths.isEmpty)
    }

    @Test func restoresProfileAndProgress() async throws {
        let clock = Clock()
        let pid = "aaaaaaaa-0000-0000-0000-000000000001"
        let t = ScriptedTransport([
            .init(status: 200, body: #"[{"id":"\#(pid)","name":"Ana","kind":"adult","input_mode":"midi","experience":"some"}]"#),
            .init(status: 200, body: #"[{"lesson_id":"a0709ee4-87f0-5519-a787-e7004b828ec9","best_stars":2,"status":"done","completed_at":"2026-11-19T22:41:07.123456+00:00"},{"lesson_id":"ba403960-5ae3-547c-9466-3822d8cf0528","best_stars":0,"status":"open","completed_at":null}]"#),
        ])
        let (b, _) = backend(t, clock: clock, tokens: signedIn(clock))
        let profile = try #require(try await b.existingProfile(session: session))
        #expect(profile.name == "Ana")
        #expect(profile.inputMode == .midi)
        #expect(profile.experience == .some)
        let progress = try await b.lessonProgress(profileId: profile.id, session: session)
        #expect(progress["a0709ee4-87f0-5519-a787-e7004b828ec9"]?.bestStars == 2)
        #expect(progress["a0709ee4-87f0-5519-a787-e7004b828ec9"]?.done == true)
        #expect(progress["a0709ee4-87f0-5519-a787-e7004b828ec9"]?.completedAt != nil)
        #expect(progress["ba403960-5ae3-547c-9466-3822d8cf0528"]?.done == false)
        let query = try #require(t.requests[1].url?.query)
        #expect(query.contains("profile_id=eq.\(pid)"))
    }

    @Test func profileLimit() async throws {
        let clock = Clock()
        let t = ScriptedTransport([.init(status: 400, body: #"{"code":"P0001","message":"profile_limit_reached","details":null,"hint":null}"#)])
        let (b, _) = backend(t, clock: clock, tokens: signedIn(clock))
        await #expect(throws: BackendError.profileLimitReached) {
            _ = try await b.createProfile(Profile(name: "Two", inputMode: .mic, experience: .beginner), session: session)
        }
    }

    @Test func deleteAccountForgetsTheSession() async throws {
        let clock = Clock()
        let t = ScriptedTransport([.init(status: 204, body: "")])
        let (b, store) = backend(t, clock: clock, tokens: signedIn(clock))
        try await b.deleteAccount(session: session)
        #expect(t.paths == ["/functions/v1/delete-account"])
        #expect(t.header(0, "Authorization") == "Bearer jwt-old")
        #expect(store.load() == nil)
    }
}

@Suite struct FakeBackendProfileTests {
    @Test func secondDeviceFindsTheProfile() async throws {
        let b = FakeBackend()
        let s = try await b.verify(email: "a@b.co", code: "123456")
        #expect(try await b.existingProfile(session: s) == nil)
        let p = try await b.createProfile(Profile(name: "Ana", inputMode: .mic, experience: .beginner), session: s)
        #expect(try await b.existingProfile(session: s) == p)
        await #expect(throws: BackendError.profileLimitReached) {
            _ = try await b.createProfile(Profile(name: "Two", inputMode: .mic, experience: .beginner), session: s)
        }
        let a = Attempt(profileId: p.id, lessonId: "x", contentVersion: 1, accuracy: 90, stars: 3, inputMode: .mic,
                        startedAt: .now, finishedAt: .now)
        _ = try await b.recordAttempts([a], session: s)
        #expect(try await b.lessonProgress(profileId: p.id, session: s)["x"]?.bestStars == 3)
    }
}
