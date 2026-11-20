import SwiftUI
import StoreKit
import HandspanCore

/// S05. Shown only when the learner asks for plans or reaches locked content, never
/// inside a lesson (pricing.md). Monthly is preselected; the line under the button says
/// exactly when the first charge happens and how much it is (App Review 3.1.2: plan,
/// price, period, restore, terms).
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var size: PlanSize = .solo
    @State private var period: PlanPeriod = .monthly
    @State private var busy = false
    @State private var note: String?

    private var plan: Plan { Plan.find(size, period) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("Keep going after the first course")
                        .font(TextStyle.largeTitle)
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: Space.sm) {
                        bullet("Every course and song as they come out", "music.note.list")
                        bullet("Practise at your own tempo, with or without the click", "metronome")
                        bullet("No ads, ever", "nosign")
                    }

                    Picker("Plan size", selection: $size) {
                        ForEach(PlanSize.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(size.detail)
                        .font(TextStyle.footnote)
                        .foregroundStyle(Palette.textMuted)

                    VStack(spacing: Space.sm) {
                        ForEach(PlanPeriod.allCases) { p in
                            PlanCard(title: p.title,
                                     price: "\(store.price(of: Plan.find(size, p))) a \(p.unit)",
                                     badge: p == .yearly ? saving : nil,
                                     selected: period == p) { period = p }
                        }
                    }

                    if store.activePlan == plan {
                        Label("This is your plan.", systemImage: "checkmark.seal")
                            .font(TextStyle.headline)
                            .foregroundStyle(Palette.success)
                    }
                    if let note {
                        Text(note)
                            .font(TextStyle.subheadline)
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Layout.screenMargin + Space.xs)
                .padding(.top, Space.md)
                .frame(maxWidth: Layout.maxReadableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task { await store.load() }
        }
    }

    private var saving: String? {
        let m = Plan.find(size, .monthly), y = Plan.find(size, .yearly)
        if let pm = store.products[m.productId]?.price, let py = store.products[y.productId]?.price {
            return PaywallCopy.yearlySaving(monthly: pm, yearly: py)
        }
        return PaywallCopy.yearlySaving(monthly: m.fallbackPrice, yearly: y.fallbackPrice)
    }

    private var footer: some View {
        VStack(spacing: Space.sm) {
            let trial = store.hasTrial(plan)
            Button(trial ? "Start \(Plan.trialDays)-day free trial" : "Subscribe") { buy() }
                .buttonStyle(.primaryStyle(loading: busy, fullWidth: true))
                .disabled(busy || store.activePlan == plan)
            Text(PaywallCopy.chargeLine(price: store.price(of: plan), period: period, trial: trial, from: .now))
                .font(TextStyle.footnote)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.lg) {
                Button("Restore purchases") { restore() }
                Link("Terms of Use", destination: LegalLinks.terms)
                Link("Privacy", destination: LegalLinks.privacy)
            }
            .font(TextStyle.footnote)
        }
        .padding(.horizontal, Layout.screenMargin + Space.xs)
        .padding(.bottom, Space.sm)
        .padding(.top, Space.sm)
        .frame(maxWidth: Layout.maxReadableWidth)
        .background(.bar)
    }

    private func bullet(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(TextStyle.body)
            .foregroundStyle(Palette.text)
    }

    private func buy() {
        busy = true
        note = nil
        Task {
            defer { busy = false }
            switch await store.purchase(plan, accountId: model.state.session?.accountId) {
            case .purchased: dismiss()
            case .pending: note = "Waiting for approval. You'll get access as soon as it's approved."
            case .cancelled: break
            case .failed(let message): note = message
            }
        }
    }

    private func restore() {
        busy = true
        note = nil
        Task {
            defer { busy = false }
            note = await store.restore()
                ? "Restored. Your plan is active on this \(DeviceWord.current)."
                : "No subscription found for this Apple Account."
        }
    }
}

/// components.md: Plan card. Selected, and an optional badge.
struct PlanCard: View {
    let title: String
    let price: String
    var badge: String?
    let selected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: Space.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Palette.tint : Palette.textMuted)
                    .font(.title3)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(title).font(TextStyle.headline)
                    Text(price).font(TextStyle.subheadline).foregroundStyle(Palette.textMuted)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(TextStyle.caption.weight(.semibold))
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, Space.xxs)
                        .background(Capsule().fill(Palette.tint.opacity(0.15)))
                        .foregroundStyle(Palette.tint)
                }
            }
            .foregroundStyle(Palette.text)
            .padding(Layout.cardPadding)
            .frame(minHeight: Layout.minTarget)
            .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(selected ? Palette.tint : Palette.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// The terms and the privacy policy live on the landing site (`replica/launch/site/`).
/// App Review 3.1.2 wants both linked from the paywall. When the domain is bought, change
/// `site` and nothing else.
enum LegalLinks {
    static let site = URL(string: "https://handspan.vercel.app")!
    static let terms = site.appending(path: "terms.html")
    static let privacy = site.appending(path: "privacy.html")
}
