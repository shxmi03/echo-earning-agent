import SwiftUI
import HandspanCore

/// One static bar of notes on a staff (components.md, StaffView, static variant).
/// Drawn in a single Canvas on `paper`: no glass, no shadows.
struct StaffView: View {
    let exercise: Exercise
    let states: [NoteState]

    /// Staff positions kept visible: two ledger lines below to two above.
    private let lowest = -6
    private let highest = 13

    var body: some View {
        Canvas { context, size in
            // `gap` is one line to the next; positions are half a gap apart.
            let gap = size.height / (CGFloat(highest - lowest) / 2 + 1)
            let half = gap / 2
            let bottomLine = size.height - half - CGFloat(-lowest) * half   // so y(lowest) sits half a gap from the edge
            func y(_ position: Int) -> CGFloat { bottomLine - CGFloat(position) * half }
            let lineColor = Palette.ink.opacity(0.3)

            // The five lines.
            for p in stride(from: 0, through: 8, by: 2) {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(p)))
                line.addLine(to: CGPoint(x: size.width, y: y(p)))
                context.stroke(line, with: .color(lineColor), lineWidth: 1)
            }

            // Clef.
            let clefText = Text(exercise.clef == .treble ? "\u{1D11E}" : "\u{1D122}")
                .font(.system(size: gap * 6.5))
                .foregroundStyle(Palette.ink)
            let clefY = exercise.clef == .treble ? y(3) : y(5)
            context.draw(context.resolve(clefText), at: CGPoint(x: gap * 1.8, y: clefY), anchor: .center)

            // Notes, evenly spaced after the clef.
            let notes = exercise.notes
            guard !notes.isEmpty else { return }
            let left = gap * 5
            let right = size.width - gap * 1.5
            let step = notes.count > 1 ? (right - left) / CGFloat(notes.count - 1) : 0
            let headWidth = gap * 1.3

            for (i, note) in notes.enumerated() {
                let state = states.indices.contains(i) ? states[i] : .upcoming
                let color = state.color
                let p = note.pitch.staffPosition(on: exercise.clef)
                let x = notes.count > 1 ? left + CGFloat(i) * step : (left + right) / 2
                let ny = y(p)

                for ledger in Staff.ledgerLines(forPosition: p) {
                    var l = Path()
                    l.move(to: CGPoint(x: x - headWidth * 0.9, y: y(ledger)))
                    l.addLine(to: CGPoint(x: x + headWidth * 0.9, y: y(ledger)))
                    context.stroke(l, with: .color(Palette.ink), lineWidth: 1.2)
                }

                // Head: a filled oval, tilted.
                var head = context
                head.translateBy(x: x, y: ny)
                head.rotate(by: .degrees(-20))
                head.fill(Path(ellipseIn: CGRect(x: -headWidth / 2, y: -gap * 0.42,
                                                 width: headWidth, height: gap * 0.84)),
                          with: .color(color))

                // Stem: up on the right below the middle line, down on the left from it.
                var stem = Path()
                if p < 4 {
                    stem.move(to: CGPoint(x: x + headWidth / 2 - 0.6, y: ny))
                    stem.addLine(to: CGPoint(x: x + headWidth / 2 - 0.6, y: ny - gap * 3.5))
                } else {
                    stem.move(to: CGPoint(x: x - headWidth / 2 + 0.6, y: ny))
                    stem.addLine(to: CGPoint(x: x - headWidth / 2 + 0.6, y: ny + gap * 3.5))
                }
                context.stroke(stem, with: .color(color), lineWidth: 1.4)

                // Shape as well as colour: ▼ over the target, ✓ or ✕ under played notes.
                if let symbol = state.symbol {
                    var image = context.resolve(Image(systemName: symbol))
                    image.shading = .color(color)
                    let above = state == .target
                    let sy = above ? max(half, min(y(10), ny - gap * 4.3)) : max(y(-3), ny + gap * 1.4)
                    context.draw(image, in: CGRect(x: x - gap * 0.55, y: sy - gap * 0.55,
                                                  width: gap * 1.1, height: gap * 1.1))
                }
            }
        }
        .background(Palette.paper)
        .accessibilityElement()
        .accessibilityLabel("Staff, \(exercise.notes.count) notes")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let i = states.firstIndex(where: { $0 == .target || $0 == .wrong }) else {
            return "All played"
        }
        return "Note \(i + 1): \(Coaching.playHint(exercise.notes[i]))"
    }
}

#Preview {
    let ex = Exercise(id: "p", prompt: "", clef: .treble,
                      notes: [60, 62, 64, 65, 67, 72].map { ExerciseNote(pitch: Pitch($0), finger: 1) })
    StaffView(exercise: ex, states: [.correct, .correct, .wrong, .upcoming, .upcoming, .upcoming])
        .frame(height: 200)
        .padding()
}
