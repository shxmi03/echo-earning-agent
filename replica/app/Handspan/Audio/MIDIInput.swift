import AVFoundation
import CoreMIDI
import HandspanCore
import Observation

/// S24: a MIDI keyboard over USB or Bluetooth. Every source is connected as it appears;
/// each note-on reaches the lesson with its exact time, so there's no delay to allow for.
///
/// Like `MicPipeline`, the CoreMIDI side is not main-actor isolated: its blocks run on
/// CoreMIDI's own thread.
final class MIDIPipeline: @unchecked Sendable {
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private let lock = NSLock()
    private var onNote: (@Sendable (Int, TimeInterval) -> Void)?
    private var onChange: (@Sendable () -> Void)?

    func start(onNote: @escaping @Sendable (Int, TimeInterval) -> Void,
               onChange: @escaping @Sendable () -> Void) -> Bool {
        lock.withLock {
            self.onNote = onNote
            self.onChange = onChange
        }
        if client == 0 {
            let made = MIDIClientCreateWithBlock("Handspan" as CFString, &client) { [weak self] message in
                guard message.pointee.messageID == .msgSetupChanged else { return }
                self?.connectAll()
                self?.lock.withLock { self?.onChange }?()
            }
            guard made == noErr else { return false }
            let opened = MIDIInputPortCreateWithProtocol(client, "Handspan input" as CFString, ._1_0, &port) {
                [weak self] list, _ in self?.receive(list)
            }
            guard opened == noErr else { return false }
        }
        connectAll()
        return true
    }

    func stop() {
        lock.withLock { onNote = nil }
    }

    /// Display names of the keyboards that are plugged in or paired.
    var sourceNames: [String] {
        (0..<MIDIGetNumberOfSources()).compactMap { i in
            var name: Unmanaged<CFString>?
            guard MIDIObjectGetStringProperty(MIDIGetSource(i), kMIDIPropertyDisplayName, &name) == noErr else { return nil }
            return name?.takeRetainedValue() as String?
        }
    }

    private func connectAll() {
        guard port != 0 else { return }
        for i in 0..<MIDIGetNumberOfSources() {
            MIDIPortConnectSource(port, MIDIGetSource(i), nil)   // connecting twice is harmless
        }
    }

    private func receive(_ list: UnsafePointer<MIDIEventList>) {
        guard let onNote = lock.withLock({ onNote }) else { return }
        for packet in list.unsafeSequence() {
            let count = Int(packet.pointee.wordCount)
            let words: [UInt32] = withUnsafeBytes(of: packet.pointee.words) { raw in
                Array(raw.bindMemory(to: UInt32.self).prefix(count))
            }
            let stamp = packet.pointee.timeStamp == 0 ? mach_absolute_time() : packet.pointee.timeStamp
            let time = AVAudioTime.seconds(forHostTime: stamp)
            for note in MIDIParser.noteOns(words) { onNote(note, time) }
        }
    }
}

@MainActor @Observable
final class MIDIInput {
    private(set) var devices: [String] = []
    private(set) var isRunning = false
    /// Called on the main actor for every note-on, with the uptime it was played at.
    @ObservationIgnored var onNote: ((Pitch, TimeInterval) -> Void)?
    @ObservationIgnored private let pipeline = MIDIPipeline()

    var hasKeyboard: Bool { !devices.isEmpty }

    func start() {
        let started = pipeline.start(
            onNote: { [weak self] note, time in
                Task { @MainActor in self?.onNote?(Pitch(note), time) }
            },
            onChange: { [weak self] in
                Task { @MainActor in self?.refresh() }
            })
        isRunning = started
        refresh()
    }

    func stop() {
        pipeline.stop()
        isRunning = false
    }

    func refresh() { devices = pipeline.sourceNames }
}
