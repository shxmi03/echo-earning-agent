import SwiftUI
import HandspanCore

/// S04 follow-up (fix 3): measures this device's microphone delay. The learner plays any
/// key on each of eight clicks; the typical gap is then taken off every note on the moving
/// stage, so "in time" means in time on this piano and this phone.
struct TimingCheckView: View {
    @Environment(AudioInput.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @State private var player = StagePlayer()
    @State private var calibration: LatencyCalibration?
    @State private var outcome: LatencyCalibration.Outcome?
    @State private var saved = LatencyStore.saved
    @State private var finish: Task<Void, Never>?

    private var running: Bool { calibration != nil && outcome == nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Check timing")
                    .font(TextStyle.largeTitle)
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Every microphone hears a little late. Play any key on your piano on each click, eight times after four count-in clicks, and Handspan learns how late this one is.")
                    .font(TextStyle.body)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let calibration, outcome == nil {
                    HStack(spacing: Space.sm) {
                        ForEach(0..<LatencyCalibration.clicksToPlay, id: \.self) { i in
                            Circle()
                                .fill(calibration.offsets[i] != nil ? Palette.success : Palette.border)
                                .frame(width: 14, height: 14)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(calibration.heard) of \(LatencyCalibration.clicksToPlay) heard")
                }

                Text(resultLine)
                    .font(TextStyle.headline)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(outcome == nil ? "Start" : "Try again") { start() }
                    .buttonStyle(.primaryStyle(loading: running, fullWidth: true))
                    .disabled(running)
                if saved != nil {
                    Button("Use the standard setting") {
                        LatencyStore.save(nil)
                        saved = nil
                    }
                    .frame(maxWidth: .infinity, minHeight: Layout.minTarget)
                }
            }
            .padding(.horizontal, Layout.screenMargin + Space.xs)
            .padding(.vertical, Space.md)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onDisappear(perform: stop)
        }
    }

    private var resultLine: String {
        switch outcome {
        case .measured(let delay)?:
            return "Done. This microphone hears \(LatencyCalibration.describe(delay)) late; lessons now allow for it."
        case .tooFew(let heard)?:
            return heard == 0
                ? "Nothing was heard. Check the microphone is allowed in Settings, and play a little louder."
                : "Only \(heard) of \(LatencyCalibration.clicksToPlay) notes were heard. Play a little louder and try again."
        case .unsteady?:
            return "The notes were spread out, so this didn't measure well. Try again, right on each click."
        case nil:
            if running { return "Listen for the clicks…" }
            if let saved { return "Measured: \(LatencyCalibration.describe(saved)) for this microphone." }
            return "Not measured yet. Lessons use a standard setting."
        }
    }

    private func start() {
        stop()
        outcome = nil
        Task {
            await audio.start()
            guard audio.status == .running else {
                outcome = .tooFew(heard: 0)
                return
            }
            let c = LatencyCalibration(start: ProcessInfo.processInfo.systemUptime + 0.6, beat: 0.75)
            calibration = c
            audio.onNote = { _, heardAt in calibration?.record(heardAt: heardAt) }
            try? player.scheduleClicks(at: c.clickTimes)
            finish = Task {
                try? await Task.sleep(for: .seconds(max(0, c.end - ProcessInfo.processInfo.systemUptime)))
                guard !Task.isCancelled else { return }
                complete()
            }
        }
    }

    private func complete() {
        player.stopClicks()
        audio.onNote = nil
        audio.stop()
        guard let calibration else { return }
        let result = calibration.outcome
        if case .measured(let delay) = result {
            LatencyStore.save(delay)
            saved = delay
        }
        outcome = result
    }

    private func stop() {
        finish?.cancel()
        finish = nil
        player.stopClicks()
        audio.onNote = nil
        if calibration != nil, outcome == nil { audio.stop() }
        calibration = nil
    }
}
