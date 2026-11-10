// Tokens.swift
// Design tokens for Handspan (working name), written by hand from replica/design/tokens.json.
// Keep the two in step: change tokens.json, run contrast.py, then update here.
// Target: iOS 26+ (Liquid Glass). SF Pro via the system font, Dynamic Type everywhere.

import SwiftUI
import UIKit

// MARK: - Colour

extension Color {
    /// A colour that follows the system light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Colour roles. Components use these names only, never raw hex.
enum Palette {
    static let skyTop        = Color(light: 0x557F97, dark: 0x04080C)
    static let skyMid        = Color(light: 0xC7D8E6, dark: 0x10314D)
    static let bg            = Color(light: 0xF2F3F6, dark: 0x0A0E13)
    static let surface       = Color(light: 0xF4F6F8, dark: 0x171D24)
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x232B35)
    static let surfaceSunken = Color(light: 0xE2E7EE, dark: 0x10151B)
    static let border        = Color(light: 0xD9DEE5, dark: 0x2A333E)
    static let borderInput   = Color(light: 0x7A828D, dark: 0x6F7B88)
    static let text          = Color(light: 0x111318, dark: 0xF2F5F8)
    static let textMuted     = Color(light: 0x59606B, dark: 0xA3ADB8)
    static let onSky         = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let onSkyMuted    = Color(light: 0xE4EDF2, dark: 0xB3D2E6)
    static let accent        = Color(light: 0x0E0F12, dark: 0xF2F5F8)
    static let onAccent      = Color(light: 0xFFFFFF, dark: 0x0E1114)
    static let tint          = Color(light: 0x0B62A4, dark: 0x6CC0F2)
    static let onTint        = Color(light: 0xFFFFFF, dark: 0x0A0E13)
    static let success       = Color(light: 0x1B7443, dark: 0x4CC38A)
    static let danger        = Color(light: 0xC2352A, dark: 0xFF7A6E)
    static let warning       = Color(light: 0x9A5700, dark: 0xF0B04A)
    static let paper         = Color(light: 0xFBFBFC, dark: 0x141A21)
    static let ink           = Color(light: 0x111318, dark: 0xEEF2F6)

    /// Translucent card fill. Contrast was checked at the composited value (`surface`).
    static let cardFill   = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: 0x1E2630, alpha: 0.80) : UIColor(hex: 0xFFFFFF, alpha: 0.85)
    })
    static let sunkenFill = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: 0x10151B, alpha: 0.70) : UIColor(hex: 0xFFFFFF, alpha: 0.55)
    })
}

/// What the player shows for a note. Never colour alone: every state also has a shape.
enum NoteState: Equatable {
    case upcoming, target, correct, wrong, heard

    var color: Color {
        switch self {
        case .upcoming: Palette.ink
        case .target:   Palette.tint
        case .correct:  Palette.success
        case .wrong:    Palette.danger
        case .heard:    Palette.textMuted
        }
    }

    /// SF Symbol drawn next to or on the note head, for colour-blind users and VoiceOver.
    var symbol: String? {
        switch self {
        case .correct: "checkmark"
        case .wrong:   "xmark"
        case .target:  "arrowtriangle.down.fill"
        default:       nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .upcoming: "Coming up"
        case .target:   "Play this note"
        case .correct:  "Correct"
        case .wrong:    "Not this one"
        case .heard:    "Heard"
        }
    }
}

// MARK: - Type (Dynamic Type text styles; never fixed sizes)

enum TextStyle {
    static let largeTitle  = Font.largeTitle.weight(.bold)
    static let title       = Font.title                       // header pair: "Today" + date
    static let titleStrong = Font.title.weight(.semibold)     // card headline
    static let title3      = Font.title3.weight(.semibold)
    static let headline    = Font.headline
    static let body        = Font.body
    static let subheadline = Font.subheadline                 // card body copy
    static let footnote    = Font.footnote
    static let caption     = Font.caption.weight(.medium)     // weekday letters, metadata
    /// Numbers in rings, stars, streak counts.
    static func number(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .rounded).weight(.semibold).monospacedDigit()
    }
}

// MARK: - Space, radius, layout

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum Layout {
    static let screenMargin: CGFloat = 16
    static let cardPadding: CGFloat = 24
    static let stackGap: CGFloat = 12
    static let headerTop: CGFloat = 24
    static let maxReadableWidth: CGFloat = 640
    /// Minimum hit target (Apple HIG).
    static let minTarget: CGFloat = 44
}

enum Radius {
    static let card: CGFloat = 32
    static let inner: CGFloat = 20    // card - padding + a little, so corners nest
    static let chip: CGFloat = 16
    static let control: CGFloat = 14
}

// MARK: - Motion

enum Motion {
    static let standard = Animation.smooth(duration: 0.35)
    static let tap      = Animation.snappy(duration: 0.25)
    static let reward   = Animation.bouncy(duration: 0.5, extraBounce: 0.1)
    static let morph    = Animation.smooth(duration: 0.4)
    /// Note colour changes. Linear and short: it must feel instant, never springy.
    static let keyFeedback = Animation.linear(duration: 0.06)
    /// What every animation becomes when Reduce Motion is on.
    static let reduced  = Animation.easeInOut(duration: 0.2)

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}
