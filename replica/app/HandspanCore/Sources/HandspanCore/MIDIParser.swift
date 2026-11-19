import Foundation

/// S24: reads note-ons out of Universal MIDI Packet words (CoreMIDI's MIDIEventList in
/// the MIDI 1.0 protocol). Kept apart from CoreMIDI so it can be tested on its own.
public enum MIDIParser {
    /// 32-bit words per message, by message type (the top four bits of the first word).
    private static let wordsPerType = [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4]

    /// MIDI note numbers of every note-on in `words`, in order. A note-on with velocity 0
    /// is a note-off by convention, so it isn't one. Both MIDI 1.0 (type 2) and MIDI 2.0
    /// (type 4) channel voice messages are read.
    public static func noteOns(_ words: [UInt32]) -> [Int] {
        var out: [Int] = []
        var i = 0
        while i < words.count {
            let w = words[i]
            let type = Int(w >> 28)
            let status = (w >> 16) & 0xF0
            switch type {
            case 0x2 where status == 0x90 && (w & 0x7F) > 0:
                out.append(Int((w >> 8) & 0x7F))
            case 0x4 where status == 0x90 && i + 1 < words.count && (words[i + 1] >> 16) > 0:
                out.append(Int((w >> 8) & 0x7F))
            default:
                break
            }
            i += wordsPerType[type]
        }
        return out
    }
}
