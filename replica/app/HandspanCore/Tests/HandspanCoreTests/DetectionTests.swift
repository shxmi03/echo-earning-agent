import Foundation
import Testing
@testable import HandspanCore

/// A piano-like test tone: a weak fundamental, a louder second harmonic (the classic
/// cause of octave errors), slight string inharmonicity and some noise.
/// Synthetic tones are a smoke test. The real gate is the recorded-piano set (fix 3).
func pianoTone(midi: Int, sampleRate: Double = 48_000, count: Int = 2048,
               harmonics: [Double] = [0.4, 1.0, 0.6, 0.3, 0.2, 0.1],
               amplitude: Double = 0.2, noise: Double = 0.01, seed: UInt64 = 1) -> [Float] {
    var rng = SplitMix(seed: seed)
    let f0 = Pitch(midi).frequency
    let loudest = harmonics.max() ?? 1
    let phases = harmonics.map { _ in rng.nextUnit() * 2 * .pi }
    return (0..<count).map { i in
        let t = Double(i) / sampleRate
        var s = 0.0
        for (k, a) in harmonics.enumerated() {
            let n = Double(k + 1)
            s += a * sin(2 * .pi * f0 * n * (1 + 0.0004 * n * n).squareRoot() * t + phases[k])
        }
        return Float(amplitude * s / loudest + noise * (rng.nextUnit() * 2 - 1))
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

@Suite struct DetectionTests {
    let detector = YINPitchDetector(sampleRate: 48_000)

    @Test(arguments: [36, 48, 55, 60, 62, 64, 65, 67, 69, 72, 84, 96])
    func findsTheRightKeyAndOctave(midi: Int) throws {
        let estimate = try #require(detector.estimate(pianoTone(midi: midi)))
        let match = try #require(Pitch.nearest(toFrequency: estimate.frequency))
        #expect(match.pitch == Pitch(midi))
        #expect(abs(match.cents) < 25)
    }

    @Test func veryWeakFundamentalStaysInOctave() throws {
        let tone = pianoTone(midi: 48, harmonics: [0.05, 1.0, 0.8, 0.5])
        let estimate = try #require(detector.estimate(tone))
        #expect(Pitch.nearest(toFrequency: estimate.frequency)?.pitch == Pitch(48))
    }

    @Test func works_at_44_1kHz() throws {
        let d = YINPitchDetector(sampleRate: 44_100)
        let estimate = try #require(d.estimate(pianoTone(midi: 60, sampleRate: 44_100)))
        #expect(Pitch.nearest(toFrequency: estimate.frequency)?.pitch == Pitch(60))
    }

    @Test func silenceAndNoiseGiveNothing() {
        #expect(detector.estimate([Float](repeating: 0, count: 2048)) == nil)
        var rng = SplitMix(seed: 7)
        let noise = (0..<2048).map { _ in Float(0.05 * (rng.nextUnit() * 2 - 1)) }
        #expect(detector.estimate(noise) == nil)
    }

    @Test func tooFewSamples() {
        #expect(detector.estimate(pianoTone(midi: 60, count: 1000)) == nil)
    }
}

@Suite struct NoteTrackerTests {
    func estimate(_ midi: Int, rms: Double = 0.1, cents: Double = 0) -> PitchEstimate {
        PitchEstimate(frequency: Pitch(midi).frequency * pow(2, cents / 1200), clarity: 0.95, rms: rms)
    }

    @Test func needsTwoFramesToConfirm() {
        var t = NoteTracker()
        #expect(t.process(estimate(60), at: 0) == nil)
        #expect(t.process(estimate(60), at: 0.02) == NoteEvent(pitch: Pitch(60), time: 0.02))
    }

    @Test func oneStrayFrameScoresNothing() {
        var t = NoteTracker()
        #expect(t.process(estimate(67), at: 0) == nil)
        #expect(t.process(estimate(60), at: 0.02) == nil)
        #expect(t.process(nil, at: 0.04) == nil)
    }

    @Test func aHeldNoteCountsOnce() {
        var t = NoteTracker()
        var events: [NoteEvent] = []
        var rms = 0.2
        for i in 0..<40 {
            if let e = t.process(estimate(64, rms: rms), at: Double(i) * 0.02) { events.append(e) }
            rms *= 0.97   // a piano note decays
        }
        #expect(events.count == 1)
    }

    @Test func theSameKeyStruckAgainCountsTwice() {
        var t = NoteTracker()
        var events: [NoteEvent] = []
        let levels = [0.2, 0.2, 0.15, 0.12, 0.1, 0.08, 0.06, 0.05, 0.2, 0.2, 0.15]
        for (i, level) in levels.enumerated() {
            if let e = t.process(estimate(60, rms: level), at: Double(i) * 0.02) { events.append(e) }
        }
        #expect(events.map(\.pitch) == [Pitch(60), Pitch(60)])
    }

    @Test func silenceThenSameKeyCountsAgain() {
        var t = NoteTracker()
        var count = 0
        for frame in [estimate(60), estimate(60), nil, estimate(60), estimate(60)] {
            if t.process(frame, at: 0) != nil { count += 1 }
        }
        #expect(count == 2)
    }

    @Test func outOfTuneFramesAreIgnored() {
        var t = NoteTracker()
        #expect(t.process(estimate(60, cents: 48), at: 0) == nil)
        #expect(t.process(estimate(60, cents: 48), at: 0.02) == nil)
    }

    @Test func aDifferentKeyStartsANewNote() {
        var t = NoteTracker()
        _ = t.process(estimate(60), at: 0)
        _ = t.process(estimate(60), at: 0.02)
        #expect(t.process(estimate(62), at: 0.04) == nil)
        #expect(t.process(estimate(62), at: 0.06)?.pitch == Pitch(62))
    }
}
