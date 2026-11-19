import Foundation
import Testing
@testable import HandspanCore

private func exercise(_ midis: [Int]) -> Exercise {
    Exercise(id: UUID().uuidString, prompt: "", clef: .treble,
             notes: midis.enumerated().map { ExerciseNote(pitch: Pitch($1), finger: $0 % 5 + 1) })
}

private func lesson(_ exercises: [[Int]]) -> Lesson {
    Lesson(id: UUID().uuidString, title: "t", summary: "s", kind: .exerciseSet, minutes: 5,
           concept: nil, exercises: exercises.map(exercise))
}

@Suite struct ScoringTests {
    @Test func waitsForTheRightNote() {
        var run = StaticExerciseRun(exercise([60, 62, 64]))
        #expect(run.play(Pitch(60)) == .correct(Pitch(60)))
        #expect(run.play(Pitch(64)) == .wrong(played: Pitch(64), target: Pitch(62),
                                              hint: "That was E4. Aim two keys lower."))
        #expect(run.target?.pitch == Pitch(62))        // a wrong note never moves on
        #expect(run.play(Pitch(62)) == .correct(Pitch(62)))
        #expect(run.play(Pitch(64)) == .correct(Pitch(64)))
        #expect(run.isFinished)
        #expect(run.play(Pitch(60)) == .ignored)
        #expect(run.result.firstTryHits == 2)
        #expect(run.result.missedPitches == [Pitch(62)])
    }

    @Test func wrongOctaveIsWrong() {
        var run = StaticExerciseRun(exercise([60]))
        guard case .wrong(_, _, let hint) = run.play(Pitch(72)) else {
            Issue.record("C5 must not pass for C4"); return
        }
        #expect(hint == "That was C5. Aim one octave lower.")
    }

    @Test(arguments: [(100, 3), (90, 3), (89, 2), (70, 2), (69, 1), (40, 1), (39, 0), (0, 0)])
    func starThresholds(accuracy: Int, stars: Int) {
        #expect(LessonResult.stars(forAccuracy: accuracy) == stars)
    }

    @Test func aWholeLesson() {
        var run = LessonRun(lesson([[60, 62], [64, 62, 60]]))
        #expect(run.exerciseCount == 2)
        _ = run.play(Pitch(60)); _ = run.play(Pitch(62))
        #expect(run.advanceIfExerciseDone() == false)
        #expect(run.exerciseIndex == 1)
        _ = run.play(Pitch(65)); _ = run.play(Pitch(64))   // E needed two tries
        _ = run.play(Pitch(62)); _ = run.play(Pitch(60))
        #expect(run.advanceIfExerciseDone() == true)
        let result = run.result
        #expect(result.total == 5)
        #expect(result.firstTryHits == 4)
        #expect(result.accuracy == 80)
        #expect(result.stars == 2)
        #expect(result.passed)
        #expect(result.headline == "4 of 5 notes right the first time.")
        #expect(result.trickiest?.pitch == Pitch(64))
        #expect(result.trickiest?.exercise == 2)
    }

    @Test func notYetNamesTheTrickyNote() {
        var run = LessonRun(lesson([[60, 62, 64]]))
        for target in [60, 62, 64] {
            _ = run.play(Pitch(target + 1))
            _ = run.play(Pitch(target))
        }
        run.advanceIfExerciseDone()
        let result = run.result
        #expect(result.stars == 0)
        #expect(!result.passed)
        #expect(result.headline == "Almost. C4 in exercise 1 was the tricky one. Try the lesson again?")
    }

    @Test func advanceDoesNothingMidExercise() {
        var run = LessonRun(lesson([[60, 62]]))
        _ = run.play(Pitch(60))
        #expect(run.advanceIfExerciseDone() == false)
        #expect(run.exerciseIndex == 0)
    }
}

@Suite struct SeedContentTests {
    @Test func firstCourseLoadsAndIsSound() throws {
        let course = try SeedContent.firstCourse()
        #expect(course.isFree)
        #expect(course.lessons.count >= 5)
        let ids = course.lessons.map(\.id) + course.lessons.flatMap { $0.exercises.map(\.id) }
        #expect(Set(ids).count == ids.count, "ids must be unique")
        #expect(ids.allSatisfy { UUID(uuidString: $0) != nil }, "ids are UUIDs, as in the schema")
        for lesson in course.lessons {
            #expect(!lesson.exercises.isEmpty, "\(lesson.title) has no exercises")
            if lesson.kind == .concept { #expect(lesson.concept != nil) }
            for ex in lesson.exercises {
                for note in ex.notes {
                    #expect(Pitch.pianoRange.contains(note.pitch))
                    #expect((1...5).contains(note.finger))
                    // The first course stays on the staff or one ledger line, no sharps.
                    #expect((-2...10).contains(note.pitch.staffPosition(on: ex.clef)))
                    #expect(!note.pitch.isBlackKey)
                }
            }
        }
    }

    @Test func copyAvoidsBannedWords() throws {
        let data = try JSONEncoder().encode(SeedContent.firstCourse())
        let text = String(decoding: data, as: UTF8.self).lowercased()
        for word in ["simply", "easy", "fast", "in minutes"] {
            #expect(!text.contains(word), "brand.md: never \"\(word)\"")
        }
    }
}

@Suite struct FirstSongTests {
    @Test func theFirstCourseEndsOnASong() throws {
        let course = try SeedContent.firstCourse()
        let song = try #require(course.lessons.last)
        #expect(song.kind == .song)
        let whole = try #require(song.exercises.last)
        #expect(whole.isTimed)
        // The lines, played in order, are exactly the whole song.
        let lines = song.exercises.dropLast().flatMap { $0.notes }
        #expect(lines == whole.notes)
        // Every bar is full: 4/4 all the way through.
        let beats = whole.notes.reduce(0.0) { $0 + $1.duration }
        #expect(beats == 64)
        let barCount = whole.bars().count
        #expect(barCount == 16)
    }
}
