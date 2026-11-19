import Foundation

// S12, the moving stage: notes come to a fixed cursor in time with a click, and each
// one is judged on pitch and on timing. All times are seconds on one clock (the app
// uses ProcessInfo.systemUptime, the same clock the audio host time runs on), already
// corrected for input latency by the caller.

public enum TimedFeedback: Equatable, Sendable {
    /// The note at `index` was played. `offset` is negative when early. `score` 0...100.
    case hit(index: Int, offset: TimeInterval, score: Int)
    /// A key that matches nothing due now. `target` is the note closest in time, if any.
    case wrong(played: Pitch, target: Pitch?, hint: String?)
    /// Before the first note's window, or after the stage is over.
    case ignored
}

public enum TimedNoteState: Equatable, Sendable {
    case pending
    case hit(offset: TimeInterval, score: Int)
    case missed
}

public struct TimedExerciseRun: Sendable {
    public let exercise: Exercise
    /// When the count-in's first click sounds.
    public let start: TimeInterval
    /// Seconds per beat at the chosen tempo.
    public let beat: TimeInterval
    public let countInBeats: Int
    public let tempoPct: Int
    /// When each note should sound.
    public let onsets: [TimeInterval]
    public private(set) var states: [TimedNoteState]
    public private(set) var wrongNotes = 0

    public init(_ exercise: Exercise, start: TimeInterval, tempoPct: Int = 100, countInBeats: Int = 4) {
        self.exercise = exercise
        self.start = start
        self.tempoPct = min(200, max(25, tempoPct))
        self.countInBeats = countInBeats
        let bpm = Double(exercise.tempo ?? 60) * Double(self.tempoPct) / 100
        beat = 60 / bpm
        var t = start + Double(countInBeats) * beat
        var onsets: [TimeInterval] = []
        for note in exercise.notes {
            onsets.append(t)
            t += note.duration * beat
        }
        self.onsets = onsets
        states = Array(repeating: .pending, count: exercise.notes.count)
    }

    /// How far from the beat a note still counts: 250 ms, or less than half a beat when fast.
    public var window: TimeInterval { min(0.25, beat * 0.45) }
    /// When the first note is due.
    public var firstOnset: TimeInterval { onsets.first ?? start }
    /// When the last note has had its full length: the stage is over.
    public var end: TimeInterval {
        guard let last = onsets.last, let note = exercise.notes.last else { return start }
        return max(last + note.duration * beat, last + window)
    }
    /// The clicks: the count-in and every beat until the end.
    public var clickTimes: [TimeInterval] {
        let beats = Int(((end - start) / beat).rounded(.up))
        return (0..<beats).map { start + Double($0) * beat }
    }

    public func isOver(at t: TimeInterval) -> Bool { t >= end || !states.contains(.pending) }
    public var hits: Int { states.filter { if case .hit = $0 { true } else { false } }.count }

    /// Score for being `deviation` seconds off: 100 within 50 ms, falling to 40 at the window's edge.
    public func timingScore(_ deviation: TimeInterval) -> Int {
        let d = abs(deviation)
        if d <= 0.05 { return 100 }
        guard d <= window else { return 0 }
        let share = (d - 0.05) / max(0.001, window - 0.05)
        return Int((100 - 60 * share).rounded())
    }

    /// One key, played at `t`.
    public mutating func play(_ pitch: Pitch, at t: TimeInterval) -> TimedFeedback {
        _ = advance(to: t)
        guard t >= firstOnset - window, t < end + window else { return .ignored }
        let due = states.indices.filter { states[$0] == .pending && abs(t - onsets[$0]) <= window }
        if let i = due.first(where: { exercise.notes[$0].pitch == pitch }) {
            let offset = t - onsets[i]
            let score = timingScore(offset)
            states[i] = .hit(offset: offset, score: score)
            return .hit(index: i, offset: offset, score: score)
        }
        wrongNotes += 1
        let nearest = states.indices.filter { states[$0] == .pending }
            .min { abs(onsets[$0] - t) < abs(onsets[$1] - t) }
        let target = nearest.map { exercise.notes[$0].pitch }
        return .wrong(played: pitch, target: target,
                      hint: target.map { Coaching.aimHint(played: pitch, target: $0) })
    }

    /// Marks every note whose window has passed as missed. Returns the ones that just were.
    public mutating func advance(to t: TimeInterval) -> [Int] {
        var newlyMissed: [Int] = []
        for i in states.indices where states[i] == .pending && t > onsets[i] + window {
            states[i] = .missed
            newlyMissed.append(i)
        }
        return newlyMissed
    }

    /// The note to show on the keyboard strip: the next one not yet played.
    public func upcoming(at t: TimeInterval) -> Int? {
        states.indices.first { states[$0] == .pending && t <= onsets[$0] + window }
    }

    /// Average timing of the notes that were hit, 0...100; nil when none were.
    public var timing: Int? {
        let scores = states.compactMap { if case .hit(_, let s) = $0 { s } else { nil } }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    /// Call once the stage is over. A hit counts as right first time; a miss does not.
    public var result: ExerciseResult {
        let missed = states.indices.filter { !isHit($0) }
        return ExerciseResult(exerciseIndex: 0, total: exercise.notes.count, firstTryHits: hits,
                              missedPitches: missed.map { exercise.notes[$0].pitch }, timing: timing)
    }

    private func isHit(_ i: Int) -> Bool { if case .hit = states[i] { true } else { false } }
}
