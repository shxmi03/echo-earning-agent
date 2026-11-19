import Foundation
import Testing
@testable import HandspanCore

/// C D E, one beat each, then C for two beats, at 60 bpm: notes due at 4, 5, 6, 7 s.
private func timed(_ notes: [(Int, Double)] = [(60, 1), (62, 1), (64, 1), (60, 2)], tempo: Int = 60) -> Exercise {
    Exercise(id: UUID().uuidString, prompt: "", clef: .treble,
             notes: notes.map { ExerciseNote(pitch: Pitch($0.0), finger: 1, beats: $0.1) }, tempo: tempo)
}

@Suite struct TimingTests {
    @Test func onsetsFollowTheBeat() {
        let run = TimedExerciseRun(timed(), start: 10)
        #expect(run.beat == 1)
        #expect(run.onsets == [14, 15, 16, 17])
        #expect(run.end == 19)
        #expect(run.clickTimes.count == 9)                 // 4 count-in + 5 beats of music
        let slow = TimedExerciseRun(timed(), start: 0, tempoPct: 50)
        #expect(slow.beat == 2)
        #expect(slow.onsets.first == 8)
    }

    @Test func hitsAreScoredOnTiming() {
        var run = TimedExerciseRun(timed(), start: 0)
        #expect(run.play(Pitch(60), at: 2) == .ignored)    // during the count-in
        #expect(run.play(Pitch(60), at: 4.02) == .hit(index: 0, offset: 4.02 - 4, score: 100))
        guard case .hit(1, let offset, let score) = run.play(Pitch(62), at: 4.85) else {
            Issue.record("D a little early must count"); return
        }
        #expect(offset < 0)
        #expect(score < 100 && score >= 40)
        #expect(run.timingScore(0.25) == 40)
        #expect(run.timingScore(0.26) == 0)
    }

    @Test func wrongKeysAndMisses() {
        var run = TimedExerciseRun(timed(), start: 0)
        #expect(run.play(Pitch(62), at: 4.0) == .wrong(played: Pitch(62), target: Pitch(60),
                                                       hint: "That was D4. Aim two keys lower."))
        #expect(run.advance(to: 4.3) == [0])               // C's window closed
        #expect(run.play(Pitch(60), at: 4.3) == .wrong(played: Pitch(60), target: Pitch(62),
                                                       hint: "That was C4. Aim two keys higher."))
        _ = run.play(Pitch(62), at: 5.0)
        _ = run.play(Pitch(64), at: 6.1)
        #expect(!run.isOver(at: 6.5))
        _ = run.play(Pitch(60), at: 7.0)
        #expect(run.isOver(at: 7.01))                      // every note judged
        let result = run.result
        #expect(result.firstTryHits == 3)
        #expect(result.missedPitches == [Pitch(60)])
        #expect(run.wrongNotes == 2)
        #expect(result.timing != nil)
    }

    @Test func aRepeatedNoteMatchesTheOneDueNow() {
        var run = TimedExerciseRun(timed([(64, 1), (64, 1), (64, 1)], tempo: 120), start: 0)
        // beat 0.5 s, window 0.225 s: notes due at 2.0, 2.5, 3.0
        #expect(run.play(Pitch(64), at: 2.45) == .hit(index: 1, offset: 2.45 - 2.5, score: 100))
        #expect(run.states[0] == .missed)
        #expect(run.upcoming(at: 2.5) == 2)
    }

    @Test func nothingPlayedIsAllMissed() {
        var run = TimedExerciseRun(timed(), start: 0)
        #expect(run.advance(to: 100) == [0, 1, 2, 3])
        #expect(run.result.firstTryHits == 0)
        #expect(run.timing == nil)
    }

    @Test func aLessonWithAStaticAndATimedExercise() {
        let lesson = Lesson(id: UUID().uuidString, title: "t", summary: "s", kind: .exerciseSet, minutes: 5,
                            concept: nil,
                            exercises: [Exercise(id: UUID().uuidString, prompt: "", clef: .treble,
                                                 notes: [ExerciseNote(pitch: Pitch(60), finger: 1)]),
                                        timed()])
        var run = LessonRun(lesson)
        _ = run.play(Pitch(60))
        #expect(run.advanceIfExerciseDone() == false)
        #expect(run.awaitsTimedStart)
        #expect(run.play(Pitch(60)) == .ignored)           // static play does nothing on the stage
        run.startTimed(at: 100)
        #expect(run.playTimed(Pitch(60), at: 104) == .hit(index: 0, offset: 0, score: 100))
        #expect(run.advanceIfExerciseDone(at: 105) == false)   // not over yet
        run.stopTimed()                                     // pause: back to the count-in
        #expect(run.awaitsTimedStart)
        run.startTimed(at: 200)
        for (p, t) in [(60, 204.0), (62, 205.0), (64, 206.0), (60, 207.0)] { _ = run.playTimed(Pitch(p), at: t) }
        #expect(run.advanceIfExerciseDone(at: 207.1) == true)
        let result = run.result
        #expect(result.total == 5)
        #expect(result.firstTryHits == 5)
        #expect(result.stars == 3)
        #expect(result.timing == 100)
    }

    @Test func seedTimedExercisesAreSound() throws {
        let course = try SeedContent.firstCourse()
        let timed = course.lessons.flatMap(\.exercises).filter(\.isTimed)
        #expect(timed.count >= 4)
        for ex in timed {
            #expect((50...120).contains(ex.tempo ?? 0))
            #expect(ex.notes.allSatisfy { [1, 2, 3, 4].contains($0.duration) })
        }
        // The first lesson stays without a clock.
        let firstHasTimed = course.lessons[0].exercises.contains { $0.isTimed }
        #expect(!firstHasTimed)
    }
}

@Suite struct BarDrillTests {
    @Test func barsFollowTheBeats() {
        let e = timed([(60, 1), (62, 1), (64, 2), (65, 4), (67, 2), (65, 2)])
        let bars = e.bars()
        let numbers = bars.map { $0.number }
        let ranges = bars.map { $0.notes }
        #expect(numbers == [1, 2, 3])
        #expect(ranges == [0..<3, 3..<4, 4..<6])
        let slice = e.bar(3, notes: 4..<6)
        let pitches = slice.notes.map { $0.pitch }
        #expect(pitches == [Pitch(67), Pitch(65)])
        #expect(slice.tempo == 60)
        #expect(slice.prompt == "Bar 3")
    }

    @Test func drillTheTrickyBarWithoutChangingTheResult() {
        let e = timed([(60, 1), (62, 1), (64, 1), (65, 1), (67, 1), (65, 1), (64, 1), (62, 1)])
        let lesson = Lesson(id: UUID().uuidString, title: "t", summary: "s", kind: .exerciseSet, minutes: 5,
                            concept: nil, exercises: [e])
        var run = LessonRun(lesson)
        run.startTimed(at: 0)
        // Bar 1 clean; in bar 2 the F (index 5) and the last D (index 7) are missed.
        for (p, t) in [(60, 4.0), (62, 5.0), (64, 6.0), (65, 7.0), (67, 8.0), (64, 10.0)] {
            _ = run.playTimed(Pitch(p), at: t)
        }
        _ = run.tick(at: 12.5)
        #expect(run.stageRun?.isOver(at: 12.5) == true)
        #expect(run.trickyBar?.number == 2)
        #expect(run.trickyBar?.notes == 4..<8)

        run.beginDrill()
        #expect(run.drill?.number == 2)
        #expect(run.stageExercise?.notes.count == 4)
        run.startTimed(at: 100, tempoPct: 100)
        let pass = run.stageRun!
        #expect(pass.tempoPct == 85)                        // drills start a little slower
        let wrong = run.playTimed(Pitch(60), at: pass.onsets[0])
        #expect(wrong != .ignored)                          // a wrong key, judged on the drill
        #expect(run.finishDrillPass() == false)

        run.startTimed(at: 200)
        let again = run.stageRun!
        for (i, p) in [67, 65, 64, 62].enumerated() { _ = run.playTimed(Pitch(p), at: again.onsets[i]) }
        #expect(run.finishDrillPass() == true)
        #expect(run.drill?.cleanPasses == 1)

        run.endDrill()
        #expect(run.advanceIfExerciseDone() == true)
        #expect(run.result.firstTryHits == 6)               // practice never rewrites the first pass
        #expect(run.drill == nil)
    }

    @Test func noBarToDrillWhenClean() {
        var run = TimedExerciseRun(timed(), start: 0)
        for (p, t) in [(60, 4.0), (62, 5.0), (64, 6.0), (60, 7.0)] { _ = run.play(Pitch(p), at: t) }
        #expect(run.trickyBar() == nil)
    }
}
