import AVFoundation
import HandspanCore
import Observation

/// The microphone side of the player: AVAudioEngine input tap → YIN → NoteTracker.
///
/// Deliberately not main-actor isolated. The tap block runs on an audio thread, and a
/// closure created inside a @MainActor method would be inferred as main-actor isolated
/// and trap at runtime under Swift 6. Analysis runs on its own serial queue, never on
/// the audio thread. No audio is stored or sent anywhere (brand.md, string 6).
final class MicPipeline: @unchecked Sendable {
    struct Frame: Sendable {
        let rms: Double
        let estimate: PitchEstimate?
        let note: NoteEvent?
    }

    enum PipelineError: LocalizedError {
        case noInput
        var errorDescription: String? { "No microphone is available." }
    }

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "app.handspan.pitch", qos: .userInteractive)
    // Touched only on `queue`.
    private var detector: YINPitchDetector?
    private var tracker = NoteTracker()
    private var pending: [Float] = []
    private var handler: (@Sendable (Frame) -> Void)?

    func start(onFrame: @escaping @Sendable (Frame) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        // .measurement turns off the voice processing and automatic gain that smear pitch.
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw PipelineError.noInput }
        let detector = YINPitchDetector(sampleRate: format.sampleRate)
        queue.sync {
            self.detector = detector
            self.tracker.reset()
            self.pending.removeAll(keepingCapacity: true)
            self.handler = onFrame
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            self.queue.async { self.consume(samples) }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        queue.async {
            self.pending.removeAll()
            self.handler = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Runs on `queue`. Windows of 2048 samples, a new one every 1024 (about 21 ms at 48 kHz).
    private func consume(_ samples: [Float]) {
        guard let detector else { return }
        pending.append(contentsOf: samples)
        let hop = detector.windowSize / 2
        while pending.count >= detector.windowSize {
            let window = Array(pending.prefix(detector.windowSize))
            pending.removeFirst(hop)
            let estimate = detector.estimate(window)
            let rms = estimate?.rms ?? Self.rms(window)
            let note = tracker.process(estimate, at: ProcessInfo.processInfo.systemUptime)
            handler?(Frame(rms: rms, estimate: estimate, note: note))
        }
    }

    private static func rms(_ x: [Float]) -> Double {
        guard !x.isEmpty else { return 0 }
        var sum = 0.0
        for v in x { sum += Double(v) * Double(v) }
        return (sum / Double(x.count)).squareRoot()
    }
}

/// What screens observe: status, an input level for meters, and the last note heard.
@MainActor @Observable
final class AudioInput {
    enum Status: Equatable { case idle, running, denied, interrupted, failed(String) }

    private(set) var status: Status = .idle
    /// 0...1, for the listening meter.
    private(set) var level: Double = 0
    private(set) var lastHeard: Pitch?
    /// Goes up by one per note, so the same key twice is still a change to observe.
    private(set) var notesHeard = 0

    /// Called on the main actor for every new note.
    @ObservationIgnored var onNote: ((Pitch) -> Void)?
    @ObservationIgnored private let pipeline = MicPipeline()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    var permission: AVAudioApplication.recordPermission { AVAudioApplication.shared.recordPermission }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() async {
        guard status != .running else { return }
        if permission == .undetermined { _ = await requestPermission() }
        guard permission == .granted else {
            status = .denied
            return
        }
        do {
            try pipeline.start { [weak self] frame in
                guard let self else { return }
                Task { @MainActor in self.receive(frame) }
            }
            status = .running
            observeSession()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() {
        guard status == .running || status == .interrupted else { return }
        pipeline.stop()
        status = .idle
        level = 0
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    private func receive(_ frame: MicPipeline.Frame) {
        // -60 dBFS → 0, 0 dBFS → 1
        let db = 20 * log10(max(frame.rms, 1e-6))
        level = min(1, max(0, (db + 60) / 60))
        if let note = frame.note {
            lastHeard = note.pitch
            notesHeard += 1
            onNote?(note.pitch)
        }
    }

    /// Phone calls, Siri and other apps take the mic. Pause, and pick up again after.
    private func observeSession() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated {
                guard let self else { return }
                switch type {
                case .began:
                    self.pipeline.stop()
                    self.status = .interrupted
                case .ended:
                    if self.status == .interrupted {
                        self.status = .idle
                        Task { await self.start() }
                    }
                default: break
                }
            }
        })
    }
}
