import Foundation
import Testing
@testable import HandspanCore

@Suite struct CalibrationTests {
    @Test func steadyNotesGiveTheMedianDelay() {
        var c = LatencyCalibration(start: 100, beat: 0.75)
        #expect(c.targets.first == 103)                        // after four count-in clicks
        #expect(c.clickTimes.count == 12)
        let delays = [0.09, 0.10, 0.11, 0.10, 0.12, 0.09, 0.10, 0.11]
        for (i, d) in delays.enumerated() { c.record(heardAt: c.targets[i] + d) }
        #expect(c.heard == 8)
        guard case .measured(let delay) = c.outcome else { Issue.record("expected a measurement"); return }
        #expect(abs(delay - 0.10) < 0.001)
        #expect(LatencyCalibration.describe(delay) == "100 ms")
    }

    @Test func notesDuringTheCountInOrFarAwayDontCount() {
        var c = LatencyCalibration(start: 0, beat: 1)
        #expect(c.record(heardAt: 1.1) == nil)                 // count-in
        #expect(c.record(heardAt: 4.7) == nil)                 // too far after the click at 4
        #expect(c.record(heardAt: 5.1) == 1)
        #expect(c.record(heardAt: 5.2) == nil)                 // that click already has its answer
    }

    @Test func tooFewOrUnsteady() {
        var few = LatencyCalibration(start: 0, beat: 1)
        for i in 0..<3 { few.record(heardAt: few.targets[i] + 0.1) }
        #expect(few.outcome == .tooFew(heard: 3))

        var wild = LatencyCalibration(start: 0, beat: 1)
        for (i, d) in [0.05, 0.3, 0.1, 0.4, 0.0, 0.25, 0.15, 0.35].enumerated() { wild.record(heardAt: wild.targets[i] + d) }
        #expect(wild.outcome == .unsteady)
    }

    @Test func oneStrayNoteIsForgiven() {
        var c = LatencyCalibration(start: 0, beat: 1)
        for (i, d) in [0.1, 0.1, 0.4, 0.1, 0.11, 0.09, 0.1, 0.1].enumerated() { c.record(heardAt: c.targets[i] + d) }
        guard case .measured(let delay) = c.outcome else { Issue.record("expected a measurement"); return }
        #expect(abs(delay - 0.1) < 0.001)
    }
}
