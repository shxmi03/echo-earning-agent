import Foundation

/// A key press the app believes it heard (or received over MIDI, or from a tap).
public struct NoteEvent: Sendable, Equatable {
    public let pitch: Pitch
    public let time: TimeInterval

    public init(pitch: Pitch, time: TimeInterval) {
        self.pitch = pitch
        self.time = time
    }
}

/// Turns a stream of per-frame pitch estimates into note-on events.
///
/// - A new note is confirmed after `framesToConfirm` frames in a row agree, so one
///   noisy frame can't score a note (the "random notes pass" complaint).
/// - Estimates more than `maxCentsOff` from a key are ignored: out-of-tune noise.
/// - The same key struck again is found by its level jumping back up after decaying.
/// - Silence releases the current note.
public struct NoteTracker: Sendable {
    public var framesToConfirm: Int
    public var maxCentsOff: Double
    /// How much louder than the quietest point since the last onset a frame must be
    /// to count as the same key struck again.
    public var reattackRatio: Double
    /// Frames after an onset during which a re-strike is not looked for (the attack
    /// itself is still rising).
    public var reattackHoldFrames: Int

    private var candidate: Pitch?
    private var candidateCount = 0
    public private(set) var sounding: Pitch?
    private var quietestSinceOnset = Double.infinity
    private var framesSinceOnset = 0

    public init(framesToConfirm: Int = 2, maxCentsOff: Double = 40,
                reattackRatio: Double = 1.8, reattackHoldFrames: Int = 4) {
        self.framesToConfirm = framesToConfirm
        self.maxCentsOff = maxCentsOff
        self.reattackRatio = reattackRatio
        self.reattackHoldFrames = reattackHoldFrames
    }

    public mutating func reset() {
        candidate = nil
        candidateCount = 0
        sounding = nil
        quietestSinceOnset = .infinity
        framesSinceOnset = 0
    }

    /// Feeds one frame. Returns an event when a note starts.
    public mutating func process(_ estimate: PitchEstimate?, at time: TimeInterval) -> NoteEvent? {
        guard let estimate else {
            // Silence ends whatever was sounding.
            reset()
            return nil
        }
        guard let match = Pitch.nearest(toFrequency: estimate.frequency),
              abs(match.cents) <= maxCentsOff else {
            candidate = nil
            candidateCount = 0
            return nil
        }
        let pitch = match.pitch

        if let sounding, sounding == pitch {
            framesSinceOnset += 1
            quietestSinceOnset = min(quietestSinceOnset, estimate.rms)
            if framesSinceOnset > reattackHoldFrames,
               estimate.rms > quietestSinceOnset * reattackRatio {
                onset(estimate)
                return NoteEvent(pitch: pitch, time: time)
            }
            return nil
        }

        if candidate == pitch {
            candidateCount += 1
        } else {
            candidate = pitch
            candidateCount = 1
        }
        guard candidateCount >= framesToConfirm else { return nil }
        sounding = pitch
        candidate = nil
        candidateCount = 0
        onset(estimate)
        return NoteEvent(pitch: pitch, time: time)
    }

    private mutating func onset(_ estimate: PitchEstimate) {
        quietestSinceOnset = estimate.rms
        framesSinceOnset = 0
    }
}
