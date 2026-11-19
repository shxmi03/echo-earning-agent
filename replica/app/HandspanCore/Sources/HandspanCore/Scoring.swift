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
    /// Timed exercises only: average timing of the notes hit, 0...100.
    public let timing: Int?

    public init(exerciseIndex: Int, total: Int, firstTryHits: Int, missedPitches: [Pitch], timing: Int? = nil) {
        self.exerciseIndex = exerciseIndex
        self.total = total
        self.firstTryHits = firstTryHits
        self.missedPitches = missedPitches
        self.timing = timing
    }
}

/// The end of a lesson (S14).
public struct LessonResult: Sendable, Equatable {
    public let total: Int
    public let firstTryHits: Int
    /// 0...100, as stored in attempts.accuracy.
    public let accuracy: Int
    public let stars: Int
    /// 0...100 over the timed exercises, as in attempts.timing; nil when the lesson had none.
    public let timing: Int?
    /// The note missed most often, and the exercise it was first missed in (1-based).
    public let trickiest: (pitch: Pitch, exercise: Int)?

    public var passed: Bool { stars > 0 }

    public static func == (a: LessonResult, b: LessonResult) -> Bool {
        a.total == b.total && a.firstTryHits == b.firstTryHits && a.stars == b.stars && a.timing == b.timing
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
        let timings = results.compactMap(\.timing)
        timing = timings.isEmpty ? nil : Int((Double(timings.reduce(0, +)) / Double(timings.count)).rounded())

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

/// A whole lesson: its exercises in order. Static exercises run in `current`; a timed
/// one waits in `pendingTimed` until the screen starts its clock, then runs in `timed`.
public struct LessonRun: Sendable {
    public let lesson: Lesson
    public private(set) var exerciseIndex = 0
    public private(set) var current: StaticExerciseRun?
    public private(set) var timed: TimedExerciseRun?
    /// Practising the bar that went wrong, after a timed exercise ended (fix 4).
    public private(set) var drill: BarDrill?
    public private(set) var results: [ExerciseResult] = []
    public let startedAt: Date

    public init(_ lesson: Lesson, startedAt: Date = Date()) {
        self.lesson = lesson
        self.startedAt = startedAt
        load()
    }

    public var isFinished: Bool { exerciseIndex >= lesson.exercises.count }
    public var exerciseCount: Int { lesson.exercises.count }
    public var currentExercise: Exercise? { isFinished ? nil : lesson.exercises[exerciseIndex] }
    /// The current exercise is timed and its clock hasn't started (or was stopped).
    public var awaitsTimedStart: Bool { currentExercise?.isTimed == true && timed == nil }

    /// Plays a note into the current static exercise.
    public mutating func play(_ pitch: Pitch) -> PlayFeedback {
        guard var run = current else { return .ignored }
        let feedback = run.play(pitch)
        current = run
        return feedback
    }

    // MARK: Timed (S12)

    /// What the stage shows: the drilled bar while drilling, else the current exercise.
    public var stageExercise: Exercise? { drill?.exercise ?? currentExercise }
    /// The clock the stage runs on: the drill's pass while drilling, else the exercise's.
    public var stageRun: TimedExerciseRun? { drill == nil ? timed : drill?.run }

    /// Starts the current timed exercise (or the next drill pass): the count-in's first
    /// click is at `start`.
    public mutating func startTimed(at start: TimeInterval, tempoPct: Int = 100) {
        if let exercise = drill?.exercise {
            drill?.run = TimedExerciseRun(exercise, start: start, tempoPct: BarDrill.tempo(for: tempoPct))
            return
        }
        guard let exercise = currentExercise, exercise.isTimed else { return }
        timed = TimedExerciseRun(exercise, start: start, tempoPct: tempoPct)
    }

    /// Drops the running clock (pause, restart): the exercise starts again from its count-in.
    public mutating func stopTimed() {
        if drill != nil { drill?.run = nil; return }
        if currentExercise?.isTimed == true { timed = nil }
    }

    public mutating func playTimed(_ pitch: Pitch, at t: TimeInterval) -> TimedFeedback {
        if var pass = drill?.run {
            let feedback = pass.play(pitch, at: t)
            drill?.run = pass
            return feedback
        }
        guard drill == nil, var run = timed else { return .ignored }
        let feedback = run.play(pitch, at: t)
        timed = run
        return feedback
    }

    /// Moves the clock on. Returns the notes that were just missed.
    public mutating func tick(at t: TimeInterval) -> [Int] {
        if var pass = drill?.run {
            let missed = pass.advance(to: t)
            drill?.run = pass
            return missed
        }
        guard drill == nil, var run = timed else { return [] }
        let missed = run.advance(to: t)
        timed = run
        return missed
    }

    /// The bar worth practising after the timed exercise ended, if any note was missed.
    public var trickyBar: (number: Int, notes: Range<Int>)? {
        guard drill == nil, var run = timed else { return nil }
        _ = run.advance(to: .infinity)
        return run.trickyBar()
    }

    /// Starts practising the tricky bar. The exercise's result is already fixed.
    public mutating func beginDrill() {
        guard let bar = trickyBar, let exercise = currentExercise else { return }
        drill = BarDrill(number: bar.number, exercise: exercise.bar(bar.number, notes: bar.notes))
    }

    /// Ends a drill pass. Returns true when it was clean.
    @discardableResult
    public mutating func finishDrillPass() -> Bool { drill?.finishPass() ?? false }

    /// Leaves the drill; the learner goes on with `advanceIfExerciseDone`.
    public mutating func endDrill() { drill = nil }

    /// Call after showing the last note's feedback. Returns true when the lesson is done.
    /// A timed exercise ends when its clock passes the end (`at`), a static one when its
    /// last note is played.
    @discardableResult
    public mutating func advanceIfExerciseDone(at t: TimeInterval = .infinity) -> Bool {
        drill = nil
        var r: ExerciseResult
        if let run = current, run.isFinished {
            r = run.result
        } else if var run = timed, run.isOver(at: t) {
            _ = run.advance(to: .infinity)
            r = run.result
        } else {
            return isFinished
        }
        r.exerciseIndex = exerciseIndex
        results.append(r)
        exerciseIndex += 1
        load()
        return isFinished
    }

    public var result: LessonResult { LessonResult(results: results) }

    /// The current exercise from its first note again; earlier exercises keep their results.
    public mutating func restartExercise() { load() }

    private mutating func load() {
        drill = nil
        timed = nil
        current = nil
        guard let exercise = currentExercise, !exercise.isTimed else { return }
        current = StaticExerciseRun(exercise)
    }
}
