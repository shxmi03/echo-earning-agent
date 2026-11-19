import AVFoundation
import HandspanCore

/// The sound side of the moving stage (S12): the click track and the "Listen" playback.
///
/// Clicks are scheduled on the audio host clock, which is the clock behind
/// `ProcessInfo.systemUptime`, so the click, the cursor and the scoring all read the
/// same time. Output latency (Bluetooth headphones add 150-250 ms) is taken off each
/// click's start, so the click is *heard* on the beat, not just sent on it.
/// Not main-actor isolated, for the same reason as `MicPipeline`.
final class StagePlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let clicks = AVAudioPlayerNode()
    private let sampler = AVAudioUnitSampler()
    private var accent: AVAudioPCMBuffer?
    private var tick: AVAudioPCMBuffer?
    private var listenTask: Task<Void, Never>?

    init() {
        engine.attach(clicks)
        engine.attach(sampler)
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let mono = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate > 0 ? format.sampleRate : 48_000,
                                 channels: 1)!
        engine.connect(clicks, to: engine.mainMixerNode, format: mono)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        accent = Self.clickBuffer(format: mono, frequency: 1_760, gain: 0.55)
        tick = Self.clickBuffer(format: mono, frequency: 1_320, gain: 0.35)
    }

    /// Seconds between handing a sound to the hardware and hearing it.
    var outputLatency: TimeInterval {
        let s = AVAudioSession.sharedInstance()
        return s.outputLatency + s.ioBufferDuration
    }

    /// Seconds between a key sounding and the detector reporting it: the analysis window
    /// plus the confirming frame, plus the input path. A fixed estimate until the latency
    /// calibration in S04 measures it per device.
    var inputLatency: TimeInterval {
        let s = AVAudioSession.sharedInstance()
        return s.inputLatency + s.ioBufferDuration + 0.065
    }

    private func startEngine() throws {
        guard !engine.isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        try session.setActive(true)
        engine.prepare()
        try engine.start()
    }

    /// Schedules a click at each time (uptime seconds). The first of every `beatsPerBar`
    /// is accented, so the count-in's "one" stands out.
    func scheduleClicks(at times: [TimeInterval], beatsPerBar: Int = 4) throws {
        try startEngine()
        clicks.stop()
        let lead = outputLatency
        for (i, t) in times.enumerated() {
            guard let buffer = i % beatsPerBar == 0 ? accent : tick else { continue }
            let when = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: max(0, t - lead)))
            clicks.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)
        }
        clicks.play()
    }

    func stopClicks() {
        clicks.stop()
    }

    /// Plays the exercise's notes at its tempo, for "Listen" in the pause menu.
    /// The sampler with no instrument loaded plays a plain tone; a piano sound comes with
    /// the backing-track work.
    func listen(to exercise: Exercise, tempoPct: Int = 100) {
        listenTask?.cancel()
        do { try startEngine() } catch { return }
        let beat = 60 / (Double(exercise.tempo ?? 72) * Double(tempoPct) / 100)
        nonisolated(unsafe) let sampler = sampler
        listenTask = Task.detached(priority: .userInitiated) {
            for note in exercise.notes {
                guard !Task.isCancelled else { break }
                let midi = UInt8(clamping: note.pitch.midi)
                sampler.startNote(midi, withVelocity: 90, onChannel: 0)
                try? await Task.sleep(for: .seconds(note.duration * beat * 0.9))
                sampler.stopNote(midi, onChannel: 0)
                try? await Task.sleep(for: .seconds(note.duration * beat * 0.1))
            }
        }
    }

    func stopListening() {
        listenTask?.cancel()
        listenTask = nil
        for midi in 0...127 { sampler.stopNote(UInt8(midi), onChannel: 0) }
    }

    func stop() {
        stopClicks()
        stopListening()
        engine.stop()
    }

    /// A 25 ms sine blip with a fast decay.
    private static func clickBuffer(format: AVAudioFormat, frequency: Double, gain: Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * 0.025)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            let envelope = exp(-t * 180)
            data[i] = gain * Float(sin(2 * .pi * frequency * t) * envelope)
        }
        return buffer
    }
}
