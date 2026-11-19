import Foundation

// S04 / fix 3: measure, per device, how long it takes from a key sounding to the app
// hearing it. The learner plays one key on each of eight clicks; the typical gap between
// a click and the note heard is the delay the moving stage takes off every note.

public struct LatencyCalibration: Sendable {
    public enum Outcome: Equatable, Sendable {
        /// The delay to use, in seconds.
        case measured(TimeInterval)
        /// Fewer than five notes were heard near a click.
        case tooFew(heard: Int)
        /// The notes were too far apart from each other to trust (the player was guessing).
        case unsteady
    }

    public static let countIn = 4
    public static let clicksToPlay = 8
    /// A note further than this from every click isn't an answer to one.
    public static let reach: TimeInterval = 0.45
    public static let maxDelay: TimeInterval = 0.5

    /// The clicks to play on (after the count-in).
    public let targets: [TimeInterval]
    /// Every click, count-in included, for the player.
    public let clickTimes: [TimeInterval]
    public private(set) var offsets: [TimeInterval?]

    public init(start: TimeInterval, beat: TimeInterval = 0.75) {
        let all = (0..<(Self.countIn + Self.clicksToPlay)).map { start + Double($0) * beat }
        clickTimes = all
        targets = Array(all.dropFirst(Self.countIn))
        offsets = Array(repeating: nil, count: Self.clicksToPlay)
    }

    /// When the last answer can still arrive.
    public var end: TimeInterval { (targets.last ?? 0) + Self.reach + 0.1 }
    public var heard: Int { offsets.compactMap { $0 }.count }

    /// A note heard at `t` (uptime). Pairs it with the latest click before it that has no
    /// answer yet, since the detector only ever reports late, never early.
    @discardableResult
    public mutating func record(heardAt t: TimeInterval) -> Int? {
        let candidates = targets.indices.filter {
            offsets[$0] == nil && t >= targets[$0] - 0.05 && t - targets[$0] <= Self.reach
        }
        guard let i = candidates.last else { return nil }
        offsets[i] = t - targets[i]
        return i
    }

    public var outcome: Outcome {
        let values = offsets.compactMap { $0 }.sorted()
        guard values.count >= 5 else { return .tooFew(heard: values.count) }
        // Drop the earliest and the latest, then the rest must agree within 80 ms.
        let middle = values.dropFirst().dropLast()
        guard let lo = middle.first, let hi = middle.last, hi - lo <= 0.08 else { return .unsteady }
        let median = values.count % 2 == 1
            ? values[values.count / 2]
            : (values[values.count / 2 - 1] + values[values.count / 2]) / 2
        return .measured(min(Self.maxDelay, max(0, median)))
    }

    /// "92 ms", for the result line.
    public static func describe(_ delay: TimeInterval) -> String { "\(Int((delay * 1000).rounded())) ms" }
}
