import Foundation

public enum PlayFeedback: Equatable, Sendable {
    case correct(Pitch)
    case wrong(played: Pitch, target: Pitch, hint: String)
    /// The exercise was already over.
    case ignored
}

/// One static exercise in progress (S11). No clock: it waits for the right key.
/// A wrong note never counts, and the target note stays the target until it is played.
public struct StaticExerciseRun: Sendable {
    public let exercise: Exercise
    public private(set) var index = 0
    public private(set) var firstTryHits = 0
    public private(set) var wrongNotes = 0
    /// Indexes of notes that needed more than one try.
    public private(set) var missed: [Int] = []
    private var triesOnCurrent = 0

    public init(_ exercise: Exercise) { self.exercise = exercise }

    public var isFinished: Bool { index >= exercise.notes.count }
    public var target: ExerciseNote? { isFinished ? nil : exercise.notes[index] }

    public mutating func play(_ pitch: Pitch) -> PlayFeedback {
        guard let target else { return .ignored }
        if pitch == target.pitch {
            if triesOnCurrent == 0 { firstTryHits += 1 } else { missed.append(index) }
            index += 1
            triesOnCurrent = 0
            return .correct(pitch)
        }
        triesOnCurrent += 1
        wrongNotes += 1
        return .wrong(played: pitch, target: target.pitch,
                      hint: Coaching.aimHint(played: pitch, target: target.pitch))
    }

    public var result: ExerciseResult {
        ExerciseResult(exerciseIndex: 0, total: exercise.notes.count, firstTryHits: firstTryHits,
                       missedPitches: missed.map { exercise.notes[$0].pitch })
    }
}

public struct ExerciseResult: Sendable, Equatable {
    public var exerciseIndex: Int
    public let total: Int
    public let firstTryHits: Int
    public let missedPitches: [Pitch]

    public init(exerciseIndex: Int, total: Int, firstTryHits: Int, missedPitches: [Pitch]) {
        self.exerciseIndex = exerciseIndex
        self.total = total
        self.firstTryHits = firstTryHits
        self.missedPitches = missedPitches
    }
}

/// The end of a lesson (S14).
public struct LessonResult: Sendable, Equatable {
    public let total: Int
    public let firstTryHits: Int
    /// 0...100, as stored in attempts.accuracy.
    public let accuracy: Int
    public let stars: Int
    /// The note missed most often, and the exercise it was first missed in (1-based).
    public let trickiest: (pitch: Pitch, exercise: Int)?

    public var passed: Bool { stars > 0 }

    public static func == (a: LessonResult, b: LessonResult) -> Bool {
        a.total == b.total && a.firstTryHits == b.firstTryHits && a.stars == b.stars
            && a.trickiest?.pitch == b.trickiest?.pitch && a.trickiest?.exercise == b.trickiest?.exercise
    }

    /// Stars from the share of notes right first time: 90% → 3, 70% → 2, 40% → 1.
    public static func stars(forAccuracy accuracy: Int) -> Int {
        switch accuracy {
        case 90...: 3
        case 70..<90: 2
        case 40..<70: 1
        default: 0
        }
    }

    public init(results: [ExerciseResult]) {
        total = results.reduce(0) { $0 + $1.total }
        firstTryHits = results.reduce(0) { $0 + $1.firstTryHits }
        accuracy = total == 0 ? 0 : Int((Double(firstTryHits) * 100 / Double(total)).rounded())
        stars = Self.stars(forAccuracy: accuracy)

        var counts: [Pitch: Int] = [:]
        var firstSeen: [Pitch: Int] = [:]
        for r in results {
            for p in r.missedPitches {
                counts[p, default: 0] += 1
                if firstSeen[p] == nil { firstSeen[p] = r.exerciseIndex + 1 }
            }
        }
        if let worst = counts.max(by: { ($0.value, $1.key.midi) < ($1.value, $0.key.midi) }) {
            trickiest = (worst.key, firstSeen[worst.key] ?? 1)
        } else {
            trickiest = nil
        }
    }

    /// The headline sentence, in the brand voice. Never a zero-star scolding (fix 4).
    public var headline: String {
        if passed { return "\(firstTryHits) of \(total) notes right the first time." }
        if let trickiest {
            return "Almost. \(trickiest.pitch.name) in exercise \(trickiest.exercise) was the tricky one. Try the lesson again?"
        }
        return "Almost. Try the lesson again?"
    }
}

/// A whole lesson: its exercises in order.
public struct LessonRun: Sendable {
    public let lesson: Lesson
    public private(set) var exerciseIndex = 0
    public private(set) var current: StaticExerciseRun?
    public private(set) var results: [ExerciseResult] = []
    public let startedAt: Date

    public init(_ lesson: Lesson, startedAt: Date = Date()) {
        self.lesson = lesson
        self.startedAt = startedAt
        current = lesson.exercises.first.map(StaticExerciseRun.init)
    }

    public var isFinished: Bool { current == nil }
    public var exerciseCount: Int { lesson.exercises.count }

    /// Plays a note into the current exercise. Moves to the next exercise when this one ends.
    public mutating func play(_ pitch: Pitch) -> PlayFeedback {
        guard var run = current else { return .ignored }
        let feedback = run.play(pitch)
        current = run
        return feedback
    }

    /// Call after showing the last note's feedback. Returns true when the lesson is done.
    @discardableResult
    public mutating func advanceIfExerciseDone() -> Bool {
        guard let run = current, run.isFinished else { return isFinished }
        var r = run.result
        r.exerciseIndex = exerciseIndex
        results.append(r)
        exerciseIndex += 1
        current = exerciseIndex < lesson.exercises.count ? StaticExerciseRun(lesson.exercises[exerciseIndex]) : nil
        return isFinished
    }

    public var result: LessonResult { LessonResult(results: results) }
}
