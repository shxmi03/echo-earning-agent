import Foundation
import HandspanCore

/// The Supabase project the app talks to (replica/supabase, project "handspan").
/// Both values are public by design: the publishable key ships inside every copy of the
/// app, and row level security is what protects each account's rows. Never put the
/// service role key or a database password here.
/// Empty values make the app use the in-memory `FakeBackend` (any 6-digit code works).
enum SupabaseSettings {
    static let url = "https://ypvscfhwywxjnjzhcmqq.supabase.co"
    static let publishableKey = "sb_publishable_H0Tsfl0OOXE5Fm0ogy1AmA_hiyJF4vd"

    static var config: SupabaseConfig? {
        if ProcessInfo.processInfo.environment["HANDSPAN_FAKE_BACKEND"] == "1" { return nil }
        guard !publishableKey.isEmpty, let url = URL(string: url), url.scheme == "https" else { return nil }
        return SupabaseConfig(url: url, publishableKey: publishableKey)
    }
}
