import Testing
@testable import HandspanCore

@Suite struct MIDIParserTests {
    @Test func midi1NoteOns() {
        // Note on C4 vel 100 (ch 1), note on E4 vel 0 (= off), note off D4, control change.
        let words: [UInt32] = [0x2090_3C64, 0x2090_4000, 0x2080_3E40, 0x20B0_4000]
        #expect(MIDIParser.noteOns(words) == [60])
    }

    @Test func otherChannelsAndGroups() {
        #expect(MIDIParser.noteOns([0x2393_4350]) == [67])         // group 3, channel 4
    }

    @Test func skipsLongerMessagesWhole() {
        // A 64-bit SysEx (type 3) whose second word looks like a note-on must not count.
        let words: [UInt32] = [0x3016_0001, 0x2090_3C64, 0x2090_4040]
        #expect(MIDIParser.noteOns(words) == [64])
    }

    @Test func midi2NoteOns() {
        // MIDI 2.0 note on (type 4): velocity in the top 16 bits of the second word.
        #expect(MIDIParser.noteOns([0x4090_3C00, 0x8000_0000]) == [60])
        #expect(MIDIParser.noteOns([0x4090_3C00, 0x0000_0000]) == [])
    }
}
