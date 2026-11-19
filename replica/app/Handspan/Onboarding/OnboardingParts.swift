import SwiftUI

/// Layout shared by the onboarding steps: step dots, a title, the content and one
/// primary button pinned to the bottom. Sits on `bg`, never on the sky (components.md).
struct OnboardingScaffold<Content: View>: View {
    var step: Int?
    var steps: Int = OnboardingStep.questionCount
    let title: String
    var subtitle: String?
    var buttonTitle: String
    var buttonEnabled = true
    var isLoading = false
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let step { StepDots(current: step, total: steps) }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title)
                        .font(TextStyle.largeTitle)
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle).font(TextStyle.body).foregroundStyle(Palette.textMuted)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(.horizontal, Layout.screenMargin + Space.xs)
            .padding(.top, Space.md)
            .frame(maxWidth: Layout.maxReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button(buttonTitle, action: action)
                .buttonStyle(.primaryStyle(loading: isLoading, fullWidth: true))
                .disabled(!buttonEnabled || isLoading)
                .padding(.horizontal, Layout.screenMargin + Space.xs)
                .padding(.bottom, Space.sm)
                .frame(maxWidth: Layout.maxReadableWidth)
        }
        .background(Palette.bg.ignoresSafeArea())
    }
}

struct StepDots: View {
    let current: Int   // 1-based
    let total: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Palette.tint : Palette.border)
                    .frame(width: i == current ? Space.lg : Space.xs, height: Space.xs)
            }
        }
        .animation(Motion.standard, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// A selectable answer card (components.md, Option card).
struct OptionCard: View {
    let systemImage: String?
    let title: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(Palette.tint)
                        .frame(width: 36)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(title).font(TextStyle.headline).foregroundStyle(Palette.text)
                    if let detail {
                        Text(detail).font(TextStyle.subheadline).foregroundStyle(Palette.textMuted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Space.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.tint : Palette.borderInput)
                    .accessibilityHidden(true)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, minHeight: Layout.minTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(isSelected ? Palette.surfaceRaised : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(isSelected ? Palette.tint : Palette.border, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(Motion.tap, value: isSelected)
    }
}
