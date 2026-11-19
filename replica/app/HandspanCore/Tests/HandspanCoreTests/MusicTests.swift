import Foundation
import Testing
@testable import HandspanCore

@Suite struct MusicTests {
    @Test func namesAndOctaves() {
        #expect(Pitch(60).name == "C4")
        #expect(Pitch(61).name == "C♯4")
        #expect(Pitch(59).name == "B3")
        #expect(Pitch(21).name == "A0")
        #expect(Pitch(108).name == "C8")
    }

    @Test func frequencies() {
        #expect(abs(Pitch(69).frequency - 440) < 1e-9)
        #expect(abs(Pitch.middleC.frequency - 261.6256) < 0.001)
        let near = Pitch.nearest(toFrequency: 446)
        #expect(near?.pitch == Pitch(69))
        #expect(abs((near?.cents ?? 0) - 23.45) < 0.1)
        #expect(Pitch.nearest(toFrequency: 0) == nil)
        #expect(Pitch.nearest(toFrequency: .nan) == nil)
    }

    @Test func staffPositions() {
        #expect(Pitch(64).staffPosition(on: .treble) == 0)    // E4 bottom line
        #expect(Pitch(62).staffPosition(on: .treble) == -1)   // D4 under the staff
        #expect(Pitch(60).staffPosition(on: .treble) == -2)   // middle C, ledger line
        #expect(Pitch(65).staffPosition(on: .treble) == 1)    // F4 bottom space
        #expect(Pitch(77).staffPosition(on: .treble) == 8)    // F5 top line
        #expect(Pitch(61).staffPosition(on: .treble) == -2)   // C♯4 sits on C's line
        #expect(Pitch(43).staffPosition(on: .bass) == 0)      // G2
        #expect(Pitch(60).staffPosition(on: .bass) == 10)     // middle C above the bass staff
    }

    @Test func ledgerLines() {
        #expect(Staff.ledgerLines(forPosition: -2) == [-2])
        #expect(Staff.ledgerLines(forPosition: -1) == [])
        #expect(Staff.ledgerLines(forPosition: -5) == [-2, -4])
        #expect(Staff.ledgerLines(forPosition: 8) == [])
        #expect(Staff.ledgerLines(forPosition: 11) == [10])
    }

    @Test func coachingSentences() {
        #expect(Coaching.aimHint(played: Pitch(62), target: Pitch(60)) == "That was D4. Aim two keys lower.")
        #expect(Coaching.aimHint(played: Pitch(64), target: Pitch(65)) == "That was E4. Aim one key higher.")
        #expect(Coaching.aimHint(played: Pitch(72), target: Pitch(60)) == "That was C5. Aim one octave lower.")
        #expect(Coaching.aimHint(played: Pitch(36), target: Pitch(60)) == "That was C2. Aim two octaves higher.")
        let note = ExerciseNote(pitch: Pitch(62), hand: .right, finger: 2)
        #expect(Coaching.playHint(note) == "Play D4, right hand, finger 2")
    }
}
