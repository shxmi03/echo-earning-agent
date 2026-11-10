// Components.swift
// Primitives for Handspan (working name). iOS 26+. Uses only tokens from Tokens.swift.
// Liquid Glass on the control layer (buttons, HUD, tab bar); frosted, non-glass
// surfaces for content (cards, the staff). See components.md for the full specs.

import SwiftUI

// MARK: - Sky background

/// Full-screen gradient behind Home and Songs. Never behind the player (the staff
/// needs a calm, solid page).
struct SkyBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Palette.skyTop, location: 0.0),
                .init(color: Palette.skyMid, location: 0.45),
                .init(color: Palette.bg, location: 0.78),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Screen header

/// Two-line header from the reference: a plain title over a muted second line,
/// with an optional trailing control (glass button or progress ring).
/// Sits in the sky's top band only, where on-sky text passes contrast.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(TextStyle.title).foregroundStyle(Palette.onSky)
                Text(subtitle).font(TextStyle.title).foregroundStyle(Palette.onSkyMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.md)
            trailing
        }
        .padding(.horizontal, Layout.cardPadding)
        .padding(.top, Layout.headerTop)
    }
}

// MARK: - Frosted card (content surface, not glass)

struct FrostedCard: ViewModifier {
    var radius: CGFloat = Radius.card
    var fill: Color = Palette.cardFill
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(reduceTransparency ? Palette.surface : fill)
                    .background(
                        reduceTransparency ? nil :
                        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.12), radius: 16, y: 12)
            }
    }
}

extension View {
    func frostedCard(radius: CGFloat = Radius.card, fill: Color = Palette.cardFill) -> some View {
        modifier(FrostedCard(radius: radius, fill: fill))
    }
}

// MARK: - Buttons

/// The one solid, high-emphasis action on a screen ("Start lesson"). A black
/// capsule in light mode, a white one in dark mode. Not glass on purpose: it
/// sits on a content card, and glass is for the floating control layer.
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.xs) {
            if isLoading {
                ProgressView().tint(Palette.onAccent)
            }
            configuration.label
                .opacity(isLoading ? 0.6 : 1)
        }
        .font(TextStyle.headline)
        .foregroundStyle(Palette.onAccent)
        .padding(.horizontal, Space.xl)
        .frame(minHeight: 52)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(Capsule().fill(Palette.accent))
        .opacity(isEnabled ? 1 : 0.4)
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
        .animation(Motion.resolve(Motion.tap, reduceMotion: reduceMotion), value: configuration.isPressed)
        .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primaryStyle(loading: Bool = false, fullWidth: Bool = false) -> PrimaryButtonStyle {
        PrimaryButtonStyle(isLoading: loading, fullWidth: fullWidth)
    }
}

/// Round floating control in Liquid Glass (settings, close, pause).
/// Always give it an accessibility label: it has no text.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: Layout.minTarget + 4, height: Layout.minTarget + 4)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let value: Double          // 0...1
    var caption: String = "Course"
    var size: CGFloat = 96
    var lineWidth: CGFloat = 3
    var foreground: Color = Palette.onSky
    var showsLabel = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(foreground.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(value, 1)))
                .stroke(foreground, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                VStack(spacing: 0) {
                    Text(value, format: .percent.precision(.fractionLength(0)))
                        .font(TextStyle.number(.title3))
                        .contentTransition(.numericText(value: value))
                    Text(caption).font(TextStyle.caption).opacity(0.8)
                }
                .foregroundStyle(foreground)
            }
        }
        .frame(width: size, height: size)
        .animation(Motion.resolve(Motion.standard, reduceMotion: reduceMotion), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption) progress")
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - Focus card (the stacked deck from the reference)

/// A sunken container holding three rows: course progress, the main card
/// (today's lesson and the CTA), and what comes next.
struct FocusCard: View {
    let courseTitle: String
    let courseProgress: Double
    let eyebrow: String
    let title: String
    let summary: String
    let duration: String
    let upNext: String
    var start: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // top strip
            HStack(spacing: Space.sm) {
                ProgressRing(value: courseProgress, caption: "", size: 20, lineWidth: 2.5,
                             foreground: Palette.text, showsLabel: false)
                    .accessibilityHidden(true)
                Text(courseTitle).font(TextStyle.subheadline.weight(.medium))
                Spacer()
                Text(courseProgress, format: .percent.precision(.fractionLength(0)))
                    .font(TextStyle.subheadline.weight(.medium).monospacedDigit())
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, Layout.cardPadding)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.lg)
            .accessibilityElement(children: .combine)

            // main card
            VStack(alignment: .leading, spacing: Space.md) {
                Text(eyebrow).font(TextStyle.subheadline).foregroundStyle(Palette.textMuted)
                Text(title).font(TextStyle.titleStrong).foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(summary).font(TextStyle.subheadline).foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Space.xl)
                HStack {
                    Button("Start lesson", action: start).buttonStyle(.primary)
                    Spacer()
                    Label(duration, systemImage: "clock")
                        .font(TextStyle.footnote).foregroundStyle(Palette.textMuted)
                }
            }
            .padding(Layout.cardPadding)
            .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
            .frostedCard()

            // bottom strip
            HStack(spacing: Space.xs) {
                Text("Up next").foregroundStyle(Palette.textMuted)
                Text(upNext).fontWeight(.medium).foregroundStyle(Palette.text)
                Spacer()
            }
            .font(TextStyle.subheadline)
            .padding(.horizontal, Layout.cardPadding)
            .padding(.vertical, Space.lg)
            .accessibilityElement(children: .combine)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.sunkenFill)
        )
    }
}

// MARK: - Week strip (practice days)

struct WeekDay: Identifiable {
    let id = UUID()
    let letter: String     // "M"
    let number: Int        // 2
    let practised: Bool
    let isToday: Bool
}

struct WeekStrip: View {
    let label: String      // "This week"
    let range: String      // "Nov 2–8"
    let days: [WeekDay]
    @Namespace private var todayNS

    var body: some View {
        VStack(spacing: Space.md) {
            HStack {
                Text(label).foregroundStyle(Palette.textMuted)
                Spacer()
                Text(range).foregroundStyle(Palette.text)
            }
            .font(TextStyle.subheadline)

            HStack(spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: Space.xs) {
                        Text(day.letter).font(TextStyle.caption).foregroundStyle(Palette.textMuted)
                        Text("\(day.number)").font(TextStyle.title3.weight(.regular)).foregroundStyle(Palette.text)
                        Circle()
                            .fill(day.practised ? Palette.tint : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background {
                        if day.isToday {
                            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                .fill(Palette.surfaceRaised)
                                .matchedGeometryEffect(id: "today", in: todayNS)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.letter) \(day.number)")
                    .accessibilityValue(day.practised ? "Practised" : "No practice")
                    .accessibilityAddTraits(day.isToday ? .isSelected : [])
                }
            }
        }
        .padding(Layout.cardPadding)
        .frostedCard(fill: Palette.sunkenFill)
    }
}

// MARK: - Stars (result screen)

struct StarRow: View {
    let earned: Int        // 0...3
    var size: CGFloat = 40
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.md) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < shown ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(i < shown ? Palette.warning : Palette.textMuted.opacity(0.4))
                    .scaleEffect(i < shown && !reduceMotion ? 1 : 0.85)
                    .symbolEffect(.bounce, value: i < shown && !reduceMotion)
            }
        }
        .sensoryFeedback(.success, trigger: shown == earned && earned > 0)
        .task {
            // reveal one star at a time
            for i in 0..<earned {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 250))
                withAnimation(Motion.resolve(Motion.reward, reduceMotion: reduceMotion)) { shown = i + 1 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(earned) of 3 stars")
    }
}

// MARK: - Keyboard strip (player hint)

/// One or two octaves of keys under the staff. Shows which key to play and what
/// was heard. Colour changes use Motion.keyFeedback: instant, never springy.
struct KeyboardStrip: View {
    var lowestMidi: Int = 60            // C4
    var octaves: Int = 2
    var states: [Int: NoteState] = [:] // midi -> state

    private var whiteKeys: [Int] {
        (lowestMidi..<(lowestMidi + 12 * octaves + 1)).filter { !Self.isBlack($0) }
    }
    static func isBlack(_ midi: Int) -> Bool { [1, 3, 6, 8, 10].contains(midi % 12) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(whiteKeys.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(whiteKeys, id: \.self) { midi in
                        key(midi, black: false).frame(width: w - 1)
                    }
                }
                ForEach(whiteKeys.indices, id: \.self) { i in
                    let midi = whiteKeys[i] + 1
                    if Self.isBlack(midi), midi < lowestMidi + 12 * octaves {
                        key(midi, black: true)
                            .frame(width: w * 0.6, height: geo.size.height * 0.62)
                            .offset(x: w * CGFloat(i + 1) - w * 0.3)
                    }
                }
            }
        }
        .frame(height: 96)
        .animation(Motion.keyFeedback, value: states)
        .accessibilityHidden(true)     // the staff carries the accessible note info
    }

    @ViewBuilder private func key(_ midi: Int, black: Bool) -> some View {
        let state = states[midi]
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(state.map { $0.color } ?? (black ? Palette.ink : Palette.surfaceRaised))
            .overlay(alignment: .bottom) {
                if let symbol = state?.symbol {
                    Image(systemName: symbol).font(.caption.weight(.bold))
                        .foregroundStyle(Palette.onTint).padding(.bottom, 6)
                }
            }
    }
}

// MARK: - Floating player HUD (Liquid Glass)

/// Pause and tempo controls float over the staff in one glass container, so the
/// shapes blend, and the pause button morphs into the pause menu.
struct PlayerHUD: View {
    @Binding var isPaused: Bool
    let tempoPercent: Int
    let progress: Double
    @Namespace private var glassNS

    var body: some View {
        GlassEffectContainer(spacing: Space.md) {
            HStack(spacing: Space.md) {
                Button {
                    withAnimation(Motion.morph) { isPaused.toggle() }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .contentTransition(.symbolEffect(.replace))
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("pause", in: glassNS)
                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                HStack(spacing: Space.sm) {
                    ProgressView(value: progress).tint(Palette.tint).frame(width: 120)
                    Text("\(tempoPercent)%").font(TextStyle.footnote.monospacedDigit())
                }
                .padding(.horizontal, Space.md)
                .frame(height: 48)
                .glassEffect(.regular, in: .capsule)
                .glassEffectID("status", in: glassNS)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Progress and tempo")
            }
        }
    }
}
