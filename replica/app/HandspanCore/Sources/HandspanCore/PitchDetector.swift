import Foundation

/// One analysis frame's answer: the fundamental, how clear it was (0...1) and the level.
public struct PitchEstimate: Sendable, Equatable {
    public let frequency: Double
    public let clarity: Double
    public let rms: Double

    public init(frequency: Double, clarity: Double, rms: Double) {
        self.frequency = frequency
        self.clarity = clarity
        self.rms = rms
    }
}

/// Single-note pitch detection with the YIN method (de Cheveigné and Kawahara, 2002).
///
/// YIN looks for the period at which the signal best repeats itself. Its cumulative
/// normalisation makes it prefer the first strong period, which is what keeps it from
/// answering an octave high when a piano's second harmonic is louder than the
/// fundamental. Everything runs on the device; no audio leaves it.
///
/// Cost is about `windowSize/2 × maxLag` multiply-adds per frame. At 48 kHz with the
/// defaults that is roughly 1 M per frame, fine for one frame every 1024 samples.
/// Swap the inner loop for vDSP if profiling on an older phone says so.
public struct YINPitchDetector: Sendable {
    public let sampleRate: Double
    public let windowSize: Int
    /// Lower is stricter. 0.10 to 0.20 is the usual range.
    public var threshold: Double
    public var minFrequency: Double
    public var maxFrequency: Double
    /// Frames quieter than this are silence.
    public var silenceRMS: Double

    public init(sampleRate: Double,
                windowSize: Int = 2048,
                threshold: Double = 0.15,
                minFrequency: Double = 60,     // just under B1
                maxFrequency: Double = 2100,   // just over C7
                silenceRMS: Double = 0.004) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.threshold = threshold
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.silenceRMS = silenceRMS
    }

    /// The longest period searched, in samples.
    public var maxLag: Int { min(windowSize / 2, Int(sampleRate / minFrequency) + 1) }

    /// Estimates the pitch of the first `windowSize` samples, or nil for silence or noise.
    public func estimate(_ samples: [Float]) -> PitchEstimate? {
        guard samples.count >= windowSize, sampleRate > 0 else { return nil }
        let n = windowSize

        var sumSquares = 0.0
        for i in 0..<n { let v = Double(samples[i]); sumSquares += v * v }
        let rms = (sumSquares / Double(n)).squareRoot()
        guard rms >= silenceRMS else { return nil }

        let maxLag = self.maxLag
        let minLag = max(2, Int(sampleRate / maxFrequency))
        guard minLag < maxLag else { return nil }
        let width = n - maxLag

        // Step 2: difference function.
        var difference = [Double](repeating: 0, count: maxLag + 1)
        samples.withUnsafeBufferPointer { x in
            for tau in 1...maxLag {
                var sum = 0.0
                for i in 0..<width {
                    let d = Double(x[i] - x[i + tau])
                    sum += d * d
                }
                difference[tau] = sum
            }
        }

        // Step 3: cumulative mean normalised difference.
        var normalised = [Double](repeating: 1, count: maxLag + 1)
        var running = 0.0
        for tau in 1...maxLag {
            running += difference[tau]
            normalised[tau] = running > 0 ? difference[tau] * Double(tau) / running : 1
        }

        // Step 4: the first dip under the threshold, followed to its bottom.
        var chosen = -1
        var tau = minLag
        while tau <= maxLag {
            if normalised[tau] < threshold {
                while tau + 1 <= maxLag, normalised[tau + 1] < normalised[tau] { tau += 1 }
                chosen = tau
                break
            }
            tau += 1
        }
        guard chosen > 0 else { return nil }   // nothing periodic enough: noise, a thud, speech

        // Step 5: parabolic interpolation around the dip.
        var period = Double(chosen)
        if chosen > 1, chosen < maxLag {
            let a = normalised[chosen - 1], b = normalised[chosen], c = normalised[chosen + 1]
            let denominator = a + c - 2 * b
            if denominator != 0 { period += (a - c) / (2 * denominator) }
        }

        let frequency = sampleRate / period
        guard frequency >= minFrequency, frequency <= maxFrequency else { return nil }
        return PitchEstimate(frequency: frequency, clarity: max(0, 1 - normalised[chosen]), rms: rms)
    }
}
