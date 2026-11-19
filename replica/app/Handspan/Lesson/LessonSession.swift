import Foundation
import HandspanCore
import Observation

/// Drives one lesson on screen: concept card → exercises → result.
/// Takes notes from any source (mic, screen keys) and turns `LessonRun` feedback
/// into note colours, key colours and one line of coaching. Static exercises (S11) wait
/// for each note; timed ones (S12) run on a clock with a click track.
@MainActor @Observable
final class LessonSession {
    enum Phase: Equatable { case concept, exercise, result }
    /// The moving stage: ready (waiting for "Start"), running, or paused (S13).
    enum StageState: Equatable { case ready, running, paused }
    /// After a timed exercise with misses: offer to loop the tricky bar, or loop it (fix 4).
    enum AfterStage: Equatable { case none, offer(bar: Int), drilling(bar: Int) }

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
    private(set) var stage: StageState = .ready
    private(set) var afterStage: AfterStage = .none
    /// Tempo for timed exercises, 50...100%. Lowered from the pause menu.
    var tempoPct = 100
    /// The pause menu (S13) is open.
    var isPaused = false

    /// Clock for the stage. Uptime, the same clock as the audio host time.
    @ObservationIgnored var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    @ObservationIgnored let player: StagePlayer?
    @ObservationIgnored private var pendingAdvance: Task<Void, Never>?
    @ObservationIgnored private var clearWrong: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(lesson: Lesson, player: StagePlayer? = StagePlayer()) {
        self.lesson = lesson
        self.player = player
        self.run = LessonRun(lesson)
        self.phase = lesson.concept == nil ? .exercise : .concept
        refreshExercise()
    }

    /// What the screen shows: the current exercise, or the bar being drilled.
    var exercise: Exercise? { run.stageExercise }
    var exerciseNumber: Int { run.exerciseIndex + 1 }
    var isTimed: Bool { exercise?.isTimed == true }
    var progress: Double {
        guard run.exerciseCount > 0 else { return 1 }
        var inExercise = 0.0
        if let current = run.current {
            inExercise = Double(current.index) / Double(max(1, current.exercise.notes.count))
        } else if let timed = run.timed, run.drill == nil {
            inExercise = min(1, max(0, (now() - timed.start) / max(0.001, timed.end - timed.start)))
        }
        return (Double(run.exerciseIndex) + inExercise) / Double(run.exerciseCount)
    }

    func beginExercises() {
        phase = .exercise
        refreshExercise()
    }

    /// One note, from the mic (with the time it was heard) or the screen (now). A MIDI
    /// keyboard's time is exact: nothing is taken off it.
    func play(_ pitch: Pitch, at heardAt: TimeInterval? = nil, exact: Bool = false) {
        guard phase == .exercise, !isPaused else { return }
        if isTimed {
            let latency = exact ? 0 : (player?.inputLatency ?? 0)
            playTimed(pitch, at: heardAt.map { $0 - latency } ?? now())
        } else {
            playStatic(pitch)
        }
    }

    // MARK: Static (S11)

    private func playStatic(_ pitch: Pitch) {
        guard pendingAdvance == nil, run.current?.target != nil else { return }
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

    // MARK: Timed (S12)

    /// Starts the count-in. The first click is a short moment away so the clicks can be
    /// scheduled ahead of the audio clock.
    func startStage() {
        guard isTimed, stage != .running else { return }
        isPaused = false
        let start = now() + 0.6
        run.startTimed(at: start, tempoPct: tempoPct)
        guard let timed = run.stageRun else { return }
        noteStates = Array(repeating: .upcoming, count: timed.exercise.notes.count)
        keyStates = [:]
        message = run.drill == nil
            ? "Get ready: four clicks, then play on the beat."
            : "Bar \(run.drill!.number), a little slower. Four clicks, then play."
        try? player?.scheduleClicks(at: timed.clickTimes)
        stage = .running
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func playTimed(_ pitch: Pitch, at t: TimeInterval) {
        guard stage == .running else { return }
        switch run.playTimed(pitch, at: t) {
        case .hit(let index, let offset, let score):
            noteStates[index] = .correct
            keyStates = [pitch.midi: .correct]
            message = score >= 90 ? "On the beat." : (offset < 0 ? "A touch early." : "A touch late.")
        case .wrong(let played, let target, let hint):
            wrongCount += 1
            keyStates = [played.midi: .wrong]
            if let target { keyStates[target.midi] = .target }
            if let hint { message = hint }
            clearWrong?.cancel()
            clearWrong = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, let self else { return }
                self.keyStates = self.keyStates.filter { $0.value != .wrong }
            }
        case .ignored:
            break
        }
    }

    private func tick() {
        guard stage == .running, let timed = run.stageRun else { return }
        let t = now()
        for i in run.tick(at: t) {
            noteStates[i] = .heard          // missed: information, not a failure
        }
        if let next = run.stageRun?.upcoming(at: t), noteStates[next] == .upcoming {
            for i in noteStates.indices where noteStates[i] == .target { noteStates[i] = .upcoming }
            noteStates[next] = .target
            if keyStates.values.allSatisfy({ $0 != .wrong }) {
                keyStates = [timed.exercise.notes[next].pitch.midi: .target]
            }
        }
        if timed.isOver(at: t), t >= timed.end {
            finishStage(at: t)
        }
    }

    private func finishStage(at t: TimeInterval) {
        ticker?.cancel()
        ticker = nil
        player?.stopClicks()
        stage = .ready
        let hits = run.stageRun?.hits ?? 0
        let total = run.stageRun?.exercise.notes.count ?? 0
        if let drill = run.drill {
            let clean = run.finishDrillPass()
            message = clean ? "Clean. Bar \(drill.number) is yours." : "\(hits) of \(total) in time. Once more?"
            afterStage = .drilling(bar: drill.number)
            return
        }
        if let bar = run.trickyBar {
            message = "\(hits) of \(total) in time. Bar \(bar.number) was the tricky one."
            afterStage = .offer(bar: bar.number)
            return
        }
        message = "\(hits) of \(total) in time."
        pendingAdvance = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.advance(at: t)
        }
    }

    // MARK: Loop the tricky bar (fix 4)

    /// Practise only the bar that went wrong, on a loop, a little slower.
    func practiseBar() {
        guard case .offer = afterStage else { return }
        run.beginDrill()
        guard let drill = run.drill else { return }
        afterStage = .drilling(bar: drill.number)
        stage = .ready
        refreshExercise()
        startStage()
    }

    /// Leaves the drill (or skips it) and goes to the next exercise. The exercise keeps
    /// the result of its first pass.
    func goOn() {
        guard afterStage != .none else { return }
        afterStage = .none
        run.endDrill()
        advance()
    }

    // MARK: Pause menu (S13)

    func pause() {
        guard phase == .exercise else { return }
        isPaused = true
        if stage == .running {
            // A stage can't carry on from the middle: it starts again from the count-in.
            ticker?.cancel()
            ticker = nil
            player?.stopClicks()
            run.stopTimed()
            stage = .paused
            refreshExercise()
        }
    }

    func resume() {
        isPaused = false
        player?.stopListening()
        if stage == .paused { startStage() }
    }

    /// Plays the current exercise's notes so the learner can hear how it goes.
    func listen() {
        guard let exercise else { return }
        player?.listen(to: exercise, tempoPct: tempoPct)
    }

    /// Starts this exercise again (from the pause menu).
    func restartExercise() {
        player?.stopListening()
        pendingAdvance?.cancel()
        pendingAdvance = nil
        isPaused = false
        if isTimed {
            if case .offer = afterStage { afterStage = .none }
            ticker?.cancel()
            ticker = nil
            player?.stopClicks()
            run.stopTimed()
            stage = .ready
            startStage()
        } else {
            run.restartExercise()
            refreshExercise()
        }
    }

    /// The whole lesson again (from the result screen).
    func restart() {
        stopAll()
        run = LessonRun(lesson)
        phase = .exercise
        refreshExercise()
    }

    func stopAll() {
        pendingAdvance?.cancel()
        pendingAdvance = nil
        ticker?.cancel()
        ticker = nil
        player?.stop()
        stage = .ready
        afterStage = .none
        isPaused = false
    }

    private func advance(at t: TimeInterval = .infinity) {
        pendingAdvance = nil
        afterStage = .none
        if run.advanceIfExerciseDone(at: t) {
            stopAll()
            phase = .result
        } else {
            refreshExercise()
        }
    }

    private func refreshExercise() {
        if let current = run.current {
            stage = .ready
            noteStates = current.exercise.notes.indices.map { $0 == current.index ? .target : .upcoming }
            showTarget()
        } else if let exercise = run.stageExercise, exercise.isTimed {
            if stage != .paused { stage = .ready }
            noteStates = Array(repeating: .upcoming, count: exercise.notes.count)
            keyStates = [:]
            message = "In time with the click. Tap Start when your hand is on the keys."
        }
    }

    private func showTarget() {
        guard let current = run.current, let target = current.target else { return }
        if noteStates.indices.contains(current.index) { noteStates[current.index] = .target }
        keyStates = [target.pitch.midi: .target]
        message = Coaching.playHint(target)
    }
}
