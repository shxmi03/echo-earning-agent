import Foundation

/// One key on the piano, as a MIDI note number (middle C = 60).
public struct Pitch: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let midi: Int

    public init(_ midi: Int) { self.midi = midi }

    public static let middleC = Pitch(60)
    /// The lowest and highest keys of an 88-key piano.
    public static let pianoRange = Pitch(21)...Pitch(108)

    private static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    /// Which letter each pitch class is written on. Sharps sit on the letter below.
    private static let letterIndex = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]

    public var pitchClass: Int { ((midi % 12) + 12) % 12 }
    /// Scientific octave: middle C is C4.
    public var octave: Int { Int((Double(midi) / 12).rounded(.down)) - 1 }
    /// "C4", "F♯3".
    public var name: String { Self.names[pitchClass] + String(octave) }
    /// "C", "F♯".
    public var letterName: String { Self.names[pitchClass] }
    public var isBlackKey: Bool { [1, 3, 6, 8, 10].contains(pitchClass) }

    /// Equal temperament, A4 = 440 Hz.
    public var frequency: Double { 440 * pow(2, Double(midi - 69) / 12) }

    /// The nearest key to a frequency, and how far off it is in cents (-50...50).
    public static func nearest(toFrequency hz: Double) -> (pitch: Pitch, cents: Double)? {
        guard hz.isFinite, hz > 0 else { return nil }
        let exact = 69 + 12 * log2(hz / 440)
        let rounded = exact.rounded()
        guard rounded >= 0, rounded <= 127 else { return nil }
        return (Pitch(Int(rounded)), (exact - rounded) * 100)
    }

    /// Steps on the staff, counting letters (C, D, E…) from C-1. One step per line or space.
    public var diatonicStep: Int { (octave + 1) * 7 + Self.letterIndex[pitchClass] }

    /// 0 is the staff's bottom line, 1 the space above it, 2 the next line… Negative is below.
    public func staffPosition(on clef: Clef) -> Int { diatonicStep - clef.bottomLine.diatonicStep }

    public static func < (a: Pitch, b: Pitch) -> Bool { a.midi < b.midi }
    public var description: String { name }
}

extension Pitch: Codable {
    public init(from decoder: Decoder) throws {
        midi = try decoder.singleValueContainer().decode(Int.self)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(midi)
    }
}

public enum Clef: String, Codable, Sendable {
    case treble, bass

    /// The note on the bottom line: E4 in treble, G2 in bass.
    public var bottomLine: Pitch { self == .treble ? Pitch(64) : Pitch(43) }
}

public enum Hand: String, Codable, Sendable {
    case left, right

    public var word: String { rawValue }
}

public enum Staff {
    /// Staff positions that need a short ledger line for a note at `position`.
    /// The five lines are positions 0, 2, 4, 6 and 8.
    public static func ledgerLines(forPosition position: Int) -> [Int] {
        if position <= -2 { return Array(stride(from: -2, through: position, by: -2)) }
        if position >= 10 { return Array(stride(from: 10, through: position, by: 2)) }
        return []
    }
}

/// Feedback sentences, in the voice from brand.md: plain, patient, exact.
public enum Coaching {
    private static let numberWords = ["zero", "one", "two", "three", "four", "five", "six",
                                      "seven", "eight", "nine", "ten", "eleven", "twelve"]

    static func words(_ n: Int) -> String { n < numberWords.count ? numberWords[n] : String(n) }

    /// "That was D4. Aim one key lower." Keys count black and white.
    public static func aimHint(played: Pitch, target: Pitch) -> String {
        let diff = target.midi - played.midi
        guard diff != 0 else { return "That's the one." }
        let direction = diff > 0 ? "higher" : "lower"
        let n = abs(diff)
        let amount: String
        if n % 12 == 0 {
            amount = n == 12 ? "one octave" : "\(words(n / 12)) octaves"
        } else {
            amount = n == 1 ? "one key" : "\(words(n)) keys"
        }
        return "That was \(played.name). Aim \(amount) \(direction)."
    }

    /// "Play C4, right hand, finger 1"
    public static func playHint(_ note: ExerciseNote) -> String {
        "Play \(note.pitch.name), \(note.hand.word) hand, finger \(note.finger)"
    }
}
