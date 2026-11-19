import SwiftUI
import HandspanCore

/// F01: Welcome → what it costs → instrument → experience → goal → sound check → sign in.
/// The price comes second, before any question (fixes.md, fix 1).
enum OnboardingStep: Hashable {
    case price, instrument, experience, goal, soundCheck, signIn(returning: Bool)

    /// Steps that show dots: instrument, experience, goal, sound check.
    static let questionCount = 4
}

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                start: { path.append(.price) },
                signIn: { path.append(.signIn(returning: true)) }
            )
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .price:
                    PriceNoticeView { path.append(.instrument) }
                case .instrument:
                    InstrumentView { path.append(.experience) }
                case .experience:
                    ExperienceView { path.append(.goal) }
                case .goal:
                    GoalView {
                        // No piano: nothing to listen to yet, so skip the sound check.
                        path.append(model.draftInputMode == .touch ? .signIn(returning: false) : .soundCheck)
                    }
                case .soundCheck:
                    SoundCheckView { path.append(.signIn(returning: false)) }
                case .signIn(let returning):
                    SignInView(returning: returning)
                }
            }
        }
    }
}

// MARK: - S01 Welcome

struct WelcomeView: View {
    var start: () -> Void
    var signIn: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            SkyBackground()
            VStack(alignment: .leading, spacing: Space.md) {
                Spacer()
                Image(systemName: "pianokeys")
                    .font(.system(.largeTitle))
                    .foregroundStyle(Palette.tint)
                    .accessibilityHidden(true)
                Text("Learn piano for real.")
                    .font(TextStyle.largeTitle)
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Handspan hears every note you play and shows you what to fix.")
                    .font(TextStyle.title3.weight(.regular))
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: Space.xl)
                Button("Start the free course", action: start)
                    .buttonStyle(.primaryStyle(fullWidth: true))
                Button("I have an account", action: signIn)
                    .font(TextStyle.headline)
                    .frame(maxWidth: .infinity, minHeight: Layout.minTarget)
                    .foregroundStyle(Palette.text)
            }
            .padding(.horizontal, Layout.screenMargin + Space.xs)
            .padding(.bottom, Space.lg)
            .frame(maxWidth: Layout.maxReadableWidth)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - What it costs (string 4)

struct PriceNoticeView: View {
    var next: () -> Void

    var body: some View {
        OnboardingScaffold(title: "What it costs, up front", buttonTitle: "Continue", action: next) {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("The first course is free, start to finish. After that it's \(PriceCopy.monthly) a month. We'll remind you 2 days before any charge.")
                    .font(TextStyle.body)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: Space.md) {
                    Label("No card needed for the first course.", systemImage: "creditcard")
                    Label("A 7-day trial on every plan, monthly too.", systemImage: "equal.circle")
                    Label("Cancel any time in Settings.", systemImage: "xmark.circle")
                }
                .font(TextStyle.subheadline)
                .foregroundStyle(Palette.text)
                .padding(Layout.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.surface))
            }
        }
    }
}

// MARK: - S02 Instrument

struct InstrumentView: View {
    @Environment(AppModel.self) private var model
    @State private var choice: Choice?
    var next: () -> Void

    enum Choice: CaseIterable { case acoustic, digital, noPiano }

    var body: some View {
        OnboardingScaffold(step: 1, title: "What will you play on?",
                           subtitle: "Any piano or keyboard works for the first course.",
                           buttonTitle: "Continue", buttonEnabled: choice != nil, action: {
            model.setInputMode(choice == Choice.noPiano ? .touch : .mic)
            next()
        }) {
            VStack(spacing: Space.stackGap) {
                OptionCard(systemImage: "pianokeys", title: "An acoustic piano",
                           detail: "Upright or grand. Handspan listens through the microphone.",
                           isSelected: choice == .acoustic) { choice = .acoustic }
                OptionCard(systemImage: "pianokeys.inverse", title: "A digital piano or keyboard",
                           detail: "Through the microphone for now. A cable comes later.",
                           isSelected: choice == .digital) { choice = .digital }
                OptionCard(systemImage: "hand.tap", title: "No piano yet",
                           detail: "Play the keys on the screen until you have one.",
                           isSelected: choice == Choice.noPiano) { choice = Choice.noPiano }
            }
        }
    }
}

// MARK: - S03 Experience and goal

struct ExperienceView: View {
    @Environment(AppModel.self) private var model
    @State private var choice: Experience?
    var next: () -> Void

    var body: some View {
        OnboardingScaffold(step: 2, title: "Have you played before?",
                           subtitle: "Everyone starts with the first course. This helps us pace it.",
                           buttonTitle: "Continue", buttonEnabled: choice != nil, action: {
            if let choice { model.draftExperience = choice }
            next()
        }) {
            VStack(spacing: Space.stackGap) {
                OptionCard(systemImage: nil, title: "I'm new to the piano",
                           isSelected: choice == .beginner) { choice = .beginner }
                OptionCard(systemImage: nil, title: "I can play a little",
                           detail: "A few tunes, maybe by ear.",
                           isSelected: choice == .some) { choice = .some }
                OptionCard(systemImage: nil, title: "I read music and play pieces",
                           isSelected: choice == .advanced) { choice = .advanced }
            }
        }
    }
}

struct GoalView: View {
    @Environment(AppModel.self) private var model
    @State private var choice: Goal?
    var next: () -> Void

    var body: some View {
        OnboardingScaffold(step: 3, title: "What would you like to play?",
                           buttonTitle: "Continue", buttonEnabled: choice != nil, action: {
            model.draftGoal = choice
            next()
        }) {
            VStack(spacing: Space.stackGap) {
                OptionCard(systemImage: "music.note.list", title: "Classical pieces",
                           isSelected: choice == .classical) { choice = .classical }
                OptionCard(systemImage: "music.mic", title: "Songs I know",
                           isSelected: choice == .songs) { choice = .songs }
                OptionCard(systemImage: "person.2", title: "Chords, to play along with others",
                           isSelected: choice == .chords) { choice = .chords }
                OptionCard(systemImage: "pencil.and.scribble", title: "My own music",
                           isSelected: choice == .own) { choice = .own }
            }
        }
    }
}

#Preview("Welcome") { WelcomeView(start: {}, signIn: {}) }
#Preview("Flow") { OnboardingFlow().environment(AppModel.preview(onboarded: false)).environment(AudioInput()) }
