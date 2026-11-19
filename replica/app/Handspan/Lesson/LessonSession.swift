import Foundation
import HandspanCore
import Observation

/// Drives one lesson on screen: concept card → exercises → result.
/// Takes notes from any source (mic, screen keys) and turns `LessonRun` feedback
/// into note colours, key colours and one line of coaching.
@MainActor @Observable
final class LessonSession {
    enum Phase: Equatable { case concept, exercise, result }

    let lesson: Lesson
    private(set) var phase: Phase
    private(set) var run: LessonRun
    /// Colour of each note on the staff, by index in the current exercise.
    private(set) var noteStates: [NoteState] = []
    /// Colour of keys on the keyboard strip, by MIDI number.
    private(set) var keyStates: [Int: NoteState] = [:]
    /// The line under the staff: the play hint, or what to fix.
    private(set) var message = ""
    /// Bumped on each wrong note, for haptics.
    private(set) var wrongCount = 0
    /// Times the learner said "I played that right" (fix 3). Logged for tuning.
    private(set) var overrides = 0

    @ObservationIgnored private var pendingAdvance: Task<Void, Never>?
    @ObservationIgnored private var clearWrong: Task<Void, Never>?

    init(lesson: Lesson) {
        self.lesson = lesson
        self.run = LessonRun(lesson)
        self.phase = lesson.concept == nil ? .exercise : .concept
        refreshExercise()
    }

    var exercise: Exercise? { run.current?.exercise }
    var exerciseNumber: Int { run.exerciseIndex + 1 }
    var progress: Double {
        guard run.exerciseCount > 0 else { return 1 }
        let inExercise = run.current.map { Double($0.index) / Double(max(1, $0.exercise.notes.count)) } ?? 0
        return (Double(run.exerciseIndex) + inExercise) / Double(run.exerciseCount)
    }

    func beginExercises() {
        phase = .exercise
        refreshExercise()
    }

    /// One note, from the mic or the screen.
    func play(_ pitch: Pitch) {
        guard phase == .exercise, pendingAdvance == nil, run.current?.target != nil else { return }
        let index = run.current?.index ?? 0
        switch run.play(pitch) {
        case .correct:
            clearWrong?.cancel()
            noteStates[index] = .correct
            keyStates = [pitch.midi: .correct]
            if run.current?.isFinished == true {
                message = "That's the line. Nice and steady."
                pendingAdvance = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    self?.advance()
                }
            } else {
                showTarget()
            }
        case .wrong(let played, let target, let hint):
            wrongCount += 1
            message = hint
            keyStates = [played.midi: .wrong, target.midi: .target]
            noteStates[index] = .wrong
            clearWrong?.cancel()
            clearWrong = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled, let self, self.noteStates.indices.contains(index) else { return }
                self.noteStates[index] = .target
                self.keyStates[played.midi] = nil
            }
        case .ignored:
            break
        }
    }

    /// "I played that right": counts the target as played. Used when recognition is wrong.
    func overrideCorrect() {
        guard let target = run.current?.target else { return }
        overrides += 1
        play(target.pitch)
    }

    func restart() {
        pendingAdvance?.cancel()
        pendingAdvance = nil
        run = LessonRun(lesson)
        phase = .exercise
        refreshExercise()
    }

    private func advance() {
        pendingAdvance = nil
        if run.advanceIfExerciseDone() {
            phase = .result
        } else {
            refreshExercise()
        }
    }

    private func refreshExercise() {
        guard let current = run.current else { return }
        noteStates = current.exercise.notes.indices.map { $0 == current.index ? .target : .upcoming }
        showTarget()
    }

    private func showTarget() {
        guard let current = run.current, let target = current.target else { return }
        if noteStates.indices.contains(current.index) { noteStates[current.index] = .target }
        keyStates = [target.pitch.midi: .target]
        message = Coaching.playHint(target)
    }
}
