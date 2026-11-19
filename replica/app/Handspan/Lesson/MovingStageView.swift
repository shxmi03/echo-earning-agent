import SwiftUI
import HandspanCore

/// S12: the staff scrolls right to left under a fixed cursor (components.md: StaffView,
/// moving variant; Cursor, moving-stage line at 30% of the width). Position comes from
/// the same uptime clock as the clicks and the scoring, never from a SwiftUI animation.
struct MovingStageView: View {
    let session: LessonSession
    var showFingers = true

    private let lowest = -6
    private let highest = 13

    var body: some View {
        TimelineView(.animation(paused: session.stage != .running)) { context in
            let t = session.now()
            Canvas { gc, size in draw(in: &gc, size: size, at: t) }
        }
        .background(Palette.paper)
        .accessibilityElement()
        .accessibilityLabel("Moving staff")
        .accessibilityValue(accessibilityValue)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, at t: TimeInterval) {
        guard let exercise = session.exercise else { return }
        let gap = size.height / (CGFloat(highest - lowest) / 2 + 1)
        let half = gap / 2
        let bottomLine = size.height - half - CGFloat(-lowest) * half
        func y(_ position: Int) -> CGFloat { bottomLine - CGFloat(position) * half }
        let lineColor = Palette.ink.opacity(0.3)
        let clefWidth = gap * 3.8
        let cursorX = max(clefWidth + gap * 2, size.width * 0.3)
        let pxPerBeat = gap * 5

        // Where we are, in beats from the first note. Before the clock starts, the first
        // note waits a little to the right of the cursor.
        let timed = session.run.stageRun
        let nowBeats: Double = timed.map { (t - $0.firstOnset) / $0.beat } ?? -1.5
        var startBeat = 0.0
        let noteBeats: [Double] = exercise.notes.map { note in
            defer { startBeat += note.duration }
            return startBeat
        }

        func staffLines(from x0: CGFloat, to x1: CGFloat) {
            for p in stride(from: 0, through: 8, by: 2) {
                var line = Path()
                line.move(to: CGPoint(x: x0, y: y(p)))
                line.addLine(to: CGPoint(x: x1, y: y(p)))
                context.stroke(line, with: .color(lineColor), lineWidth: 1)
            }
        }
        staffLines(from: 0, to: size.width)

        // Bar lines every four beats, so the eye can feel the bar.
        let lastBeat = startBeat
        for bar in stride(from: 0.0, through: lastBeat, by: 4) where bar > 0 {
            let x = cursorX + CGFloat(bar - nowBeats) * pxPerBeat - pxPerBeat * 0.5
            guard x > clefWidth, x < size.width else { continue }
            var line = Path()
            line.move(to: CGPoint(x: x, y: y(0)))
            line.addLine(to: CGPoint(x: x, y: y(8)))
            context.stroke(line, with: .color(lineColor), lineWidth: 1)
        }

        let headWidth = gap * 1.3
        for (i, note) in exercise.notes.enumerated() {
            let x = cursorX + CGFloat(noteBeats[i] - nowBeats) * pxPerBeat
            guard x > clefWidth - headWidth, x < size.width + headWidth else { continue }
            let state = session.noteStates.indices.contains(i) ? session.noteStates[i] : .upcoming
            let color = state.color
            let p = note.pitch.staffPosition(on: exercise.clef)
            let ny = y(p)

            // A faint bar behind the head shows how long the note lasts.
            if note.duration > 1 {
                let length = CGFloat(note.duration) * pxPerBeat - headWidth
                context.fill(Path(roundedRect: CGRect(x: x, y: ny - gap * 0.18, width: length, height: gap * 0.36),
                                  cornerRadius: gap * 0.18),
                             with: .color(color.opacity(0.18)))
            }
            for ledger in Staff.ledgerLines(forPosition: p) {
                var l = Path()
                l.move(to: CGPoint(x: x - headWidth * 0.9, y: y(ledger)))
                l.addLine(to: CGPoint(x: x + headWidth * 0.9, y: y(ledger)))
                context.stroke(l, with: .color(Palette.ink), lineWidth: 1.2)
            }
            var head = context
            head.translateBy(x: x, y: ny)
            head.rotate(by: .degrees(-20))
            let oval = Path(ellipseIn: CGRect(x: -headWidth / 2, y: -gap * 0.42, width: headWidth, height: gap * 0.84))
            if note.duration >= 2 {
                head.stroke(oval, with: .color(color), lineWidth: 1.8)      // half and whole notes are hollow
            } else {
                head.fill(oval, with: .color(color))
            }
            if note.duration < 4 {
                var stem = Path()
                if p < 4 {
                    stem.move(to: CGPoint(x: x + headWidth / 2 - 0.6, y: ny))
                    stem.addLine(to: CGPoint(x: x + headWidth / 2 - 0.6, y: ny - gap * 3.5))
                } else {
                    stem.move(to: CGPoint(x: x - headWidth / 2 + 0.6, y: ny))
                    stem.addLine(to: CGPoint(x: x - headWidth / 2 + 0.6, y: ny + gap * 3.5))
                }
                context.stroke(stem, with: .color(color), lineWidth: 1.4)
            }
            if showFingers {
                let label = Text("\(note.finger)")
                    .font(.system(size: gap * 0.95, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textMuted)
                context.draw(context.resolve(label), at: CGPoint(x: x, y: y(12)), anchor: .center)
            }
            if let symbol = state.symbol {
                var image = context.resolve(Image(systemName: symbol))
                image.shading = .color(color)
                let above = state == .target
                let sy = above ? max(half, min(y(10), ny - gap * 4.3)) : max(y(-3), ny + gap * 1.4)
                context.draw(image, in: CGRect(x: x - gap * 0.55, y: sy - gap * 0.55, width: gap * 1.1, height: gap * 1.1))
            }
        }

        // The clef panel stays put; notes slide under it and disappear.
        context.fill(Path(CGRect(x: 0, y: 0, width: clefWidth, height: size.height)), with: .color(Palette.paper))
        staffLines(from: 0, to: clefWidth)
        let clef = Text(exercise.clef == .treble ? "\u{1D11E}" : "\u{1D122}")
            .font(.system(size: gap * 6.5))
            .foregroundStyle(Palette.ink)
        context.draw(context.resolve(clef), at: CGPoint(x: gap * 1.8, y: exercise.clef == .treble ? y(3) : y(5)),
                     anchor: .center)

        // The cursor: where a note should sound.
        var cursor = Path()
        cursor.move(to: CGPoint(x: cursorX, y: half))
        cursor.addLine(to: CGPoint(x: cursorX, y: size.height - half))
        context.stroke(cursor, with: .color(Palette.tint), lineWidth: 2)

        // The count-in: 4, 3, 2, 1 over the staff.
        if let timed, t < timed.firstOnset, t >= timed.start - 0.05 {
            let left = Int(((timed.firstOnset - t) / timed.beat).rounded(.up))
            let text = Text("\(max(1, left))")
                .font(.system(size: gap * 4, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.tint)
            context.draw(context.resolve(text), at: CGPoint(x: cursorX + gap * 4, y: size.height / 2), anchor: .center)
        }
    }

    private var accessibilityValue: String {
        guard let exercise = session.exercise else { return "" }
        if let i = session.noteStates.firstIndex(of: .target) {
            return "Next: \(Coaching.playHint(exercise.notes[i]))"
        }
        return "\(exercise.notes.count) notes"
    }
}
